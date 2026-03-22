use std::sync::Arc;
use tokio::sync::{mpsc, Mutex};
use tokio::net::UdpSocket;
use mumble_protocol_2x::crypt::CryptState;
use mumble_protocol_2x::voice::{Serverbound, Clientbound};
use opus_rs::{Application, OpusEncoder};
use crate::mumble::audio::AudioManager;
use crate::mumble::MumbleCommand;
use ringbuf::traits::{Consumer, Observer};

pub struct VoiceHandler;

impl VoiceHandler {
    pub async fn run(
        server_addr: String,
        _crypt_state: CryptState<Serverbound, Clientbound>,
        mut audio_manager: AudioManager,
        mut cmd_rx: mpsc::Receiver<MumbleCommand>,
    ) -> anyhow::Result<()> {
        let socket = UdpSocket::bind("0.0.0.0:0").await?;
        socket.connect(server_addr).await?;

        let mut _encoder = OpusEncoder::new(48000, 1, Application::Voip)
            .map_err(|e| anyhow::anyhow!("{}", e))?;
        
        let ptt_active = Arc::new(Mutex::new(false));

        let mut pcm_frame = vec![0i16; 960];
        let mut f32_frame = vec![0.0f32; 960];
        let mut _opus_buf = vec![0u8; 1024];

        let mut _udp_buf = vec![0u8; 2048];

        loop {
            tokio::select! {
                cmd = cmd_rx.recv() => {
                    match cmd {
                        Some(MumbleCommand::SetPtt(active)) => {
                            let mut ptt = ptt_active.lock().await;
                            *ptt = active;
                        }
                        _ => {}
                    }
                }
                
                _ = tokio::time::sleep(std::time::Duration::from_millis(10)) => {
                    let is_ptt = *ptt_active.lock().await;
                    if is_ptt {
                        if audio_manager.input_consumer.occupied_len() >= 960 {
                            let _ = audio_manager.input_consumer.pop_slice(&mut pcm_frame);
                            for (i, &sample) in pcm_frame.iter().enumerate() {
                                f32_frame[i] = sample as f32 / 32768.0;
                            }
                            // Encoding and sending logic
                        }
                    }
                }

                res = socket.recv(&mut _udp_buf) => {
                    if let Ok(_len) = res {
                        // Decoding and playback logic
                    }
                }
            }
        }
    }
}
