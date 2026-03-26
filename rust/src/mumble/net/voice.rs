use crate::mumble::dsp::{AudioPacket, IncomingAudio, MAX_OPUS_SIZE};
use bytes::BytesMut;
use crossbeam_channel::Sender as CrossSender;
use mumble_protocol_2x::crypt::CryptState;
use mumble_protocol_2x::voice::{Clientbound, Serverbound, VoicePacket, VoicePacketPayload};
use std::sync::Arc;
use tokio::net::UdpSocket;
use tokio::sync::mpsc;

pub enum VoiceCommand {
    UpdateCryptState([u8; 16], [u8; 16], [u8; 16]),
    Disconnect,
}

/// Handles the UDP voice channel for the Mumble network protocol.
pub struct VoiceChannel;

impl VoiceChannel {
    pub async fn run(
        server_addr_str: String,
        mut crypt_state: CryptState<Serverbound, Clientbound>,
        mut cmd_rx: mpsc::Receiver<VoiceCommand>,
        mut network_rx: mpsc::Receiver<AudioPacket>,
        udp_tx: CrossSender<IncomingAudio>,
    ) -> anyhow::Result<()> {
        let mut addrs = tokio::net::lookup_host(&server_addr_str).await?;
        let server_addr = addrs
            .next()
            .ok_or_else(|| anyhow::anyhow!("Could not resolve server address"))?;

        let socket = Arc::new(UdpSocket::bind("0.0.0.0:0").await?);
        socket.connect(server_addr).await?;

        let mut encryption_buf = BytesMut::with_capacity(1024);
        let mut udp_recv_buf = [0u8; 2048];

        let mut sequence: u64 = 0;
        let mut last_ping = std::time::Instant::now();
        let mut maintenance_ticker = tokio::time::interval(std::time::Duration::from_millis(100));

        let socket_recv = socket.clone();

        loop {
            tokio::select! {
                cmd = cmd_rx.recv() => {
                    match cmd {
                        Some(VoiceCommand::UpdateCryptState(key, enc, dec)) => {
                            crypt_state = CryptState::new_from(key, enc, dec);
                        }
                        Some(VoiceCommand::Disconnect) | None => break,
                    }
                }

                // Process outgoing network packets from encode thread
                packet = network_rx.recv() => {
                    if let Some(audio_packet) = packet {
                        let is_last = audio_packet.is_last();
                        let payload = VoicePacketPayload::Opus(bytes::Bytes::copy_from_slice(audio_packet.payload()), is_last);
                        let voice_packet = VoicePacket::Audio {
                            _dst: std::marker::PhantomData,
                            target: 0,
                            session_id: (),
                            seq_num: sequence,
                            payload,
                            position_info: None,
                        };

                        sequence += 1;
                        if is_last {
                            sequence = 0;
                        }

                        encryption_buf.clear();
                        crypt_state.encrypt(voice_packet, &mut encryption_buf);
                        let _ = socket.send(&encryption_buf).await;
                    }
                }

                // Ping mechanism
                _ = maintenance_ticker.tick() => {
                    if last_ping.elapsed().as_secs() >= 1 {
                        let packet = VoicePacket::Ping { timestamp: 0 };
                        encryption_buf.clear();
                        crypt_state.encrypt(packet, &mut encryption_buf);
                        let _ = socket.send(&encryption_buf).await;
                        last_ping = std::time::Instant::now();
                    }
                }

                // Receive incoming UDP packets
                res = socket_recv.recv(&mut udp_recv_buf) => {
                    if let Ok(len) = res {
                        let mut data_to_decrypt = BytesMut::from(&udp_recv_buf[..len]);
                        if let Ok(Ok(VoicePacket::Audio { session_id, payload: VoicePacketPayload::Opus(data, last), .. })) = crypt_state.decrypt(&mut data_to_decrypt) {
                            let mut p = heapless::Vec::<u8, MAX_OPUS_SIZE>::new();
                            p.extend_from_slice(&data[..data.len().min(MAX_OPUS_SIZE)]).expect("UDP receive Opus payload overflow");
                            let _ = udp_tx.try_send(IncomingAudio::new(
                                session_id,
                                AudioPacket::new(p, last),
                            ));
                        }
                    }
                }
            }
        }
        Ok(())
    }
}
