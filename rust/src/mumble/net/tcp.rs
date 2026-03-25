use crate::api::client::{MumbleChannel, MumbleEvent, MumbleTextMessage, MumbleUser};
use crate::frb_generated::StreamSink;
use crate::mumble::audio::{setup_audio, AudioStreams};
use crate::mumble::processing::{spawn_decode_thread, spawn_encode_thread};
use crate::mumble::types::MumbleConfig;
use crate::mumble::MumbleCommand;
use futures_util::{SinkExt, StreamExt};
use mumble_protocol_2x::control::msgs;
use mumble_protocol_2x::control::ControlCodec;
use mumble_protocol_2x::control::ControlPacket;
use mumble_protocol_2x::voice::{Clientbound, Serverbound};
use openssl::ssl::{SslConnector, SslMethod, SslVerifyMode};
use std::collections::HashMap;
use std::pin::Pin;
use std::sync::atomic::{AtomicBool, AtomicU32};
use std::sync::Arc;
use tokio::net::TcpStream;
use tokio::sync::mpsc;
use tokio_openssl::SslStream;
use tokio_util::codec::Framed;

struct MumbleSession {
    channels: HashMap<u32, MumbleChannel>,
    users: HashMap<u32, MumbleUser>,
    session_id: u32,
    my_channel_id: u32,
    voice_cmd_tx: Option<mpsc::Sender<crate::mumble::net::udp::VoiceCommand>>,
    _active_audio: Option<AudioStreams>,
    network_tx: Option<tokio::sync::mpsc::Sender<crate::mumble::types::AudioPacket>>,
    udp_rx: Option<crossbeam_channel::Receiver<crate::mumble::types::IncomingAudio>>,
    event_sink: StreamSink<MumbleEvent>,
    config: MumbleConfig,
    current_rms: Arc<AtomicU32>,
    global_volume: Arc<AtomicU32>,
    input_gain: Arc<AtomicU32>,
    vol_cmd_tx: crossbeam_channel::Sender<(u32, f32)>,
    vol_cmd_rx: crossbeam_channel::Receiver<(u32, f32)>,
    host: String,
    port: u16,
    crypt_setup: Option<([u8; 16], [u8; 16], [u8; 16])>,
    ptt_active: Arc<AtomicBool>,
}

impl MumbleSession {
    fn new(
        event_sink: StreamSink<MumbleEvent>,
        config: MumbleConfig,
        vol_cmd_tx: crossbeam_channel::Sender<(u32, f32)>,
        vol_cmd_rx: crossbeam_channel::Receiver<(u32, f32)>,
        host: String,
        port: u16,
    ) -> Self {
        Self {
            channels: HashMap::new(),
            users: HashMap::new(),
            session_id: 0,
            my_channel_id: 0,
            voice_cmd_tx: None,
            _active_audio: None,
            network_tx: None,
            udp_rx: None,
            event_sink,
            config,
            current_rms: Arc::new(AtomicU32::new(0.0f32.to_bits())),
            global_volume: Arc::new(AtomicU32::new(1.0f32.to_bits())),
            input_gain: Arc::new(AtomicU32::new(1.0f32.to_bits())),
            vol_cmd_tx,
            vol_cmd_rx,
            host,
            port,
            crypt_setup: None,
            ptt_active: Arc::new(AtomicBool::new(false)),
        }
    }

    fn init_audio_pipeline(&mut self) {
        self._active_audio = None;

        let network_tx = match self.network_tx.as_ref() {
            Some(tx) => tx.clone(),
            None => return,
        };
        let udp_rx = match self.udp_rx.as_ref() {
            Some(rx) => rx.clone(),
            None => return,
        };

        let event_sink_clone = self.event_sink.clone();

        use ringbuf::traits::Split;
        use ringbuf::HeapRb;

        let rb_in = HeapRb::<f32>::new(8192);
        let rb_out = HeapRb::<f32>::new(8192);
        let (prod_in, cons_in) = rb_in.split();
        let (prod_out, cons_out) = rb_out.split();

        let (in_notify_tx, in_notify_rx) = crossbeam_channel::bounded(10);
        let (out_notify_tx, out_notify_rx) = crossbeam_channel::bounded(10);

        match setup_audio(
            prod_in,
            cons_out,
            in_notify_tx,
            out_notify_tx,
            self.current_rms.clone(),
            self.input_gain.clone(),
            &self.config,
        ) {
            Ok(audio_streams) => {
                spawn_encode_thread(
                    cons_in,
                    in_notify_rx,
                    network_tx,
                    self.ptt_active.clone(),
                    audio_streams.input_rate(),
                    self.config.clone(),
                );

                spawn_decode_thread(
                    prod_out,
                    out_notify_rx,
                    udp_rx,
                    event_sink_clone,
                    audio_streams.output_rate(),
                    self.config.clone(),
                    self.global_volume.clone(),
                    self.vol_cmd_rx.clone(),
                );

                self._active_audio = Some(audio_streams);
            }
            Err(e) => {
                eprintln!("Failed to setup audio: {}", e);
            }
        }
    }

    async fn handle_packet(
        &mut self,
        packet: ControlPacket<Clientbound>,
        framed: &mut Framed<SslStream<TcpStream>, ControlCodec<Serverbound, Clientbound>>,
    ) {
        match packet {
            ControlPacket::ServerSync(ss) => {
                self.session_id = ss.session();
                let _ = self.event_sink.add(MumbleEvent::Connected(self.session_id));
            }
            ControlPacket::ChannelState(cs) => {
                let id = cs.channel_id();
                let channel = MumbleChannel {
                    id,
                    name: cs.name().to_string(),
                    parent_id: if cs.has_parent() {
                        Some(cs.parent())
                    } else {
                        None
                    },
                    position: cs.position(),
                    description: if cs.has_description() {
                        Some(cs.description().to_string())
                    } else {
                        None
                    },
                    is_enter_restricted: false,
                };
                self.channels.insert(id, channel.clone());
                let _ = self.event_sink.add(MumbleEvent::ChannelUpdate(channel));
            }
            ControlPacket::UserState(us) => {
                let session = us.session();
                if session == self.session_id {
                    self.my_channel_id = us.channel_id();
                }
                let user = MumbleUser {
                    session,
                    name: us.name().to_string(),
                    channel_id: us.channel_id(),
                    is_talking: false,
                    is_muted: us.self_mute() || us.mute(),
                    is_deafened: us.self_deaf() || us.deaf(),
                    is_suppressed: us.suppress(),
                    comment: if us.has_comment() {
                        Some(us.comment().to_string())
                    } else {
                        None
                    },
                };
                self.users.insert(session, user.clone());
                let _ = self.event_sink.add(MumbleEvent::UserUpdate(user));
            }
            ControlPacket::UserRemove(ur) => {
                self.users.remove(&ur.session());
                let _ = self.event_sink.add(MumbleEvent::UserRemoved(ur.session()));
            }
            ControlPacket::Ping(ping) => {
                let _ = framed.send(ControlPacket::Ping(ping)).await;
            }
            ControlPacket::TextMessage(tm) => {
                let sender_name = self
                    .users
                    .get(&tm.actor())
                    .map(|u| u.name.clone())
                    .unwrap_or_else(|| "Unknown".to_string());
                let _ = self
                    .event_sink
                    .add(MumbleEvent::TextMessage(MumbleTextMessage {
                        sender_name,
                        message: tm.message().to_string(),
                    }));
            }
            ControlPacket::CryptSetup(cs) => {
                let mut key = [0u8; 16];
                let mut encrypt_nonce = [0u8; 16];
                let mut decrypt_nonce = [0u8; 16];

                if let Some(k) = &cs.key {
                    let len = k.len().min(16);
                    key[..len].copy_from_slice(&k[..len]);
                }
                if let Some(cn) = &cs.client_nonce {
                    let len = cn.len().min(16);
                    encrypt_nonce[..len].copy_from_slice(&cn[..len]);
                }
                if let Some(sn) = &cs.server_nonce {
                    let len = sn.len().min(16);
                    decrypt_nonce[..len].copy_from_slice(&sn[..len]);
                }

                self.crypt_setup = Some((key, encrypt_nonce, decrypt_nonce));

                if self.network_tx.is_none() {
                    let (voice_cmd_sender, voice_cmd_receiver) = mpsc::channel(32);
                    self.voice_cmd_tx = Some(voice_cmd_sender);

                    let (out_audio_sender, out_audio_receiver) = tokio::sync::mpsc::channel(100);
                    let (udp_tx, udp_rx) = crossbeam_channel::bounded(100);

                    self.network_tx = Some(out_audio_sender);
                    self.udp_rx = Some(udp_rx);

                    let host_clone = self.host.clone();
                    let port_clone = self.port;
                    let crypt_state = mumble_protocol_2x::crypt::CryptState::new_from(
                        key,
                        encrypt_nonce,
                        decrypt_nonce,
                    );

                    tokio::spawn(async move {
                        if let Err(e) = crate::mumble::net::udp::VoiceNetworkHandler::run(
                            format!("{}:{}", host_clone, port_clone),
                            crypt_state,
                            voice_cmd_receiver,
                            out_audio_receiver,
                            udp_tx,
                        )
                        .await
                        {
                            eprintln!("Voice handler error: {}", e);
                        }
                    });
                } else {
                    if let Some(v_tx) = &self.voice_cmd_tx {
                        let _ =
                            v_tx.try_send(crate::mumble::net::udp::VoiceCommand::UpdateCryptState(
                                key,
                                encrypt_nonce,
                                decrypt_nonce,
                            ));
                    }
                }

                if self._active_audio.is_none() {
                    self.init_audio_pipeline();
                }
            }
            _ => {}
        }
    }

    async fn handle_command(
        &mut self,
        cmd: MumbleCommand,
        framed: &mut Framed<SslStream<TcpStream>, ControlCodec<Serverbound, Clientbound>>,
    ) {
        match cmd {
            MumbleCommand::JoinChannel(id) => {
                let mut us = msgs::UserState::new();
                us.set_channel_id(id);
                let _ = framed.send(ControlPacket::UserState(Box::new(us))).await;
            }
            MumbleCommand::SendTextMessage(msg) => {
                let mut tm = msgs::TextMessage::new();
                tm.set_message(msg);
                tm.channel_id.push(self.my_channel_id);
                let _ = framed.send(ControlPacket::TextMessage(Box::new(tm))).await;
            }
            MumbleCommand::SetMute(mute) => {
                let mut us = msgs::UserState::new();
                us.set_self_mute(mute);
                let _ = framed.send(ControlPacket::UserState(Box::new(us))).await;
            }
            MumbleCommand::SetDeafen(deafen) => {
                let mut us = msgs::UserState::new();
                us.set_self_deaf(deafen);
                if deafen {
                    us.set_self_mute(true);
                }
                let _ = framed.send(ControlPacket::UserState(Box::new(us))).await;
            }
            MumbleCommand::SetPtt(active) => {
                self.ptt_active
                    .store(active, std::sync::atomic::Ordering::Relaxed);
            }
            MumbleCommand::SetUserVolume(sid, vol) => {
                let _ = self.vol_cmd_tx.send((sid, vol));
            }
            MumbleCommand::SetOutputVolume(vol) => {
                self.global_volume
                    .store(vol.to_bits(), std::sync::atomic::Ordering::Relaxed);
            }
            MumbleCommand::SetInputGain(gain) => {
                self.input_gain
                    .store(gain.to_bits(), std::sync::atomic::Ordering::Relaxed);
            }
            MumbleCommand::UpdateConfig(new_config) => {
                self.config = new_config.clone();
                // To replace config on the fly, we just restart audio if it was active
                if self._active_audio.is_some() {
                    self.init_audio_pipeline();
                }
            }
            MumbleCommand::Disconnect => {} // Handled by loop breaker
        }
    }
}

pub async fn connect(
    host: &str,
    port: u16,
    username: String,
    password: Option<String>,
) -> anyhow::Result<Framed<SslStream<TcpStream>, ControlCodec<Serverbound, Clientbound>>> {
    // Setup TLS with OpenSSL
    let mut builder = SslConnector::builder(SslMethod::tls())?;
    builder.set_verify(SslVerifyMode::NONE);

    let connector = builder.build();
    let tcp_stream = TcpStream::connect(format!("{}:{}", host, port)).await?;

    let ssl = connector.configure()?.into_ssl(host)?;
    let mut tls_stream = SslStream::new(ssl, tcp_stream)?;

    Pin::new(&mut tls_stream)
        .connect()
        .await
        .map_err(|e| anyhow::anyhow!("TLS connection failed: {}", e))?;

    let mut framed = Framed::new(tls_stream, ControlCodec::<Serverbound, Clientbound>::new());

    // Handshake
    let mut version = msgs::Version::new();
    version.set_version_v1(0x00010400);
    version.set_release("Rumble".to_string());
    version.set_os("macOS".to_string());
    version.set_os_version("14.0.0".to_string());
    framed
        .send(ControlPacket::Version(Box::new(version)))
        .await?;

    let mut auth = msgs::Authenticate::new();
    auth.set_username(username);
    if let Some(p) = password {
        auth.set_password(p);
    }
    auth.set_opus(true);
    framed
        .send(ControlPacket::Authenticate(Box::new(auth)))
        .await?;

    Ok(framed)
}

pub async fn run_loop(
    mut framed: Framed<SslStream<TcpStream>, ControlCodec<Serverbound, Clientbound>>,
    host: String,
    port: u16,
    mut cmd_rx: mpsc::Receiver<MumbleCommand>,
    event_sink: StreamSink<MumbleEvent>,
    config: MumbleConfig,
) -> anyhow::Result<()> {
    let (vol_cmd_tx, vol_cmd_rx) = crossbeam_channel::unbounded();

    let mut session = MumbleSession::new(event_sink, config, vol_cmd_tx, vol_cmd_rx, host, port);

    let mut ping_interval = tokio::time::interval(std::time::Duration::from_secs(15));
    let mut volume_interval = tokio::time::interval(std::time::Duration::from_millis(200));

    loop {
        tokio::select! {
            _ = ping_interval.tick() => {
                let mut ping = msgs::Ping::new();
                let timestamp = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_millis() as u64;
                ping.set_timestamp(timestamp);
                let _ = framed.send(ControlPacket::Ping(Box::new(ping))).await;
            }
            _ = volume_interval.tick() => {
                let rms = f32::from_bits(session.current_rms.load(std::sync::atomic::Ordering::Relaxed));
                let _ = session.event_sink.add(MumbleEvent::AudioVolume(rms));
            }
            packet = framed.next() => {
                match packet {
                    Some(Ok(packet)) => {
                        session.handle_packet(packet, &mut framed).await;
                    }
                    Some(Err(e)) => {
                        let _ = session.event_sink.add(MumbleEvent::Disconnected(format!("Protocol error: {}", e)));
                        break;
                    }
                    None => {
                        let _ = session.event_sink.add(MumbleEvent::Disconnected("Server closed connection".to_string()));
                        break;
                    }
                }
            }
            cmd = cmd_rx.recv() => {
                match cmd {
                    Some(MumbleCommand::Disconnect) | None => break,
                    Some(cmd) => session.handle_command(cmd, &mut framed).await,
                }
            }
        }
    }

    Ok(())
}
