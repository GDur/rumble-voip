use crate::api::client::{MumbleChannel, MumbleEvent, MumbleTextMessage, MumbleUser};
use crate::frb_generated::StreamSink;
use crate::mumble::config::MumbleConfig;
use crate::mumble::dsp::{spawn_decode_thread, spawn_encode_thread, AudioPacket, IncomingAudio};
use crate::mumble::hardware::audio::{setup_audio, AudioBackend};
use crate::mumble::net::voice::{VoiceChannel, VoiceCommand};
use crate::mumble::MumbleCommand;
use crate::mumble::protocol::control::ControlPacket;
use crate::mumble::protocol::msgs;
use crate::mumble::protocol::crypt::CryptState;
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, AtomicU32};
use std::sync::Arc;
use tokio::net::TcpStream;
use tokio::sync::mpsc;
use tokio_rustls::rustls::{ClientConfig, RootCertStore, pki_types::ServerName};
use tokio_rustls::TlsConnector;
use tokio_rustls::client::TlsStream;
use std::io::BufReader;

struct MumbleSession {
    channels: HashMap<u32, MumbleChannel>,
    users: HashMap<u32, MumbleUser>,
    session_id: u32,
    my_channel_id: u32,
    voice_cmd_tx: Option<mpsc::Sender<VoiceCommand>>,
    _active_audio: Option<AudioBackend>,
    network_tx: Option<tokio::sync::mpsc::Sender<AudioPacket>>,
    udp_rx: Option<crossbeam_channel::Receiver<IncomingAudio>>,
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
            Ok(audio_backend) => {
                spawn_encode_thread(
                    cons_in,
                    in_notify_rx,
                    network_tx,
                    self.ptt_active.clone(),
                    audio_backend.input_rate(),
                    self.config.clone(),
                );

                spawn_decode_thread(
                    prod_out,
                    out_notify_rx,
                    udp_rx,
                    event_sink_clone,
                    audio_backend.output_rate(),
                    self.config.clone(),
                    self.global_volume.clone(),
                    self.vol_cmd_rx.clone(),
                );

                self._active_audio = Some(audio_backend);
            }
            Err(e) => {
                eprintln!("Failed to setup audio: {}", e);
            }
        }
    }

    async fn handle_packet(
        &mut self,
        packet: ControlPacket,
        tls_write: &mut (impl tokio::io::AsyncWrite + Unpin),
    ) -> anyhow::Result<()> {
        match packet {
            ControlPacket::ServerSync(ss) => {
                self.session_id = ss.session.unwrap_or(0);
                let _ = self.event_sink.add(MumbleEvent::Connected(self.session_id));
            }
            ControlPacket::Reject(rj) => {
                let reason = rj.reason.clone();
                let _ = self
                    .event_sink
                    .add(MumbleEvent::Disconnected(reason));
                return Err(anyhow::anyhow!("Handshake rejected"));
            }
            ControlPacket::ChannelState(cs) => {
                let id = cs.channel_id.unwrap_or(0);
                let channel = self.channels.entry(id).or_insert_with(|| MumbleChannel {
                    id,
                    ..Default::default()
                });

                if let Some(name) = cs.name {
                    channel.name = name;
                }
                if let Some(parent) = cs.parent {
                    channel.parent_id = Some(parent);
                }
                if let Some(position) = cs.position {
                    channel.position = position;
                }
                if let Some(description) = cs.description {
                    channel.description = Some(description);
                }

                let channel_clone = channel.clone();
                let _ = self
                    .event_sink
                    .add(MumbleEvent::ChannelUpdate(channel_clone));
            }
            ControlPacket::UserState(us) => {
                let session = us.session.unwrap_or(0);
                let user = self.users.entry(session).or_insert_with(|| MumbleUser {
                    session,
                    ..Default::default()
                });

                if let Some(name) = us.name {
                    user.name = name;
                }
                if let Some(channel_id) = us.channel_id {
                    user.channel_id = channel_id;
                }
                if us.self_mute.is_some() || us.mute.is_some() {
                    user.is_muted = us.self_mute.unwrap_or(false) || us.mute.unwrap_or(false);
                }
                if us.self_deaf.is_some() || us.deaf.is_some() {
                    user.is_deafened = us.self_deaf.unwrap_or(false) || us.deaf.unwrap_or(false);
                }
                if let Some(suppress) = us.suppress {
                    user.is_suppressed = suppress;
                }
                if let Some(comment) = us.comment {
                    user.comment = Some(comment);
                }

                if session == self.session_id {
                    self.my_channel_id = user.channel_id;
                }

                let user_clone = user.clone();
                let _ = self.event_sink.add(MumbleEvent::UserUpdate(user_clone));
            }
            ControlPacket::UserRemove(ur) => {
                self.users.remove(&ur.session);
                let _ = self.event_sink.add(MumbleEvent::UserRemoved(ur.session));
            }
            ControlPacket::Ping(ping) => {
                let mut buf = Vec::new();
                ControlPacket::Ping(ping).encode(&mut buf)?;
                tokio::io::AsyncWriteExt::write_all(tls_write, &buf).await?;
            }
            ControlPacket::TextMessage(tm) => {
                let sender_name = self
                    .users
                    .get(&tm.actor.unwrap_or(0))
                    .map(|u| u.name.clone())
                    .unwrap_or_else(|| "Unknown".to_string());
                let _ = self
                    .event_sink
                    .add(MumbleEvent::TextMessage(MumbleTextMessage {
                        sender_name,
                        message: tm.message.clone(),
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
                    let (v_tx, v_rx) = mpsc::channel(32);
                    self.voice_cmd_tx = Some(v_tx);

                    let (network_tx, network_rx) = tokio::sync::mpsc::channel(100);
                    let (udp_tx, udp_rx) = crossbeam_channel::bounded(100);

                    self.network_tx = Some(network_tx);
                    self.udp_rx = Some(udp_rx);

                    let host_clone = self.host.clone();
                    let port_clone = self.port;
                    let crypt_state = CryptState::new(
                        key,
                        encrypt_nonce,
                        decrypt_nonce,
                    );

                    tokio::spawn(async move {
                        if let Err(e) = VoiceChannel::run(
                            format!("{}:{}", host_clone, port_clone),
                            crypt_state,
                            v_rx,
                            network_rx,
                            udp_tx,
                        )
                        .await
                        {
                            eprintln!("Voice channel error: {}", e);
                        }
                    });
                } else {
                    if let Some(v_tx) = &self.voice_cmd_tx {
                        let _ = v_tx.try_send(VoiceCommand::UpdateCryptState(
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
        Ok(())
    }

    async fn handle_command(
        &mut self,
        cmd: MumbleCommand,
        tls_write: &mut (impl tokio::io::AsyncWrite + Unpin),
    ) {
        let packet = match cmd {
            MumbleCommand::JoinChannel(id) => {
                let mut us = msgs::UserState::default();
                us.channel_id = Some(id);
                Some(ControlPacket::UserState(us))
            }
            MumbleCommand::SendTextMessage(msg) => {
                let mut tm = msgs::TextMessage::default();
                tm.message = msg;
                tm.channel_id.push(self.my_channel_id);
                Some(ControlPacket::TextMessage(tm))
            }
            MumbleCommand::SetMute(mute) => {
                let mut us = msgs::UserState::default();
                us.self_mute = Some(mute);
                Some(ControlPacket::UserState(us))
            }
            MumbleCommand::SetDeafen(deafen) => {
                let mut us = msgs::UserState::default();
                us.self_deaf = Some(deafen);
                if deafen {
                    us.self_mute = Some(true);
                }
                Some(ControlPacket::UserState(us))
            }
            MumbleCommand::SetPtt(active) => {
                self.ptt_active
                    .store(active, std::sync::atomic::Ordering::Relaxed);
                None
            }
            MumbleCommand::SetUserVolume(sid, vol) => {
                let _ = self.vol_cmd_tx.send((sid, vol));
                None
            }
            MumbleCommand::SetOutputVolume(vol) => {
                self.global_volume
                    .store(vol.to_bits(), std::sync::atomic::Ordering::Relaxed);
                None
            }
            MumbleCommand::SetInputGain(gain) => {
                self.input_gain
                    .store(gain.to_bits(), std::sync::atomic::Ordering::Relaxed);
                None
            }
            MumbleCommand::UpdateConfig(new_config) => {
                self.config = new_config.clone();
                // To replace config on the fly, we just restart audio if it was active
                if self._active_audio.is_some() {
                    self.init_audio_pipeline();
                }
                None
            }
            MumbleCommand::Disconnect => None,
        };

        if let Some(p) = packet {
            let mut buf = Vec::new();
            if let Ok(_) = p.encode(&mut buf) {
                let _ = tokio::io::AsyncWriteExt::write_all(tls_write, &buf).await;
            }
        }
    }
}

pub async fn connect(
    host: &str,
    port: u16,
    username: String,
    password: Option<String>,
) -> anyhow::Result<(
    TlsStream<TcpStream>,
    Vec<ControlPacket>,
)> {
    let mut root_store = RootCertStore::empty();
    root_store.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());

    let config = ClientConfig::builder()
        .with_root_certificates(root_store)
        .with_no_client_auth();

    let connector = TlsConnector::from(Arc::new(config));
    let tcp_stream = TcpStream::connect(format!("{}:{}", host, port)).await?;
    let domain = ServerName::try_from(host)
        .map_err(|_| anyhow::anyhow!("Invalid DNS name"))?
        .to_owned();

    let mut tls_stream = connector.connect(domain, tcp_stream).await?;

    // Handshake
    let mut version = msgs::Version::default();
    version.version_v1 = Some(0x00010400);
    version.release = Some("Rumble".to_string());
    version.os = Some("macOS".to_string());
    version.os_version = Some("14.0.0".to_string());
    
    let mut buf = Vec::new();
    ControlPacket::Version(version).encode(&mut buf)?;
    tokio::io::AsyncWriteExt::write_all(&mut tls_stream, &buf).await?;

    let mut auth = msgs::Authenticate::default();
    auth.username = Some(username);
    auth.password = password;
    auth.opus = Some(true);
    
    buf.clear();
    ControlPacket::Authenticate(auth).encode(&mut buf)?;
    tokio::io::AsyncWriteExt::write_all(&mut tls_stream, &buf).await?;

    // Buffered Handshake: collect packets until ServerSync or Reject
    let mut initial_packets = Vec::new();
    loop {
        // We need to read from tls_stream. 
        // For simplicity during handshake, we'll use a wrapper or just manual read.
        // Since we don't have Framed anymore, we'll use a simple sync-like read for the handshake.
        let packet = {
            // This is a bit tricky because we want to use the async stream.
            // We can wrap it in a BufReader to use with ControlPacket::decode but that needs std::io::Read.
            // We'll use a small helper or just read the header first.
            let mut header = [0u8; 6];
            tokio::io::AsyncReadExt::read_exact(&mut tls_stream, &mut header).await?;
            let mut reader = BufReader::new(&header[..]);
            let id = byteorder::ReadBytesExt::read_u16::<byteorder::BigEndian>(&mut reader)?;
            let len = byteorder::ReadBytesExt::read_u32::<byteorder::BigEndian>(&mut reader)? as usize;
            
            let mut payload = vec![0u8; len];
            tokio::io::AsyncReadExt::read_exact(&mut tls_stream, &mut payload).await?;
            
            // Now decode from the full packet
            let mut full_packet = Vec::with_capacity(6 + len);
            full_packet.extend_from_slice(&header);
            full_packet.extend_from_slice(&payload);
            ControlPacket::decode(&mut &full_packet[..])?
        };

        match &packet {
            ControlPacket::ServerSync(_) => {
                initial_packets.push(packet);
                return Ok((tls_stream, initial_packets));
            }
            ControlPacket::Reject(rj) => {
                return Err(anyhow::anyhow!("Handshake rejected: {}", rj.reason));
            }
            _ => {
                initial_packets.push(packet);
            }
        }
    }
}

pub async fn run_loop(
    tls_stream: TlsStream<TcpStream>,
    host: String,
    port: u16,
    mut cmd_rx: mpsc::Receiver<MumbleCommand>,
    event_sink: StreamSink<MumbleEvent>,
    config: MumbleConfig,
    initial_packets: Vec<ControlPacket>,
) -> anyhow::Result<()> {
    let (vol_cmd_tx, vol_cmd_rx) = crossbeam_channel::unbounded();

    let mut session = MumbleSession::new(event_sink, config, vol_cmd_tx, vol_cmd_rx, host, port);
    let (mut tls_read, mut tls_write) = tokio::io::split(tls_stream);

    // Process buffered handshake packets
    for packet in initial_packets {
        session.handle_packet(packet, &mut tls_write).await?;
    }

    let mut ping_interval = tokio::time::interval(std::time::Duration::from_secs(15));
    let mut volume_interval = tokio::time::interval(std::time::Duration::from_millis(200));

    loop {
        tokio::select! {
            _ = ping_interval.tick() => {
                let mut ping = msgs::Ping::default();
                let timestamp = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_millis() as u64;
                ping.timestamp = Some(timestamp);
                let mut buf = Vec::new();
                if let Ok(_) = ControlPacket::Ping(ping).encode(&mut buf) {
                    let _ = tokio::io::AsyncWriteExt::write_all(&mut tls_write, &buf).await;
                }
            }
            _ = volume_interval.tick() => {
                let rms = f32::from_bits(session.current_rms.load(std::sync::atomic::Ordering::Relaxed));
                let _ = session.event_sink.add(MumbleEvent::AudioVolume(rms));
            }
            res = async {
                let mut header = [0u8; 6];
                tokio::io::AsyncReadExt::read_exact(&mut tls_read, &mut header).await?;
                let len = byteorder::ReadBytesExt::read_u32::<byteorder::BigEndian>(&mut &header[2..])? as usize;
                let mut payload = vec![0u8; len];
                tokio::io::AsyncReadExt::read_exact(&mut tls_read, &mut payload).await?;
                let mut full = Vec::with_capacity(6 + len);
                full.extend_from_slice(&header);
                full.extend_from_slice(&payload);
                ControlPacket::decode(&mut &full[..])
            } => {
                match res {
                    Ok(packet) => {
                        session.handle_packet(packet, &mut tls_write).await?
                    }
                    Err(e) => {
                        let _ = session.event_sink.add(MumbleEvent::Disconnected(format!("Protocol error: {}", e)));
                        break;
                    }
                }
            }
            cmd = cmd_rx.recv() => {
                match cmd {
                    Some(MumbleCommand::Disconnect) | None => break,
                    Some(cmd) => session.handle_command(cmd, &mut tls_write).await,
                }
            }
        }
    }

    Ok(())
}
