use tokio::sync::mpsc;
use futures_util::{StreamExt, SinkExt};
use tokio_util::codec::Framed;
use mumble_protocol_2x::control::ControlPacket;
use mumble_protocol_2x::control::ControlCodec;
use mumble_protocol_2x::control::msgs;
use mumble_protocol_2x::voice::{Serverbound, Clientbound};
use tokio::net::TcpStream;
use openssl::ssl::{SslMethod, SslConnector, SslVerifyMode};
use tokio_openssl::SslStream;
use std::pin::Pin;
use std::collections::HashMap;
use crate::api::client::{MumbleEvent, MumbleChannel, MumbleUser, MumbleTextMessage};
use crate::frb_generated::StreamSink;
use crate::mumble::MumbleCommand;

pub async fn run_loop(
    host: String,
    port: u16,
    username: String,
    password: Option<String>,
    mut cmd_rx: mpsc::Receiver<MumbleCommand>,
    event_sink: StreamSink<MumbleEvent>,
) -> anyhow::Result<()> {
    log::info!("Starting control loop for {}:{}", host, port);
    println!("--- RUST: control loop starting for {}:{} ---", host, port);
    
    // 1. Setup TLS with OpenSSL
    let mut builder = SslConnector::builder(SslMethod::tls())?;
    builder.set_verify(SslVerifyMode::NONE); 

    let connector = builder.build();
    let tcp_stream = TcpStream::connect(format!("{}:{}", host, port)).await?;
    log::info!("TCP connected to {}:{}", host, port);
    
    let ssl = connector.configure()?.into_ssl(&host)?;
    let mut tls_stream = SslStream::new(ssl, tcp_stream)?;
    
    Pin::new(&mut tls_stream).connect().await
        .map_err(|e| anyhow::anyhow!("TLS connection failed: {}", e))?;
    log::info!("TLS handshake successful");

    let mut framed = Framed::new(tls_stream, ControlCodec::<Serverbound, Clientbound>::new());

    // 2. Authenticate
    let mut auth = msgs::Authenticate::new();
    auth.set_username(username);
    if let Some(p) = password {
        auth.set_password(p);
    }
    auth.set_opus(true);
    framed.send(ControlPacket::Authenticate(Box::new(auth))).await?;
    log::info!("Authentication packet sent");

    let mut channels: HashMap<u32, MumbleChannel> = HashMap::new();
    let mut users: HashMap<u32, MumbleUser> = HashMap::new();
    let mut voice_cmd_tx: Option<mpsc::Sender<MumbleCommand>> = None;

    // 3. Main Loop
    let mut session_id = 0;
    let mut my_channel_id = 0;
    let mut ping_interval = tokio::time::interval(std::time::Duration::from_secs(15));

    loop {
        tokio::select! {
            _ = ping_interval.tick() => {
                let mut ping = msgs::Ping::new();
                let timestamp = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_millis() as u64;
                ping.set_timestamp(timestamp);
                if let Err(e) = framed.send(ControlPacket::Ping(Box::new(ping))).await {
                    log::error!("Failed to send TCP Ping: {}", e);
                }
            }
            packet = framed.next() => {
                match packet {
                    Some(Ok(ControlPacket::ServerSync(ss))) => {
                        session_id = ss.session();
                        log::info!("ServerSync received. Session ID: {}", session_id);
                        println!("--- RUST: connected as session {} ---", session_id);
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
                        framed.send(ControlPacket::Ping(ping)).await?;
                    }
                    Some(Ok(ControlPacket::TextMessage(tm))) => {
                        let sender_name = users.get(&tm.actor()).map(|u| u.name.clone()).unwrap_or_else(|| "Unknown".to_string());
                        let _ = event_sink.add(MumbleEvent::TextMessage(MumbleTextMessage {
                            sender_name,
                            message: tm.message().to_string(),
                        }));
                    }
                    Some(Ok(ControlPacket::CryptSetup(cs))) => {
                         log::info!("CryptSetup received, starting VoiceHandler");
                         println!("--- RUST: CryptSetup received, starting VoiceHandler ---");

                         // Stop old voice handler if any
                         if let Some(v_tx) = voice_cmd_tx.take() {
                             let _ = v_tx.send(MumbleCommand::Disconnect).await;
                         }

                         let mut key = [0u8; 16];
                         let mut encrypt_nonce = [0u8; 16];
                         let mut decrypt_nonce = [0u8; 16];
                         
                         if let Some(k) = &cs.key {
                             if k.len() >= 16 {
                                key.copy_from_slice(&k[..16]);
                             }
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
                         
                         let host_clone = host.clone();
                         let port_clone = port;
                         let (v_tx, v_rx) = mpsc::channel(32);
                         voice_cmd_tx = Some(v_tx);
                         let event_sink_clone = event_sink.clone();
                         
                         tokio::spawn(async move {
                             if let Err(e) = crate::mumble::voice::VoiceHandler::run(
                                 format!("{}:{}", host_clone, port_clone),
                                 crypt_state,
                                 v_rx,
                                 event_sink_clone,
                             ).await {
                                 log::error!("Voice handler error: {}", e);
                                 println!("--- RUST: Voice handler error: {} ---", e);
                             }
                         });
                    }
                    Some(Err(e)) => {
                        log::error!("Protocol error: {}", e);
                        let _ = event_sink.add(MumbleEvent::Disconnected(format!("Protocol error: {}", e)));
                        break;
                    }
                    None => {
                        log::info!("Server closed connection");
                        let _ = event_sink.add(MumbleEvent::Disconnected("Server closed connection".to_string()));
                        break;
                    }
                    _ => {}
                }
            }
            cmd = cmd_rx.recv() => {
                match cmd {
                    Some(MumbleCommand::Disconnect) => break,
                    Some(MumbleCommand::JoinChannel(id)) => {
                        let mut us = msgs::UserState::new();
                        us.set_channel_id(id);
                        framed.send(ControlPacket::UserState(Box::new(us))).await?;
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
                        framed.send(ControlPacket::UserState(Box::new(us))).await?;
                    }
                    Some(MumbleCommand::SetDeafen(deafen)) => {
                        let mut us = msgs::UserState::new();
                        us.set_self_deaf(deafen);
                        if deafen { us.set_self_mute(true); }
                        framed.send(ControlPacket::UserState(Box::new(us))).await?;
                    }
                    Some(MumbleCommand::SetPtt(active)) => {
                        if let Some(v_tx) = &voice_cmd_tx {
                            let _ = v_tx.send(MumbleCommand::SetPtt(active)).await;
                        }
                    }
                    _ => {}
                }
            }
        }
    }

    Ok(())
}
