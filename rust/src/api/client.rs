use crate::frb_generated::StreamSink;
use crate::mumble::audio;
use crate::mumble::types::AudioDevice;
use crate::mumble::{InternalMumbleClient, MumbleCommand};
use flutter_rust_bridge::frb;
use std::sync::Arc;
use tokio::sync::Mutex;

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
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
    config: Arc<std::sync::Mutex<crate::mumble::types::MumbleConfig>>,
    event_sink: Arc<std::sync::Mutex<Option<StreamSink<MumbleEvent>>>>,
}

impl RustMumbleClient {
    #[frb(sync)]
    pub fn new() -> Self {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .unwrap();

        Self {
            runtime,
            internal: Arc::new(Mutex::new(None)),
            config: Arc::new(std::sync::Mutex::new(
                crate::mumble::types::MumbleConfig::default(),
            )),
            event_sink: Arc::new(std::sync::Mutex::new(None)),
        }
    }

    pub fn get_event_stream(&self, sink: StreamSink<MumbleEvent>) {
        let mut event_sink = self.event_sink.lock().unwrap();
        *event_sink = Some(sink);
    }

    pub async fn connect(
        &self,
        host: String,
        port: u16,
        username: String,
        password: Option<String>,
    ) -> Result<(), String> {
        let config = self.config.lock().unwrap().clone();
        let event_sink = {
            let sink = self.event_sink.lock().unwrap();
            sink.clone()
                .ok_or_else(|| "Event sink not set".to_string())?
        };

        // Spawn on the dedicated tokio runtime so Mumble logic runs there
        let handle = self.runtime.spawn(async move {
            InternalMumbleClient::start(host, port, username, password, event_sink, config).await
        });

        match handle.await.map_err(|e| e.to_string())? {
            Ok(client) => {
                let mut internal = self.internal.lock().await;
                *internal = Some(client);
                Ok(())
            }
            Err(e) => Err(e),
        }
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

    pub fn set_config(&self, config: crate::mumble::types::MumbleConfig) {
        if let Ok(mut cfg) = self.config.lock() {
            *cfg = config.clone();
        }
        self.send_command(MumbleCommand::UpdateConfig(config));
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

    pub fn set_input_gain(&self, gain: f32) {
        self.send_command(MumbleCommand::SetInputGain(gain));
    }

    pub fn set_output_volume(&self, volume: f32) {
        self.send_command(MumbleCommand::SetOutputVolume(volume));
    }

    pub fn set_user_volume(&self, session_id: u32, volume: f32) {
        self.send_command(MumbleCommand::SetUserVolume(session_id, volume));
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

pub fn list_audio_input_devices() -> Vec<AudioDevice> {
    audio::list_input_devices()
}

pub fn list_audio_output_devices() -> Vec<AudioDevice> {
    audio::list_output_devices()
}
