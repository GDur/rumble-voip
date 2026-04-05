use crate::mumble::dsp::{AudioPacket, IncomingAudio, MAX_OPUS_PACKET_SIZE};
use crate::mumble::protocol::crypt::CryptState;
use crate::mumble::protocol::voice::{VoicePacket, VoicePacketPayload};
use crossbeam_channel::Sender as CrossSender;
use std::io::Cursor;
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
        mut crypt_state: CryptState,
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

        let mut encryption_buf = [0u8; 1024];
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
                            crypt_state = CryptState::new(key, enc, dec);
                        }
                        Some(VoiceCommand::Disconnect) | None => break,
                    }
                }

                // Process outgoing network packets from encode thread
                packet = network_rx.recv() => {
                    if let Some(audio_packet) = packet {
                        let is_last = audio_packet.is_last();
                        let payload = VoicePacketPayload::Opus(audio_packet.payload().to_vec(), is_last);
                        let voice_packet = VoicePacket::Audio {
                            target: 0,
                            session_id: None,
                            seq_num: sequence,
                            payload,
                            position_info: None,
                        };

                        sequence += 1;
                        if is_last {
                            sequence = 0;
                        }

                        let mut cursor = Cursor::new(&mut encryption_buf[4..]);
                        voice_packet.encode(&mut cursor, false)?;
                        let len = cursor.position() as usize;
                        let header = crypt_state.encrypt(&mut encryption_buf[4..], len);
                        encryption_buf[..4].copy_from_slice(&header);

                        let _ = socket.send(&encryption_buf[..4 + len]).await;
                    }
                }

                // Ping mechanism
                _ = maintenance_ticker.tick() => {
                    if last_ping.elapsed().as_secs() >= 1 {
                        let packet = VoicePacket::Ping { timestamp: 0 };
                        let mut cursor = Cursor::new(&mut encryption_buf[4..]);
                        packet.encode(&mut cursor, false)?;
                        let len = cursor.position() as usize;
                        let header = crypt_state.encrypt(&mut encryption_buf[4..], len);
                        encryption_buf[..4].copy_from_slice(&header);

                        let _ = socket.send(&encryption_buf[..4 + len]).await;
                        last_ping = std::time::Instant::now();
                    }
                }

                // Receive incoming UDP packets
                res = socket_recv.recv(&mut udp_recv_buf) => {
                    if let Ok(len) = res {
                        if len < 4 { continue; }
                        let mut header = [0u8; 4];
                        header.copy_from_slice(&udp_recv_buf[..4]);
                        let mut data = udp_recv_buf[4..len].to_vec();

                        if crypt_state.decrypt(header, &mut data).is_ok() {
                            let mut cursor = Cursor::new(data);
                            if let Ok(VoicePacket::Audio { session_id, payload: VoicePacketPayload::Opus(opus_data, last), .. }) = VoicePacket::decode(&mut cursor, true) {
                                let mut p = heapless::Vec::<u8, MAX_OPUS_PACKET_SIZE>::new();
                                p.extend_from_slice(&opus_data[..opus_data.len().min(MAX_OPUS_PACKET_SIZE)]).expect("UDP receive Opus payload overflow");
                                let _ = udp_tx.try_send(IncomingAudio::new(
                                    session_id.unwrap_or(0),
                                    AudioPacket::new(p, last),
                                ));
                            }
                        }
                    }
                }
            }
        }
        Ok(())
    }
}
