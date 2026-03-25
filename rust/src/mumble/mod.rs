pub mod codec;
pub mod dsp;
pub mod hardware;
pub mod net;
pub mod types;

pub use crate::api::client::MumbleEvent;
use crate::frb_generated::StreamSink;
use crate::mumble::types::MumbleConfig;
use tokio::sync::mpsc;

pub enum MumbleCommand {
    Disconnect,
    JoinChannel(u32),
    SendTextMessage(String),
    SetMute(bool),
    SetDeafen(bool),
    SetPtt(bool),
    SetUserVolume(u32, f32),
    SetOutputVolume(f32),
    SetInputGain(f32),
    UpdateConfig(MumbleConfig),
}

pub struct MumbleClient {
    pub cmd_tx: mpsc::Sender<MumbleCommand>,
}

impl MumbleClient {
    pub async fn start(
        host: String,
        port: u16,
        username: String,
        password: Option<String>,
        event_sink: StreamSink<MumbleEvent>,
        config: MumbleConfig,
    ) -> Result<Self, String> {
        let (cmd_tx, cmd_rx) = mpsc::channel(32);

        let event_sink_clone = event_sink.clone();

        // Perform connection and handshake in the current task so we can return errors
        let framed = match crate::mumble::net::control::connect(&host, port, username, password).await {
            Ok(f) => f,
            Err(e) => {
                let err_msg = format!("Failed to connect to mumble server: {}", e);
                return Err(err_msg);
            }
        };

        // Main loop runner
        tokio::spawn(async move {
            if let Err(e) =
                crate::mumble::net::control::run_loop(framed, host, port, cmd_rx, event_sink, config)
                    .await
            {
                eprintln!("Mumble client loop error: {}", e);
                let _ = event_sink_clone.add(MumbleEvent::Disconnected(e.to_string()));
            }
        });

        Ok(Self { cmd_tx })
    }
}