use crate::frb_generated::StreamSink;
use crate::mumble::config::MumbleConfig;
use crate::mumble::dsp::resample::Resampler;
use crate::mumble::dsp::user_stream::UserVoiceStream;
use crate::mumble::dsp::{INTERNAL_FRAME_SIZE, INTERNAL_SAMPLE_RATE};
use crate::mumble::MumbleEvent;
use sonora::config::GainController2;
use sonora::{AudioProcessing, Config, StreamConfig};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;

pub struct PlaybackMixer {
    users: HashMap<u32, UserVoiceStream>,
    resampler: Option<Resampler>,
    apm: AudioProcessing,
    global_volume: Arc<AtomicU32>,
    // Processed PCM pre resampling (48k).
    // Stored in struct because it's returned as a reference.
    processed_pcm_48k_buffer: [f32; INTERNAL_FRAME_SIZE],
    // Resampled outgoing pcm in output_rate.
    // Stored in struct because it's returned as a reference and used as an accumulator.
    output_pcm_buffer: Box<heapless::Vec<f32, 8192>>,
    // Number of samples per output frame
    output_frame_sample_count: usize,
}

impl PlaybackMixer {
    pub fn new(output_rate: u32, config: &MumbleConfig, global_volume: Arc<AtomicU32>) -> Self {
        let resampler = if output_rate != INTERNAL_SAMPLE_RATE {
            Some(
                Resampler::new(
                    INTERNAL_SAMPLE_RATE,
                    output_rate,
                    config.outgoing_audio_ms_per_packet,
                )
                .unwrap(),
            )
        } else {
            None
        };

        let output_frame_sample_count = if output_rate == INTERNAL_SAMPLE_RATE {
            INTERNAL_FRAME_SIZE
        } else {
            (INTERNAL_FRAME_SIZE as f32 * (output_rate as f32 / INTERNAL_SAMPLE_RATE as f32)).ceil()
                as usize
        };

        let apm_config = Config {
            gain_controller2: Some(GainController2::default()),
            ..Default::default()
        };

        let apm = AudioProcessing::builder()
            .config(apm_config)
            .capture_config(StreamConfig::new(INTERNAL_SAMPLE_RATE, 1))
            .render_config(StreamConfig::new(INTERNAL_SAMPLE_RATE, 1))
            .build();

        Self {
            users: HashMap::with_capacity(64),
            resampler,
            apm,
            global_volume,
            processed_pcm_48k_buffer: [0.0; INTERNAL_FRAME_SIZE],
            output_pcm_buffer: Box::new(heapless::Vec::new()),
            output_frame_sample_count,
        }
    }

    pub fn get_user_mut(&mut self, session_id: u32) -> Option<&mut UserVoiceStream> {
        self.users.get_mut(&session_id)
    }

    pub fn get_or_insert_user(&mut self, session_id: u32) -> &mut UserVoiceStream {
        self.users
            .entry(session_id)
            .or_insert_with(|| UserVoiceStream::new(INTERNAL_SAMPLE_RATE, 1))
    }

    pub fn output_frame_sample_count(&self) -> usize {
        self.output_frame_sample_count
    }

    pub fn mix_frame(&mut self, event_sink: &StreamSink<MumbleEvent>) -> &[f32] {
        // Clean up inactive users
        self.users.retain(|sid, user| {
            if user.is_talking() && user.time_since_last_packet().as_millis() > 500 {
                user.set_talking(false);
                let _ = event_sink.add(MumbleEvent::UserTalking(*sid, false));
            }
            user.time_since_last_packet().as_secs() < 10
        });

        // Scratch buffers on the stack for internal processing
        let mut mixed_pcm_48k = [0.0f32; INTERNAL_FRAME_SIZE];
        let mut user_pcm_frame = [0.0f32; INTERNAL_FRAME_SIZE];

        let mut active_users = 0;
        let master_gain = f32::from_bits(self.global_volume.load(Ordering::Relaxed));

        // Mix audio from all users
        for user in self.users.values_mut() {
            if user.has_audio() && user.decode_frame(INTERNAL_FRAME_SIZE, &mut user_pcm_frame) {
                for i in 0..INTERNAL_FRAME_SIZE {
                    mixed_pcm_48k[i] += user_pcm_frame[i] * master_gain;
                }
                active_users += 1;
            }
        }

        // Return silence if no audio is present
        if active_users == 0 {
            self.output_pcm_buffer.clear();
            self.output_pcm_buffer
                .resize(self.output_frame_sample_count, 0.0)
                .expect("Output buffer resize failed");
            return &self.output_pcm_buffer;
        }

        // Master processing
        self.apm
            .process_render_f32(&[&mixed_pcm_48k], &mut [&mut self.processed_pcm_48k_buffer])
            .expect("APM render processing failed");

        // Resample for output
        if let Some(resampler) = &mut self.resampler {
            self.output_pcm_buffer.clear();
            resampler.process(&self.processed_pcm_48k_buffer, &mut self.output_pcm_buffer);
            &self.output_pcm_buffer
        } else {
            &self.processed_pcm_48k_buffer
        }
    }
}
