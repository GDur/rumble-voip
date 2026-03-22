use std::sync::Arc;
use tokio::sync::{mpsc, Mutex};
use tokio::net::UdpSocket;
use mumble_protocol_2x::crypt::CryptState;
use mumble_protocol_2x::voice::{Serverbound, Clientbound, VoicePacket, VoicePacketPayload};
use opus_rs::{Application, OpusDecoder, OpusEncoder};
use crate::mumble::audio::setup_audio;
use crate::mumble::MumbleCommand;
use crate::api::client::MumbleEvent;
use crate::frb_generated::StreamSink;
use ringbuf::traits::{Consumer, Producer, Observer};
use std::collections::HashMap;
use bytes::{Bytes, BytesMut};

pub struct VoiceHandler;

impl VoiceHandler {
    const SAMPLE_RATE: usize = 48000;
    const CHANNELS: usize = 1;
    const FRAME_MS: usize = 20;
    const FRAME_SIZE: usize = Self::SAMPLE_RATE * Self::FRAME_MS / 1000;
    const BITRATE: usize = 40000;
    const COMPLEXITY: u32 = 10;

    pub async fn run(
        server_addr_str: String,
        mut crypt_state: CryptState<Serverbound, Clientbound>,
        mut cmd_rx: mpsc::Receiver<MumbleCommand>,
        event_sink: StreamSink<MumbleEvent>,
    ) -> anyhow::Result<()> {
        println!("--- RUST: VoiceHandler task starting for {} ---", server_addr_str);
        
        let mut addrs = tokio::net::lookup_host(&server_addr_str).await?;
        let server_addr = addrs.next()
            .ok_or_else(|| anyhow::anyhow!("Could not resolve server address"))?;
        
        println!("--- RUST: resolved {} to {} ---", server_addr_str, server_addr);

        let mut audio = setup_audio()?;

        let socket = UdpSocket::bind("0.0.0.0:0").await?;
        socket.connect(server_addr).await?;
        println!("--- RUST: UDP socket connected ---");

        let mut encoder = OpusEncoder::new(Self::SAMPLE_RATE as i32, Self::CHANNELS, Application::Voip)
            .map_err(|e| anyhow::anyhow!("Opus encoder error: {}", e))?;
        encoder.use_cbr = false;
        encoder.use_inband_fec = true;
        encoder.packet_loss_perc = 10; // Could be dynamically updated based on udp packet loss
        encoder.bitrate_bps = Self::BITRATE as i32;
        encoder.complexity = Self::COMPLEXITY as i32;
        
        let mut decoders: HashMap<u32, (OpusDecoder, bool, std::time::Instant, Vec<f32>)> = HashMap::new();
        
        let ptt_active = Arc::new(Mutex::new(false));

        let mut pcm_frame = vec![0i16; Self::FRAME_SIZE];
        let mut f32_frame = vec![0.0f32; Self::FRAME_SIZE];
        let mut opus_buf = vec![0u8; 1024];
        let mut udp_recv_buf = [0u8; 2048];
        
        let mut sequence: u64 = 0;
        let mut last_ping = std::time::Instant::now();
        let mut packets_sent = 0;
        let mut packets_received = 0;

        println!("--- RUST: Voice loop starting ---");

        loop {
            tokio::select! {
                cmd = cmd_rx.recv() => {
                    match cmd {
                        Some(MumbleCommand::SetPtt(active)) => {
                            let mut ptt = ptt_active.lock().await;
                            *ptt = active;
                            println!("--- RUST: PTT changed to: {} ---", active);
                        }
                        Some(MumbleCommand::Disconnect) => {
                            println!("--- RUST: VoiceHandler disconnecting ---");
                            break;
                        }
                        _ => {}
                    }
                }
                
                _ = tokio::time::sleep(std::time::Duration::from_millis(10)) => {
                    let now = std::time::Instant::now();
                    
                    // UDP Ping every 1 second
                    if now.duration_since(last_ping) > std::time::Duration::from_secs(1) {
                        let packet = VoicePacket::Ping { timestamp: 0 };
                        let mut bytes = BytesMut::new();
                        crypt_state.encrypt(packet, &mut bytes);
                        let _ = socket.send(&bytes).await;
                        last_ping = now;
                    }

                    let is_ptt = *ptt_active.lock().await;
                    
                    while audio.input_consumer.occupied_len() >= Self::FRAME_SIZE {
                        let read = audio.input_consumer.pop_slice(&mut pcm_frame);
                        if read == Self::FRAME_SIZE {
                            let mut sum_sq = 0.0;
                            for (i, &sample) in pcm_frame.iter().enumerate() {
                                // Use i16::MIN (32768) for normalization so that -32768 / 32768.0 == -1.0 exactly
                                let f = sample as f32 / -(i16::MIN as f32);
                                f32_frame[i] = f;
                                sum_sq += f * f;
                            }
                            let rms = (sum_sq / Self::FRAME_SIZE as f32).sqrt();
                            let _ = event_sink.add(MumbleEvent::AudioVolume(rms));

                            if is_ptt {
                                match encoder.encode(&f32_frame[..Self::FRAME_SIZE], Self::FRAME_SIZE, &mut opus_buf) {
                                    Ok(len) => {
                                        let packet = VoicePacket::Audio {
                                            _dst: std::marker::PhantomData,
                                            target: 0,
                                            session_id: (),
                                            seq_num: sequence,
                                            payload: VoicePacketPayload::Opus(Bytes::copy_from_slice(&opus_buf[..len]), false),
                                            position_info: None,
                                        };
                                        sequence += 1;
                                        
                                        let mut encrypted = BytesMut::new();
                                        crypt_state.encrypt(packet, &mut encrypted);
                                        if let Ok(_) = socket.send(&encrypted).await {
                                            packets_sent += 1;
                                            if packets_sent % 100 == 0 {
                                                println!("--- RUST: Sent 100 packets, current seq={} ---", sequence);
                                            }
                                        }
                                    }
                                    Err(e) => eprintln!("Opus encode error: {:?}", e),
                                }
                            }
                        }
                    }

                    if !is_ptt {
                        if sequence > 0 {
                            // Send terminator
                            let packet = VoicePacket::Audio {
                                _dst: std::marker::PhantomData,
                                target: 0,
                                session_id: (),
                                seq_num: sequence,
                                payload: VoicePacketPayload::Opus(Bytes::new(), true),
                                position_info: None,
                            };
                            let mut encrypted = BytesMut::new();
                            crypt_state.encrypt(packet, &mut encrypted);
                            let _ = socket.send(&encrypted).await;
                            sequence = 0;
                        }
                    }

                    // Remote user timeout check
                    let mut stopped_talking = Vec::new();
                    for (&sid, (_, is_talking, last_packet, _)) in decoders.iter_mut() {
                        if *is_talking && now.duration_since(*last_packet) > std::time::Duration::from_millis(500) {
                            *is_talking = false;
                            stopped_talking.push(sid);
                        }
                    }
                    for sid in stopped_talking {
                        println!("--- RUST: User {} stopped talking (timeout) ---", sid);
                        let _ = event_sink.add(MumbleEvent::UserTalking(sid, false));
                    }
                }

                res = socket.recv(&mut udp_recv_buf) => {
                    match res {
                        Ok(len) => {
                            packets_received += 1;
                            let mut data_to_decrypt = BytesMut::from(&udp_recv_buf[..len]);
                            
                            match crypt_state.decrypt(&mut data_to_decrypt) {
                                Ok(Ok(packet)) => {
                                    match packet {
                                        VoicePacket::Audio { session_id, payload, .. } => {
                                            if let VoicePacketPayload::Opus(data, _) = payload {
                                                let sid_u32 = session_id as u32;
                                                let entry = decoders.entry(sid_u32).or_insert_with(|| {
                                                    println!("--- RUST: New talking user detected: {} ---", sid_u32);
                                                    (
                                                        OpusDecoder::new(Self::SAMPLE_RATE as i32, Self::CHANNELS).expect("Failed to create Opus decoder"), 
                                                        false, 
                                                        std::time::Instant::now(),
                                                        vec![0.0f32; Self::FRAME_SIZE * 6]
                                                    )
                                                });
                                                entry.2 = std::time::Instant::now();
                                                if !entry.1 {
                                                    entry.1 = true;
                                                    println!("--- RUST: User {} started talking ---", sid_u32);
                                                    let _ = event_sink.add(MumbleEvent::UserTalking(sid_u32, true));
                                                }

                                                if !data.is_empty() {
                                                    match entry.0.decode(&data, Self::FRAME_SIZE, &mut entry.3[..]) {
                                                        Ok(samples) => {
                                                            let mut decoded_i16 = vec![0i16; samples];
                                                            for i in 0..samples {
                                                                decoded_i16[i] = (entry.3[i] * i16::MAX as f32)
                                                                    .clamp(i16::MIN as f32, i16::MAX as f32) as i16;
                                                            }
                                                            
                                                            // Basic jitter buffering: if buffer is too empty, it might cause static
                                                            // cpal will pop 0s if we are empty.
                                                            if audio.output_producer.vacant_len() >= samples {
                                                                let _ = audio.output_producer.push_slice(&decoded_i16);
                                                            } else {
                                                                eprintln!("Output buffer full, dropping frame for user {}", sid_u32);
                                                            }
                                                        }
                                                        Err(e) => eprintln!("Opus decode error: {}", e),
                                                    }
                                                }
                                            }
                                        }
                                        _ => {}
                                    }
                                }
                                _ => {
                                    if packets_received % 100 == 0 {
                                        println!("--- RUST: UDP decryption failed or non-audio packet ---");
                                    }
                                }
                            }
                        }
                        Err(e) => eprintln!("UDP recv error: {}", e),
                    }
                }
            }
        }
        
        Ok(())
    }
}
