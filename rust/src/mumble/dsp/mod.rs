pub mod capture;
pub mod playback;
pub mod resample;
pub mod user_stream;

use crate::frb_generated::StreamSink;
use crate::mumble::dsp::playback::PlaybackMixer;
use crate::mumble::dsp::capture::CapturePipeline;
use crate::mumble::types::{AudioPacket, IncomingAudio, MumbleConfig, RbConsumer, RbProducer};
use crate::mumble::MumbleEvent;
use crossbeam_channel::{select, Receiver};
use ringbuf::traits::{Consumer, Observer, Producer};
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::Arc;

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
    event_sink: StreamSink<MumbleEvent>,
    output_rate: u32,
    config: MumbleConfig,
    global_volume: Arc<AtomicU32>,
    vol_cmd_rx: Receiver<(u32, f32)>, // (session_id, volume)
) {
    std::thread::spawn(move || {
        let mut mixer = PlaybackMixer::new(output_rate, &config, global_volume);
        let target_latency_frames =
            (output_rate as f32 * (config.jitter_buffer_ms as f32 / 1000.0)) as usize;

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
                        if !user.is_talking() && !is_empty {
                            user.set_talking(true);
                            let _ = event_sink.add(MumbleEvent::UserTalking(sid, true));
                        }

                        if is_last {
                            user.set_talking(false);
                            let _ = event_sink.add(MumbleEvent::UserTalking(sid, false));
                        } else {
                            user.push_packet(packet);
                        }
                    } else {
                        break;
                    }
                }
                recv(output_notify) -> msg => {
                    if msg.is_err() { break; }

                    while prod_out.occupied_len() < target_latency_frames {
                        let frame = mixer.mix_frame(&event_sink);
                        let _ = prod_out.push_slice(frame);

                        if prod_out.vacant_len() < mixer.out_frame_size() {
                            break;
                        }
                    }
                }
            }
        }
    });
}
