use crate::api::client::MumbleEvent;
use crate::frb_generated::StreamSink;
use crate::mumble::codec::{SafeOpusDecoder, SafeOpusEncoder};
use crate::mumble::resample::AudioResampler;
use crate::mumble::types::{AudioPacket, IncomingAudio, MumbleConfig, RbConsumer, RbProducer};
use bytes::BytesMut;
use crossbeam_channel::{select, Receiver};
use opus_head_sys::*;
use ringbuf::traits::{Consumer, Observer, Producer};
use std::collections::{HashMap, VecDeque};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

struct RemoteUser {
    decoder: SafeOpusDecoder,
    jitter_buffer: VecDeque<AudioPacket>,
    is_talking: bool,
    last_packet_time: std::time::Instant,
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
        let sample_rate = crate::mumble::types::MUMBLE_SAMPLE_RATE;
        let frame_ms = config.audio_frame_ms;
        let frame_size = (sample_rate * frame_ms / 1000) as usize;

        let encoder =
            SafeOpusEncoder::new(sample_rate as i32, 1, OPUS_APPLICATION_VOIP as i32).unwrap();
        encoder.ctl(OPUS_SET_VBR_REQUEST as i32, 1);
        encoder.ctl(OPUS_SET_INBAND_FEC_REQUEST as i32, 1);
        encoder.ctl(OPUS_SET_PACKET_LOSS_PERC_REQUEST as i32, 10);
        encoder.ctl(OPUS_SET_BITRATE_REQUEST as i32, config.audio_bitrate as i32);
        encoder.ctl(
            OPUS_SET_COMPLEXITY_REQUEST as i32,
            config.opus_complexity as i32,
        );

        let mut resampler = if input_rate != sample_rate {
            Some(AudioResampler::new(input_rate, sample_rate, config.audio_frame_ms).unwrap())
        } else {
            None
        };

        let mut pcm_buffer = Vec::with_capacity(8192);
        let mut f32_48k_buffer = Vec::with_capacity(8192);
        let mut opus_buf = vec![0u8; 1024];
        let mut payload_buf = BytesMut::with_capacity(4096);
        let mut was_ptt = false;

        loop {
            if input_notify.recv().is_err() {
                break; // Exit thread
            }

            let mut tmp = [0.0; 2048];
            while cons_in.occupied_len() > 0 {
                let popped = cons_in.pop_slice(&mut tmp);
                pcm_buffer.extend_from_slice(&tmp[..popped]);
            }

            let ptt = ptt_active.load(Ordering::Relaxed);

            if let Some(res) = &mut resampler {
                res.process(&pcm_buffer, &mut f32_48k_buffer);
                pcm_buffer.clear();
            } else {
                f32_48k_buffer.extend_from_slice(&pcm_buffer);
                pcm_buffer.clear();
            }

            while f32_48k_buffer.len() >= frame_size {
                if ptt {
                    was_ptt = true;
                    if let Ok(len) =
                        encoder.encode(&f32_48k_buffer[..frame_size], frame_size, &mut opus_buf)
                    {
                        payload_buf.clear();
                        payload_buf.extend_from_slice(&opus_buf[..len]);
                        let packet = AudioPacket {
                            payload: payload_buf.split_to(len).freeze(),
                            is_last: false,
                        };
                        let _ = network_tx.try_send(packet);
                    }
                } else if was_ptt {
                    was_ptt = false;
                    let packet = AudioPacket {
                        payload: bytes::Bytes::new(),
                        is_last: true,
                    };
                    let _ = network_tx.try_send(packet);
                }
                f32_48k_buffer.drain(..frame_size);
            }

            if !ptt {
                f32_48k_buffer.clear(); // Drop samples to save CPU when idle
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
) {
    std::thread::spawn(move || {
        let sample_rate = crate::mumble::types::MUMBLE_SAMPLE_RATE;
        let frame_ms = config.audio_frame_ms;
        let frame_size = (sample_rate * frame_ms / 1000) as usize;

        let mut resampler = if output_rate != sample_rate {
            Some(AudioResampler::new(sample_rate, output_rate, config.audio_frame_ms).unwrap())
        } else {
            None
        };

        let mut users: HashMap<u32, RemoteUser> = HashMap::new();
        let mut mixed_48k = vec![0.0f32; frame_size];
        let mut user_frame = vec![0.0f32; frame_size];
        let mut final_out_buf = Vec::with_capacity(8192);

        let out_frame_size = if output_rate == sample_rate {
            frame_size
        } else {
            (frame_size as f32 * (output_rate as f32 / sample_rate as f32)).ceil() as usize
        };

        // Calculate latency buffer dynamically based on config
        let target_latency_frames =
            (output_rate as f32 * (config.jitter_buffer_ms as f32 / 1000.0)) as usize;

        loop {
            select! {
                recv(udp_rx) -> msg => {
                    if let Ok(incoming) = msg {
                        let sid = incoming.session_id;
                        let user = users.entry(sid).or_insert_with(|| RemoteUser {
                            decoder: SafeOpusDecoder::new(sample_rate as i32, 1).unwrap(),
                            jitter_buffer: VecDeque::with_capacity(10),
                            is_talking: false,
                            last_packet_time: std::time::Instant::now(),
                        });

                        user.last_packet_time = std::time::Instant::now();
                        if !user.is_talking && !incoming.packet.payload.is_empty() {
                            user.is_talking = true;
                            let _ = event_sink.add(MumbleEvent::UserTalking(sid, true));
                        }

                        if incoming.packet.is_last {
                            user.is_talking = false;
                            let _ = event_sink.add(MumbleEvent::UserTalking(sid, false));
                        } else {
                            user.jitter_buffer.push_back(incoming.packet);
                        }
                    } else {
                        break;
                    }
                }
                recv(output_notify) -> msg => {
                    if msg.is_err() { break; }

                    while prod_out.occupied_len() < target_latency_frames {
                        mixed_48k.fill(0.0);
                        let mut active_users = 0;
                        let now = std::time::Instant::now();

                        // Clean up inactive users
                        users.retain(|sid, user| {
                            if user.is_talking && now.duration_since(user.last_packet_time).as_millis() > 500 {
                                user.is_talking = false;
                                let _ = event_sink.add(MumbleEvent::UserTalking(*sid, false));
                            }
                            now.duration_since(user.last_packet_time).as_secs() < 10
                        });

                        // Decode and mix one frame per active user
                        for user in users.values_mut() {
                            if user.is_talking || !user.jitter_buffer.is_empty() {
                                let packet = user.jitter_buffer.pop_front();
                                let payload = packet.as_ref().map(|p| p.payload.as_ref());

                                if user.decoder.decode(payload, frame_size, &mut user_frame).is_ok() {
                                    for i in 0..frame_size {
                                        mixed_48k[i] += user_frame[i];
                                    }
                                    active_users += 1;
                                }
                            }
                        }

                        // Soft limiting if multiple users are talking
                        if active_users > 1 {
                            for sample in mixed_48k.iter_mut() {
                                *sample = sample.clamp(-1.0, 1.0);
                            }
                        }

                        // Resample and push to output ring buffer
                        if let Some(res) = &mut resampler {
                            res.process(&mixed_48k, &mut final_out_buf);
                            let _ = prod_out.push_slice(&final_out_buf);
                            final_out_buf.clear();
                        } else {
                            let _ = prod_out.push_slice(&mixed_48k);
                        }

                        // Break if we don't have enough space to even try pushing more
                        if prod_out.vacant_len() < out_frame_size {
                            break;
                        }
                    }
                }
            }
        }
    });
}
