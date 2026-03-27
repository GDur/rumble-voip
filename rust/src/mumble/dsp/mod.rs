pub mod capture;
pub mod playback;
pub mod user_stream;

use crate::mumble::config::{MumbleConfig, RbConsumer, RbProducer};
use crate::mumble::dsp::capture::CapturePipeline;
use crate::mumble::dsp::playback::PlaybackMixer;
use crate::api::client::AudioEvent;
use crossbeam_channel::{select, Receiver};
use ringbuf::traits::{Consumer, Observer, Producer};
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::Arc;

/// Internally and on the wire the sample rate is always 48khz
pub const INTERNAL_SAMPLE_RATE: u32 = 48000;

/// For internal processing the frame size is always 10ms. Can be different on the wire.
pub const INTERNAL_FRAME_MS: u32 = 10;
pub const INTERNAL_FRAME_SIZE: usize = (INTERNAL_SAMPLE_RATE * INTERNAL_FRAME_MS / 1000) as usize;

pub const MAX_PACKET_MS: u32 = 40; // Mumble uses 60
pub const MAX_OPUS_TARGET_BITRATE: u32 = 192000;

/// According to the OPUS spec 1275 is the maximum supported, the encoder must respect this and will adapt.
pub const MAX_OPUS_PACKET_SIZE: usize = 1275;

/// Maximum number of samples in an opus packet (48kHz * 40ms / 1000 = 1920 samples).
pub const MAX_PACKET_SAMPLES: usize = INTERNAL_SAMPLE_RATE as usize * MAX_PACKET_MS as usize / 1000;

#[derive(Debug, Clone)]
pub struct AudioPacket {
    payload: heapless::Vec<u8, MAX_OPUS_PACKET_SIZE>,
    is_last: bool,
}

impl AudioPacket {
    pub fn new(payload: heapless::Vec<u8, MAX_OPUS_PACKET_SIZE>, is_last: bool) -> Self {
        Self { payload, is_last }
    }

    pub fn payload(&self) -> &[u8] {
        &self.payload
    }

    pub fn is_last(&self) -> bool {
        self.is_last
    }
}

#[derive(Debug)]
pub struct IncomingAudio {
    session_id: u32,
    packet: AudioPacket,
}

impl IncomingAudio {
    pub fn new(session_id: u32, packet: AudioPacket) -> Self {
        Self { session_id, packet }
    }

    pub fn session_id(&self) -> u32 {
        self.session_id
    }

    pub fn packet(&self) -> &AudioPacket {
        &self.packet
    }

    pub fn into_packet(self) -> AudioPacket {
        self.packet
    }
}

pub fn spawn_encode_thread(
    mut cons_in: RbConsumer,
    input_notify: Receiver<()>,
    network_tx: tokio::sync::mpsc::Sender<AudioPacket>,
    ptt_active: Arc<AtomicBool>,
    input_rate: u32,
    config: MumbleConfig,
) {
    std::thread::spawn(move || {
        let mut pipeline = CapturePipeline::new(input_rate, &config);
        let mut was_ptt = false;

        loop {
            if input_notify.recv().is_err() {
                break;
            }

            let mut tmp = [0.0; 2048];
            while cons_in.occupied_len() > 0 {
                let popped = cons_in.pop_slice(&mut tmp);
                pipeline.push_pcm(&tmp[..popped]);
            }

            let ptt = ptt_active.load(Ordering::Relaxed);
            if !ptt {
                if was_ptt {
                    was_ptt = false;
                    // Send an empty packet to signal end of transmission.
                    let _ = network_tx.try_send(AudioPacket::new(heapless::Vec::new(), true));
                }
                pipeline.clear();
                continue;
            }

            was_ptt = true;
            for packet in pipeline.process() {
                let _ = network_tx.try_send(packet);
            }
        }
    });
}

pub fn spawn_decode_thread(
    mut prod_out: RbProducer,
    output_notify: Receiver<()>,
    udp_rx: Receiver<IncomingAudio>,
    event_sink: crate::frb_generated::StreamSink<AudioEvent>,
    output_rate: u32,
    config: MumbleConfig,
    global_volume: Arc<AtomicU32>,
    vol_cmd_rx: Receiver<(u32, f32)>, // (session_id, volume)
) {
    std::thread::spawn(move || {
        let mut mixer = PlaybackMixer::new(output_rate, &config, global_volume);
        // Ensure the jitter buffer has a baseline number of frames before playback feels stable.
        let target_latency_samples =
            (output_rate as f32 * (config.incoming_jitter_buffer_ms as f32 / 1000.0)) as usize;

        loop {
            select! {
                recv(vol_cmd_rx) -> msg => {
                    if let Ok((sid, vol)) = msg {
                        if let Some(user) = mixer.get_user_mut(sid) {
                            user.set_volume(vol);
                        }
                    }
                }
                recv(udp_rx) -> msg => {
                    if let Ok(incoming) = msg {
                        let sid = incoming.session_id();
                        let packet = incoming.into_packet();
                        let is_last = packet.is_last();
                        let is_empty = packet.payload().is_empty();

                        let user = mixer.get_or_insert_user(sid);
                        user.update_last_packet_time();

                        // Track user talking state.
                        if !user.is_talking() && !is_empty {
                            user.set_talking(true);
                            let _ = event_sink.add(AudioEvent::UserTalking(sid, true));
                        }

                        // Push audio packet to user stream if not empty.
                        if !is_empty {
                            user.push_packet(packet);
                        }

                        // Stop talking state if signalled by the network packet.
                        if is_last {
                            user.set_talking(false);
                            let _ = event_sink.add(AudioEvent::UserTalking(sid, false));
                        }
                    } else {
                        break;
                    }
                }
                recv(output_notify) -> msg => {
                    if msg.is_err() { break; }

                    // Fill the output ring buffer until target latency is reached.
                    while prod_out.occupied_len() < target_latency_samples {
                        let frame = mixer.mix_frame(&event_sink);
                        let _ = prod_out.push_slice(frame);

                        // Break if there's not enough space for another full frame.
                        if prod_out.vacant_len() < mixer.output_samples_per_frame() {
                            break;
                        }
                    }
                }
            }
        }
    });
}
