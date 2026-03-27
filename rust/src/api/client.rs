use crate::frb_generated::StreamSink;
use crate::mumble::hardware::audio::{self, AudioDevice};
use crate::mumble::{MumbleCommand};
use flutter_rust_bridge::frb;
use std::sync::Arc;
use tokio::sync::Mutex;
use ringbuf::traits::Split;
use ringbuf::HeapRb;
use crossbeam_channel::unbounded;

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[derive(Debug, Clone)]
pub enum AudioEvent {
    AudioVolume(f32),
    UserTalking(u32, bool),
    Disconnected(String),
}

#[derive(Debug, Clone, Default)]
pub struct MumbleChannel {
    pub id: u32,
    pub name: String,
    pub parent_id: Option<u32>,
    pub position: i32,
    pub description: Option<String>,
    pub is_enter_restricted: bool,
}

#[derive(Debug, Clone, Default)]
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

pub struct RustAudioEngine {
    runtime: tokio::runtime::Runtime,
    config: Arc<std::sync::Mutex<crate::mumble::config::MumbleConfig>>,
    event_sink: Arc<std::sync::Mutex<Option<StreamSink<AudioEvent>>>>,
    voice_cmd_tx: Arc<Mutex<Option<tokio::sync::mpsc::Sender<crate::mumble::net::voice::VoiceCommand>>>>,
    ptt_active: Arc<std::sync::atomic::AtomicBool>,
    current_rms: Arc<std::sync::atomic::AtomicU32>,
    global_volume: Arc<std::sync::atomic::AtomicU32>,
    input_gain: Arc<std::sync::atomic::AtomicU32>,
    vol_cmd_tx: crossbeam_channel::Sender<(u32, f32)>,
    vol_cmd_rx: crossbeam_channel::Receiver<(u32, f32)>,
    _active_audio: Arc<Mutex<Option<crate::mumble::hardware::audio::AudioBackend>>>,
}

impl RustAudioEngine {
    #[frb(sync)]
    pub fn new() -> Self {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .unwrap();

        let (vol_cmd_tx, vol_cmd_rx) = unbounded();

        Self {
            runtime,
            config: Arc::new(std::sync::Mutex::new(
                crate::mumble::config::MumbleConfig::default(),
            )),
            event_sink: Arc::new(std::sync::Mutex::new(None)),
            voice_cmd_tx: Arc::new(Mutex::new(None)),
            ptt_active: Arc::new(std::sync::atomic::AtomicBool::new(false)),
            current_rms: Arc::new(std::sync::atomic::AtomicU32::new(0.0f32.to_bits())),
            global_volume: Arc::new(std::sync::atomic::AtomicU32::new(1.0f32.to_bits())),
            input_gain: Arc::new(std::sync::atomic::AtomicU32::new(1.0f32.to_bits())),
            vol_cmd_tx,
            vol_cmd_rx,
            _active_audio: Arc::new(Mutex::new(None)),
        }
    }

    pub fn get_event_stream(&self, sink: StreamSink<AudioEvent>) {
        let mut event_sink = self.event_sink.lock().unwrap();
        *event_sink = Some(sink);
        
        let sink_clone = self.event_sink.clone();
        let rms = self.current_rms.clone();
        self.runtime.spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_millis(100));
            loop {
                interval.tick().await;
                let s = sink_clone.lock().unwrap();
                if let Some(sink) = s.as_ref() {
                    let val = f32::from_bits(rms.load(std::sync::atomic::Ordering::Relaxed));
                    let _ = sink.add(AudioEvent::AudioVolume(val));
                } else {
                    break;
                }
            }
        });
    }

    pub async fn initialize_audio(
        &self,
        host: String,
        port: u16,
        key: Vec<u8>,
        encrypt_nonce: Vec<u8>,
        decrypt_nonce: Vec<u8>,
    ) -> Result<(), String> {
        let mut key_arr = [0u8; 16];
        let mut enc_nonce_arr = [0u8; 16];
        let mut dec_nonce_arr = [0u8; 16];
        
        key_arr[..key.len().min(16)].copy_from_slice(&key[..key.len().min(16)]);
        enc_nonce_arr[..encrypt_nonce.len().min(16)].copy_from_slice(&encrypt_nonce[..encrypt_nonce.len().min(16)]);
        dec_nonce_arr[..decrypt_nonce.len().min(16)].copy_from_slice(&decrypt_nonce[..decrypt_nonce.len().min(16)]);

        let crypt_state = mumble_protocol_2x::crypt::CryptState::new_from(key_arr, enc_nonce_arr, dec_nonce_arr);
        
        let (v_tx, v_rx) = tokio::sync::mpsc::channel(32);
        let (network_tx, network_rx) = tokio::sync::mpsc::channel(100);
        let (udp_tx, udp_rx) = crossbeam_channel::bounded(100);

        {
            let mut v_guard = self.voice_cmd_tx.lock().await;
            *v_guard = Some(v_tx);
        }

        let host_clone = host.clone();
        let port_clone = port;
        
        self.runtime.spawn(async move {
            if let Err(e) = crate::mumble::net::voice::VoiceChannel::run(
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

        let config = self.config.lock().unwrap().clone();
        let ptt_active = self.ptt_active.clone();
        let current_rms = self.current_rms.clone();
        let input_gain = self.input_gain.clone();
        let global_volume = self.global_volume.clone();
        let vol_cmd_rx = self.vol_cmd_rx.clone();
        let event_sink = self.event_sink.lock().unwrap().clone().ok_or("Event sink not set".to_string())?;

        let rb_in = HeapRb::<f32>::new(8192);
        let rb_out = HeapRb::<f32>::new(8192);
        let (prod_in, cons_in) = rb_in.split();
        let (prod_out, cons_out) = rb_out.split();

        let (in_notify_tx, in_notify_rx) = crossbeam_channel::bounded(10);
        let (out_notify_tx, out_notify_rx) = crossbeam_channel::bounded(10);

        let audio_backend = crate::mumble::hardware::audio::setup_audio(
                prod_in,
                cons_out,
                in_notify_tx,
                out_notify_tx,
                current_rms,
                input_gain,
                &config,
            ).map_err(|e| e.to_string())?;

        let input_rate = audio_backend.input_rate();
        let output_rate = audio_backend.output_rate();

        crate::mumble::dsp::spawn_encode_thread(
            cons_in,
            in_notify_rx,
            network_tx,
            ptt_active,
            input_rate,
            config.clone(),
        );

        crate::mumble::dsp::spawn_decode_thread(
            prod_out,
            out_notify_rx,
            udp_rx,
            event_sink,
            output_rate,
            config,
            global_volume,
            vol_cmd_rx,
        );

        let mut guard = self._active_audio.lock().await;
        *guard = Some(audio_backend);

        Ok(())
    }

    pub fn disconnect(&self) {
        let v_tx_arc = self.voice_cmd_tx.clone();
        self.runtime.spawn(async move {
            let mut v_guard = v_tx_arc.lock().await;
            if let Some(tx) = v_guard.take() {
                let _ = tx.send(crate::mumble::net::voice::VoiceCommand::Disconnect).await;
            }
        });
    }

    pub fn set_config(&self, config: crate::mumble::config::MumbleConfig) {
        if let Ok(mut cfg) = self.config.lock() {
            *cfg = config.clone();
        }
    }

    pub fn set_ptt(&self, active: bool) {
        self.ptt_active.store(active, std::sync::atomic::Ordering::Relaxed);
    }

    pub fn set_input_gain(&self, gain: f32) {
        self.input_gain.store(gain.to_bits(), std::sync::atomic::Ordering::Relaxed);
    }

    pub fn set_output_volume(&self, volume: f32) {
        self.global_volume.store(volume.to_bits(), std::sync::atomic::Ordering::Relaxed);
    }

    pub fn set_user_volume(&self, session_id: u32, volume: f32) {
        let _ = self.vol_cmd_tx.send((session_id, volume));
    }
}

pub fn list_audio_input_devices() -> Vec<AudioDevice> {
    audio::list_input_devices()
}

pub fn list_audio_output_devices() -> Vec<AudioDevice> {
    audio::list_output_devices()
}
