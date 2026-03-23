use crate::api::client::MumbleEvent;
use crate::frb_generated::StreamSink;
use crate::mumble::audio::setup_audio;
use crate::mumble::MumbleCommand;
use bytes::{Bytes, BytesMut};
use mumble_protocol_2x::crypt::CryptState;
use mumble_protocol_2x::voice::{Clientbound, Serverbound, VoicePacket, VoicePacketPayload};
use opus_head_sys::*;
use ringbuf::traits::{Consumer, Observer, Producer};
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tokio::net::UdpSocket;
use tokio::sync::mpsc;

struct SafeOpusEncoder(*mut OpusEncoder);
impl SafeOpusEncoder {
    fn new(sample_rate: i32, channels: i32, application: i32) -> anyhow::Result<Self> {
        let mut err = 0;
        let ptr = unsafe { opus_encoder_create(sample_rate, channels, application, &mut err) };
        if err != OPUS_OK as i32 {
            return Err(anyhow::anyhow!("Opus encoder creation error: {}", err));
        }
        Ok(Self(ptr))
    }

    fn ctl(&self, request: i32, value: i32) -> i32 {
        unsafe { opus_encoder_ctl(self.0, request, value) }
    }

    fn encode(&self, pcm: &[f32], frame_size: usize, data: &mut [u8]) -> anyhow::Result<usize> {
        let ret = unsafe {
            opus_encode_float(
                self.0,
                pcm.as_ptr(),
                frame_size as i32,
                data.as_mut_ptr(),
                data.len() as i32,
            )
        };
        if ret < 0 {
            return Err(anyhow::anyhow!("Opus encode error: {}", ret));
        }
        Ok(ret as usize)
    }
}
impl Drop for SafeOpusEncoder {
    fn drop(&mut self) {
        unsafe { opus_encoder_destroy(self.0) };
    }
}
unsafe impl Send for SafeOpusEncoder {}

struct SafeOpusDecoder(*mut OpusDecoder);
impl SafeOpusDecoder {
    fn new(sample_rate: i32, channels: i32) -> anyhow::Result<Self> {
        let mut err = 0;
        let ptr = unsafe { opus_decoder_create(sample_rate, channels, &mut err) };
        if err != OPUS_OK as i32 {
            return Err(anyhow::anyhow!("Opus decoder creation error: {}", err));
        }
        Ok(Self(ptr))
    }

    fn decode(&self, data: &[u8], frame_size: usize, pcm: &mut [f32]) -> anyhow::Result<usize> {
        let ret = unsafe {
            opus_decode_float(
                self.0,
                data.as_ptr(),
                data.len() as i32,
                pcm.as_mut_ptr(),
                frame_size as i32,
                0, // decode_fec
            )
        };
        if ret < 0 {
            return Err(anyhow::anyhow!("Opus decode error: {}", ret));
        }
        Ok(ret as usize)
    }
}
impl Drop for SafeOpusDecoder {
    fn drop(&mut self) {
        unsafe { opus_decoder_destroy(self.0) };
    }
}
unsafe impl Send for SafeOpusDecoder {}

struct RemoteUserData {
    decoder: SafeOpusDecoder,
    is_talking: bool,
    last_packet_time: std::time::Instant,
    f32_pcm_buf: Vec<f32>,
    i16_pcm_buf: Vec<i16>,
}

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
        println!(
            "--- RUST: VoiceHandler task starting for {} ---",
            server_addr_str
        );

        let mut addrs = tokio::net::lookup_host(&server_addr_str).await?;
        let server_addr = addrs
            .next()
            .ok_or_else(|| anyhow::anyhow!("Could not resolve server address"))?;

        println!(
            "--- RUST: resolved {} to {} ---",
            server_addr_str, server_addr
        );

        let mut audio = setup_audio()?;

        let socket = UdpSocket::bind("0.0.0.0:0").await?;
        socket.connect(server_addr).await?;
        println!("--- RUST: UDP socket connected to {} ---", server_addr);

        let encoder = SafeOpusEncoder::new(
            Self::SAMPLE_RATE as i32,
            Self::CHANNELS as i32,
            OPUS_APPLICATION_VOIP as i32,
        )
        .map_err(|e| anyhow::anyhow!("Opus encoder error: {}", e))?;
        encoder.ctl(OPUS_SET_VBR_REQUEST as i32, 1);
        encoder.ctl(OPUS_SET_INBAND_FEC_REQUEST as i32, 1);
        encoder.ctl(OPUS_SET_PACKET_LOSS_PERC_REQUEST as i32, 10);
        encoder.ctl(OPUS_SET_BITRATE_REQUEST as i32, Self::BITRATE as i32);
        encoder.ctl(OPUS_SET_COMPLEXITY_REQUEST as i32, Self::COMPLEXITY as i32);

        // Key: session_id (u32)
        let mut decoders: HashMap<u32, RemoteUserData> = HashMap::new();

        let ptt_active = Arc::new(AtomicBool::new(false));

        let mut pcm_frame = vec![0i16; Self::FRAME_SIZE];
        let mut f32_frame = vec![0.0f32; Self::FRAME_SIZE];
        let mut opus_buf = vec![0u8; 1024];
        let mut udp_recv_buf = [0u8; 2048];
        let mut encryption_buf = BytesMut::with_capacity(1024);

        let mut sequence: u64 = 0;
        let mut last_ping = std::time::Instant::now();
        let mut last_volume_sent = std::time::Instant::now();
        let mut packets_sent = 0;
        let mut packets_received = 0;

        // Maintenance ticker for low-frequency tasks (pings, timeouts)
        let mut maintenance_ticker = tokio::time::interval(std::time::Duration::from_millis(500));

        println!("--- RUST: Voice loop starting ---");

        loop {
            tokio::select! {
                cmd = cmd_rx.recv() => {
                    match cmd {
                        Some(MumbleCommand::SetPtt(active)) => {
                            ptt_active.store(active, Ordering::Relaxed);
                            println!("--- RUST: PTT changed to: {} ---", active);
                            
                            // Wake up the audio processing branch to handle any leftover samples
                            // or send the terminator packet immediately.
                            audio.input_notify.notify_one();
                        }
                        Some(MumbleCommand::Disconnect) | None => {
                            println!("--- RUST: VoiceHandler disconnecting ---");
                            break;
                        }
                        _ => {}
                    }
                }

                _ = audio.input_notify.notified() => {
                    let now = std::time::Instant::now();
                    let is_ptt = ptt_active.load(Ordering::Relaxed);

                    while audio.input_consumer.occupied_len() >= Self::FRAME_SIZE {
                        let read = audio.input_consumer.pop_slice(&mut pcm_frame);
                        if read == Self::FRAME_SIZE {
                            // 1. Volume Calculation
                            if now.duration_since(last_volume_sent) >= std::time::Duration::from_millis(200) {
                                let mut sum_sq = 0.0;
                                for sample in pcm_frame.iter() {
                                    let f = *sample as f32 / -(i16::MIN as f32);
                                    sum_sq += f * f;
                                }
                                let rms = (sum_sq / Self::FRAME_SIZE as f32).sqrt();
                                let _ = event_sink.add(MumbleEvent::AudioVolume(rms));
                                last_volume_sent = now;
                            }

                            // 2. Encoding & Sending
                            if is_ptt {
                                for (i, &sample) in pcm_frame.iter().enumerate() {
                                    f32_frame[i] = sample as f32 / -(i16::MIN as f32);
                                }
                                if let Ok(len) = encoder.encode(&f32_frame, Self::FRAME_SIZE, &mut opus_buf) {
                                    let packet = VoicePacket::Audio {
                                        _dst: std::marker::PhantomData,
                                        target: 0,
                                        session_id: (),
                                        seq_num: sequence,
                                        payload: VoicePacketPayload::Opus(Bytes::copy_from_slice(&opus_buf[..len]), false),
                                        position_info: None,
                                    };
                                    sequence += 1;
                                    encryption_buf.clear();
                                    crypt_state.encrypt(packet, &mut encryption_buf);
                                    let _ = socket.send(&encryption_buf).await;
                                    packets_sent += 1;
                                    if packets_sent % 100 == 0 {
                                        println!("--- RUST: Sent 100 packets, current seq={} ---", sequence);
                                    }
                                }
                            }
                        }
                    }

                    // 3. Terminator Logic
                    if !is_ptt && sequence > 0 {
                        let packet = VoicePacket::Audio {
                            _dst: std::marker::PhantomData,
                            target: 0,
                            session_id: (),
                            seq_num: sequence,
                            payload: VoicePacketPayload::Opus(Bytes::new(), true),
                            position_info: None,
                        };
                        encryption_buf.clear();
                        crypt_state.encrypt(packet, &mut encryption_buf);
                        let _ = socket.send(&encryption_buf).await;
                        sequence = 0;
                    }
                }

                _ = maintenance_ticker.tick() => {
                    let now = std::time::Instant::now();

                    // UDP Ping every 1 second
                    if now.duration_since(last_ping) >= std::time::Duration::from_secs(1) {
                        let packet = VoicePacket::Ping { timestamp: 0 };
                        encryption_buf.clear();
                        crypt_state.encrypt(packet, &mut encryption_buf);
                        let _ = socket.send(&encryption_buf).await;
                        last_ping = now;
                    }

                    // Remote user timeout check (checked every 500ms)
                    let mut stopped_talking = Vec::new();
                    for (&sid, user) in decoders.iter_mut() {
                        if user.is_talking && now.duration_since(user.last_packet_time) > std::time::Duration::from_millis(500) {
                            user.is_talking = false;
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
                                    if let VoicePacket::Audio { session_id, payload, .. } = packet {
                                        if let VoicePacketPayload::Opus(data, last) = payload {
                                            let sid_u32 = session_id;
                                            let user = decoders.entry(sid_u32).or_insert_with(|| {
                                                println!("--- RUST: New talking user detected: {} ---", sid_u32);
                                                RemoteUserData {
                                                    decoder: SafeOpusDecoder::new(Self::SAMPLE_RATE as i32, Self::CHANNELS as i32).expect("Failed to create Opus decoder"),
                                                    is_talking: false,
                                                    last_packet_time: std::time::Instant::now(),
                                                    f32_pcm_buf: vec![0.0f32; Self::FRAME_SIZE],
                                                    i16_pcm_buf: vec![0i16; Self::FRAME_SIZE],
                                                }
                                            });
                                            user.last_packet_time = std::time::Instant::now();
                                            if !user.is_talking {
                                                user.is_talking = true;
                                                println!("--- RUST: User {} started talking ---", sid_u32);
                                                let _ = event_sink.add(MumbleEvent::UserTalking(sid_u32, true));
                                            }

                                            if last {
                                                user.is_talking = false;
                                                let _ = event_sink.add(MumbleEvent::UserTalking(sid_u32, false));
                                            }

                                            if !data.is_empty() {
                                                match user.decoder.decode(&data, Self::FRAME_SIZE, &mut user.f32_pcm_buf[..]) {
                                                    Ok(samples) => {
                                                        if user.i16_pcm_buf.len() < samples {
                                                            user.i16_pcm_buf.resize(samples, 0);
                                                        }
                                                        for i in 0..samples {
                                                            user.i16_pcm_buf[i] = (user.f32_pcm_buf[i] * i16::MAX as f32)
                                                                .clamp(i16::MIN as f32, i16::MAX as f32) as i16;
                                                        }

                                                        if audio.output_producer.vacant_len() >= samples {
                                                            let _ = audio.output_producer.push_slice(&user.i16_pcm_buf[..samples]);
                                                        } else {
                                                            eprintln!("Output buffer full, dropping frame for user {}", sid_u32);
                                                        }
                                                    }
                                                    Err(e) => eprintln!("Opus decode error: {}", e),
                                                }
                                            }
                                        }
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
