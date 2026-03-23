pub mod audio;
pub mod control;
pub mod voice;

use crate::api::client::MumbleEvent;
use crate::frb_generated::StreamSink;
use tokio::sync::mpsc;

pub enum MumbleCommand {
    Disconnect,
    JoinChannel(u32),
    SendTextMessage(String),
    SetMute(bool),
    SetDeafen(bool),
    SetPtt(bool),
}

pub struct InternalMumbleClient {
    pub cmd_tx: mpsc::Sender<MumbleCommand>,
}

impl InternalMumbleClient {
    pub async fn start(
        host: String,
        port: u16,
        username: String,
        password: Option<String>,
        event_sink: StreamSink<MumbleEvent>,
    ) -> anyhow::Result<Self> {
        let (cmd_tx, cmd_rx) = mpsc::channel(32);

        // Main loop runner
        tokio::spawn(async move {
            if let Err(e) =
                crate::mumble::control::run_loop(host, port, username, password, cmd_rx, event_sink)
                    .await
            {
                eprintln!("Mumble client loop error: {}", e);
            }
        });

        Ok(Self { cmd_tx })
    }
}
