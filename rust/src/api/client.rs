use std::sync::Arc;
use tokio::sync::Mutex;
use flutter_rust_bridge::frb;
use crate::frb_generated::StreamSink;
use crate::mumble::{InternalMumbleClient, MumbleCommand};
use crate::mumble::audio::{list_input_devices as list_in, list_output_devices as list_out};

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    
    // Always use env_logger for visible output in flutter run
    let _ = env_logger::builder()
        .filter_level(log::LevelFilter::Debug)
        .parse_default_env()
        .try_init();
    
    log::info!("Rust initialised");
    println!("--- RUST: initialised ---");
}

#[derive(Debug, Clone)]
pub enum MumbleEvent {
    Connected(u32),
    Disconnected(String),
    ChannelUpdate(MumbleChannel),
    UserUpdate(MumbleUser),
    UserRemoved(u32),
    UserTalking(u32, bool),
    TextMessage(MumbleTextMessage),
    AudioVolume(f32),
}

#[derive(Debug, Clone)]
pub struct MumbleChannel {
    pub id: u32,
    pub name: String,
    pub parent_id: Option<u32>,
    pub position: i32,
    pub description: Option<String>,
    pub is_enter_restricted: bool,
}

#[derive(Debug, Clone)]
pub struct MumbleUser {
    pub session: u32,
    pub name: String,
    pub channel_id: u32,
    pub is_talking: bool,
    pub is_muted: bool,
    pub is_deafened: bool,
    pub is_suppressed: bool,
    pub comment: Option<String>,
}

#[derive(Debug, Clone)]
pub struct MumbleTextMessage {
    pub sender_name: String,
    pub message: String,
}

pub struct RustMumbleClient {
    runtime: tokio::runtime::Runtime,
    internal: Arc<Mutex<Option<InternalMumbleClient>>>,
}

impl RustMumbleClient {
    #[frb(sync)]
    pub fn new() -> Self {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        
        Self {
            runtime,
            internal: Arc::new(Mutex::new(None)),
        }
    }

    pub fn connect(
        &self,
        host: String,
        port: u16,
        username: String,
        password: Option<String>,
        event_sink: StreamSink<MumbleEvent>,
    ) -> Result<(), String> {
        let internal_arc = self.internal.clone();
        self.runtime.spawn(async move {
            match InternalMumbleClient::start(host, port, username, password, event_sink).await {
                Ok(client) => {
                    let mut internal = internal_arc.lock().await;
                    *internal = Some(client);
                }
                Err(e) => {
                    log::error!("Failed to start mumble client: {}", e);
                }
            }
        });
        Ok(())
    }

    #[frb(sync)]
    pub fn disconnect(&self) {
        let internal_arc = self.internal.clone();
        self.runtime.spawn(async move {
            let mut internal_guard = internal_arc.lock().await;
            if let Some(client) = internal_guard.take() {
                let _ = client.cmd_tx.send(MumbleCommand::Disconnect).await;
            }
        });
    }

    pub fn join_channel(&self, channel_id: u32) {
        self.send_command(MumbleCommand::JoinChannel(channel_id));
    }

    pub fn send_text_message(&self, message: String) {
        self.send_command(MumbleCommand::SendTextMessage(message));
    }

    pub fn set_ptt(&self, active: bool) {
        self.send_command(MumbleCommand::SetPtt(active));
    }

    pub fn set_mute(&self, mute: bool) {
        self.send_command(MumbleCommand::SetMute(mute));
    }

    pub fn set_deafen(&self, deafen: bool) {
        self.send_command(MumbleCommand::SetDeafen(deafen));
    }

    fn send_command(&self, cmd: MumbleCommand) {
        let internal_arc = self.internal.clone();
        self.runtime.spawn(async move {
            let internal = internal_arc.lock().await;
            if let Some(client) = &*internal {
                let _ = client.cmd_tx.send(cmd).await;
            }
        });
    }
}

pub fn list_audio_input_devices() -> Vec<String> {
    list_in()
}

pub fn list_audio_output_devices() -> Vec<String> {
    list_out()
}
