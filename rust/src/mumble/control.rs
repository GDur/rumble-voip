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

pub async fn run_loop(
    host: String,
    port: u16,
    username: String,
    password: Option<String>,
    mut cmd_rx: mpsc::Receiver<MumbleCommand>,
    event_sink: StreamSink<MumbleEvent>,
    config: MumbleConfig,
) -> anyhow::Result<()> {
    // Setup TLS with OpenSSL
    let mut builder = SslConnector::builder(SslMethod::tls())?;
    builder.set_verify(SslVerifyMode::NONE);

    let connector = builder.build();
    let tcp_stream = TcpStream::connect(format!("{}:{}", host, port)).await?;

    let ssl = connector.configure()?.into_ssl(&host)?;
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

    let mut channels: HashMap<u32, MumbleChannel> = HashMap::new();
    let mut users: HashMap<u32, MumbleUser> = HashMap::new();
    let mut voice_cmd_tx: Option<mpsc::Sender<MumbleCommand>> = None;
    let mut _active_audio: Option<AudioStreams> = None;

    let mut session_id = 0;
    let mut my_channel_id = 0;
    let mut ping_interval = tokio::time::interval(std::time::Duration::from_secs(15));
    let mut volume_interval = tokio::time::interval(std::time::Duration::from_millis(200));

    let current_rms = Arc::new(AtomicU32::new(0.0f32.to_bits()));
    let global_volume = Arc::new(AtomicU32::new(1.0f32.to_bits()));
    let input_gain = Arc::new(AtomicU32::new(1.0f32.to_bits()));
    let (vol_cmd_tx, vol_cmd_rx) = crossbeam_channel::unbounded();

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
                let rms = f32::from_bits(current_rms.load(std::sync::atomic::Ordering::Relaxed));
                let _ = event_sink.add(MumbleEvent::AudioVolume(rms));
            }
            packet = framed.next() => {
                match packet {
                    Some(Ok(ControlPacket::ServerSync(ss))) => {
                        session_id = ss.session();
                        let _ = event_sink.add(MumbleEvent::Connected(session_id));
                    }
                    Some(Ok(ControlPacket::ChannelState(cs))) => {
                        let id = cs.channel_id();
                        let channel = MumbleChannel {
                            id,
                            name: cs.name().to_string(),
                            parent_id: if cs.has_parent() { Some(cs.parent()) } else { None },
                            position: cs.position(),
                            description: if cs.has_description() { Some(cs.description().to_string()) } else { None },
                            is_enter_restricted: false,
                        };
                        channels.insert(id, channel.clone());
                        let _ = event_sink.add(MumbleEvent::ChannelUpdate(channel));
                    }
                    Some(Ok(ControlPacket::UserState(us))) => {
                        let session = us.session();
                        if session == session_id {
                            my_channel_id = us.channel_id();
                        }
                        let user = MumbleUser {
                            session,
                            name: us.name().to_string(),
                            channel_id: us.channel_id(),
                            is_talking: false,
                            is_muted: us.self_mute() || us.mute(),
                            is_deafened: us.self_deaf() || us.deaf(),
                            is_suppressed: us.suppress(),
                            comment: if us.has_comment() { Some(us.comment().to_string()) } else { None },
                        };
                        users.insert(session, user.clone());
                        let _ = event_sink.add(MumbleEvent::UserUpdate(user));
                    }
                    Some(Ok(ControlPacket::UserRemove(ur))) => {
                        users.remove(&ur.session());
                        let _ = event_sink.add(MumbleEvent::UserRemoved(ur.session()));
                    }
                    Some(Ok(ControlPacket::Ping(ping))) => {
                        let _ = framed.send(ControlPacket::Ping(ping)).await;
                    }
                    Some(Ok(ControlPacket::TextMessage(tm))) => {
                        let sender_name = users.get(&tm.actor()).map(|u| u.name.clone()).unwrap_or_else(|| "Unknown".to_string());
                        let _ = event_sink.add(MumbleEvent::TextMessage(MumbleTextMessage {
                            sender_name,
                            message: tm.message().to_string(),
                        }));
                    }
                    Some(Ok(ControlPacket::CryptSetup(cs))) => {
                        if let Some(v_tx) = voice_cmd_tx.take() {
                            let _ = v_tx.send(MumbleCommand::Disconnect).await;
                        }

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

                        let crypt_state = mumble_protocol_2x::crypt::CryptState::new_from(key, encrypt_nonce, decrypt_nonce);

                        let (v_tx, v_rx) = mpsc::channel(32);
                        voice_cmd_tx = Some(v_tx);
                        let event_sink_clone = event_sink.clone();

                        use ringbuf::traits::Split;
                        use ringbuf::HeapRb;

                        let rb_in = HeapRb::<f32>::new(8192);
                        let rb_out = HeapRb::<f32>::new(8192);
                        let (prod_in, cons_in) = rb_in.split();
                        let (prod_out, cons_out) = rb_out.split();

                        let (in_notify_tx, in_notify_rx) = crossbeam_channel::bounded(10);
                        let (out_notify_tx, out_notify_rx) = crossbeam_channel::bounded(10);
                        let (network_tx, network_rx) = tokio::sync::mpsc::channel(100);
                        let (udp_tx, udp_rx) = crossbeam_channel::bounded(100);

                        let ptt_active = Arc::new(AtomicBool::new(false));

                        match setup_audio(prod_in, cons_out, in_notify_tx, out_notify_tx, current_rms.clone(), input_gain.clone(), &config) {
                            Ok(audio_streams) => {
                                spawn_encode_thread(
                                    cons_in,
                                    in_notify_rx,
                                    network_tx,
                                    ptt_active.clone(),
                                    audio_streams.input_rate,
                                    config.clone(),
                                );

                                spawn_decode_thread(
                                    prod_out,
                                    out_notify_rx,
                                    udp_rx,
                                    event_sink_clone.clone(),
                                    audio_streams.output_rate,
                                    config.clone(),
                                    global_volume.clone(),
                                    vol_cmd_rx.clone(),
                                );

                                _active_audio = Some(audio_streams);

                                let host_clone = host.clone();
                                let port_clone = port;

                                tokio::spawn(async move {
                                    if let Err(e) = crate::mumble::voice::VoiceHandler::run(
                                        format!("{}:{}", host_clone, port_clone),
                                        crypt_state,
                                        v_rx,
                                        network_rx,
                                        udp_tx,
                                        event_sink_clone,
                                        ptt_active,
                                    ).await {
                                        eprintln!("Voice handler error: {}", e);
                                    }
                                });
                            }
                            Err(e) => {
                                eprintln!("Failed to setup audio: {}", e);
                            }
                        }
                    }
                    Some(Err(e)) => {
                        let _ = event_sink.add(MumbleEvent::Disconnected(format!("Protocol error: {}", e)));
                        break;
                    }
                    None => {
                        let _ = event_sink.add(MumbleEvent::Disconnected("Server closed connection".to_string()));
                        break;
                    }
                    _ => {}
                }
            }
            cmd = cmd_rx.recv() => {
                match cmd {
                    Some(MumbleCommand::Disconnect) | None => break,
                    Some(MumbleCommand::JoinChannel(id)) => {
                        let mut us = msgs::UserState::new();
                        us.set_channel_id(id);
                        let _ = framed.send(ControlPacket::UserState(Box::new(us))).await;
                    }
                    Some(MumbleCommand::SendTextMessage(msg)) => {
                        let mut tm = msgs::TextMessage::new();
                        tm.set_message(msg);
                        tm.channel_id.push(my_channel_id);
                        let _ = framed.send(ControlPacket::TextMessage(Box::new(tm))).await;
                    }
                    Some(MumbleCommand::SetMute(mute)) => {
                        let mut us = msgs::UserState::new();
                        us.set_self_mute(mute);
                        let _ = framed.send(ControlPacket::UserState(Box::new(us))).await;
                    }
                    Some(MumbleCommand::SetDeafen(deafen)) => {
                        let mut us = msgs::UserState::new();
                        us.set_self_deaf(deafen);
                        if deafen { us.set_self_mute(true); }
                        let _ = framed.send(ControlPacket::UserState(Box::new(us))).await;
                    }
                    Some(MumbleCommand::SetPtt(active)) => {
                        if let Some(v_tx) = &voice_cmd_tx {
                            let _ = v_tx.send(MumbleCommand::SetPtt(active)).await;
                        }
                    }
                    Some(MumbleCommand::SetUserVolume(sid, vol)) => {
                        let _ = vol_cmd_tx.send((sid, vol));
                    }
                    Some(MumbleCommand::SetOutputVolume(vol)) => {
                        global_volume.store(vol.to_bits(), std::sync::atomic::Ordering::Relaxed);
                    }
                    Some(MumbleCommand::SetInputGain(gain)) => {
                        input_gain.store(gain.to_bits(), std::sync::atomic::Ordering::Relaxed);
                    }
                }
            }
        }
    }

    Ok(())
}
