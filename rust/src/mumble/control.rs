use std::sync::Arc;
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
    // 1. Setup TLS with OpenSSL
    let mut builder = SslConnector::builder(SslMethod::tls())?;
    
    // For Mumble, we often want to allow self-signed certs or handle verification manually
    // For now, we'll use the default system roots (handled by openssl-vendored)
    // but disable strict verification if needed for certain servers.
    builder.set_verify(SslVerifyMode::NONE); 

    let connector = builder.build();
    let tcp_stream = TcpStream::connect(format!("{}:{}", host, port)).await?;
    
    let ssl = connector.configure()?.into_ssl(&host)?;
    let mut tls_stream = SslStream::new(ssl, tcp_stream)?;
    
    // Perform the TLS handshake
    Pin::new(&mut tls_stream).connect().await
        .map_err(|e| anyhow::anyhow!("TLS connection failed: {}", e))?;

    let mut framed = Framed::new(tls_stream, ControlCodec::<Serverbound, Clientbound>::new());

    // 2. Authenticate
    let mut auth = msgs::Authenticate::new();
    auth.set_username(username);
    if let Some(p) = password {
        auth.set_password(p);
    }
    auth.set_opus(true);
    framed.send(ControlPacket::Authenticate(Box::new(auth))).await?;

    let mut channels: HashMap<u32, MumbleChannel> = HashMap::new();
    let mut users: HashMap<u32, MumbleUser> = HashMap::new();
    let mut _crypt_setup = None;

    // 3. Main Loop
    let mut session_id = 0;

    loop {
        tokio::select! {
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
                    Some(Ok(ControlPacket::TextMessage(tm))) => {
                        let sender_name = users.get(&tm.actor()).map(|u| u.name.clone()).unwrap_or_else(|| "Unknown".to_string());
                        let _ = event_sink.add(MumbleEvent::TextMessage(MumbleTextMessage {
                            sender_name,
                            message: tm.message().to_string(),
                        }));
                    }
                    Some(Ok(ControlPacket::CryptSetup(cs))) => {
                         _crypt_setup = Some(cs);
                    }
                    Some(Ok(_)) => {}
                    Some(Err(e)) => {
                        let _ = event_sink.add(MumbleEvent::Disconnected(format!("Protocol error: {}", e)));
                        break;
                    }
                    None => {
                        let _ = event_sink.add(MumbleEvent::Disconnected("Server closed connection".to_string()));
                        break;
                    }
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
                        framed.send(ControlPacket::TextMessage(Box::new(tm))).await?;
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
                    _ => {}
                }
            }
        }
    }

    Ok(())
}
