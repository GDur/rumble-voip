use crate::api::client::MumbleEvent;
use crate::frb_generated::StreamSink;
use crate::mumble::types::{AudioPacket, IncomingAudio};
use crate::mumble::MumbleCommand;
use bytes::BytesMut;
use crossbeam_channel::Sender as CrossSender;
use mumble_protocol_2x::crypt::CryptState;
use mumble_protocol_2x::voice::{Clientbound, Serverbound, VoicePacket, VoicePacketPayload};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tokio::net::UdpSocket;
use tokio::sync::mpsc;

pub struct VoiceHandler;

impl VoiceHandler {
    pub async fn run(
        server_addr_str: String,
        mut crypt_state: CryptState<Serverbound, Clientbound>,
        mut cmd_rx: mpsc::Receiver<MumbleCommand>,
        mut network_rx: mpsc::Receiver<AudioPacket>,
        udp_tx: CrossSender<IncomingAudio>,
        _event_sink: StreamSink<MumbleEvent>,
        ptt_active: Arc<AtomicBool>,
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
                        Some(MumbleCommand::SetPtt(active)) => {
                            ptt_active.store(active, Ordering::Relaxed);
                        }
                        Some(MumbleCommand::Disconnect) | None => break,
                        _ => {}
                    }
                }

                // Process outgoing network packets from encode thread
                packet = network_rx.recv() => {
                    if let Some(audio_packet) = packet {
                        let is_last = audio_packet.is_last;
                        let payload = VoicePacketPayload::Opus(audio_packet.payload, is_last);
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
                        if let Ok(Ok(packet)) = crypt_state.decrypt(&mut data_to_decrypt) {
                            if let VoicePacket::Audio { session_id, payload, .. } = packet {
                                if let VoicePacketPayload::Opus(data, last) = payload {
                                    let _ = udp_tx.try_send(IncomingAudio {
                                        session_id,
                                        packet: AudioPacket {
                                            payload: data,
                                            is_last: last,
                                        },
                                    });
                                }
                            }
                        }
                    }
                }
            }
        }
        Ok(())
    }
}
