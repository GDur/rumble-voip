use crate::frb_generated::StreamSink;
use crate::mumble::config::MumbleConfig;
use crate::mumble::dsp::user_stream::UserVoiceStream;
use crate::mumble::dsp::{INTERNAL_FRAME_MS, INTERNAL_FRAME_SIZE, INTERNAL_SAMPLE_RATE};
use crate::mumble::MumbleEvent;
use sonora::config::GainController2;
use sonora::{AudioProcessing, Config, StreamConfig};
use sonora_common_audio::push_sinc_resampler::PushSincResampler;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;

// Used for silence playback.
// 2048 is sufficient for >192kHz @ 10ms
const SILENCE: [f32; 2048] = [0.0; 2048];

pub struct PlaybackMixer {
    // Map of session IDs to user audio streams.
    users: HashMap<u32, UserVoiceStream>,
    // Optional resampler if the hardware output rate differs from 48kHz.
    resampler: Option<PushSincResampler>,
    // Audio processing module for the mixed render signal.
    apm: AudioProcessing,
    // Shared global volume state.
    global_volume: Arc<AtomicU32>,
    // Buffer for the mixed and processed PCM signal at 48kHz.
    processed_pcm_48k: [f32; INTERNAL_FRAME_SIZE],
    // Buffer for the resampled outgoing PCM signal at the output rate.
    output_pcm_buffer: Box<heapless::Vec<f32, 8192>>,
    // Expected number of samples per output frame.
    output_samples_per_frame: usize,
}

impl PlaybackMixer {
    pub fn new(
        output_sample_rate: u32,
        _config: &MumbleConfig,
        global_volume: Arc<AtomicU32>,
    ) -> Self {
        // Number of output samples corresponding to INTERNAL_FRAME_MS with the output sample rate.
        let output_samples_per_frame =
            (output_sample_rate as f32 * (INTERNAL_FRAME_MS as f32 / 1000.0)).ceil() as usize;

        let resampler = if output_sample_rate != INTERNAL_SAMPLE_RATE {
            Some(PushSincResampler::new(
                INTERNAL_FRAME_SIZE,
                output_samples_per_frame,
            ))
        } else {
            None
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
            processed_pcm_48k: [0.0; INTERNAL_FRAME_SIZE],
            output_pcm_buffer: Box::new(heapless::Vec::new()),
            output_samples_per_frame,
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

    pub fn output_samples_per_frame(&self) -> usize {
        self.output_samples_per_frame
    }

    /// Mixes one frame of audio from all active users.
    /// Returns a slice of PCM samples at the output sample rate.
    pub fn mix_frame(&mut self, event_sink: &StreamSink<MumbleEvent>) -> &[f32] {
        // Remove users that have been inactive for too long.
        self.users.retain(|sid, user| {
            if user.is_talking() && user.time_since_last_packet().as_millis() > 500 {
                user.set_talking(false);
                let _ = event_sink.add(MumbleEvent::UserTalking(*sid, false));
            }
            // Keep user state for 10 seconds of silence before dropping.
            user.time_since_last_packet().as_secs() < 10
        });

        // Mix audio from all users into a single 48kHz frame.
        let mut mixed_pcm_48k = [0.0f32; INTERNAL_FRAME_SIZE];
        let mut user_pcm_frame = [0.0f32; INTERNAL_FRAME_SIZE];
        let mut active_users = 0;

        for user in self.users.values_mut() {
            if user.has_audio() && user.decode_frame(&mut user_pcm_frame) {
                for i in 0..INTERNAL_FRAME_SIZE {
                    mixed_pcm_48k[i] += user_pcm_frame[i];
                }
                active_users += 1;
            }
        }

        // Return silence if no users are contributing audio.
        if active_users == 0 {
            return &SILENCE[..self.output_samples_per_frame];
        }

        // Apply master gain to the mixed signal.
        let master_gain = f32::from_bits(self.global_volume.load(Ordering::Relaxed));
        if master_gain != 1.0 {
            for sample in mixed_pcm_48k.iter_mut() {
                *sample *= master_gain;
            }
        }

        // Run master processing (AGC/Limiter).
        self.apm
            .process_render_f32(&[&mixed_pcm_48k], &mut [&mut self.processed_pcm_48k])
            .expect("APM render processing failed");

        // Resample the processed signal if needed.
        if let Some(res) = &mut self.resampler {
            self.output_pcm_buffer.clear();
            // Ensure the output buffer has the correct size for the resampler.
            self.output_pcm_buffer
                .resize(self.output_samples_per_frame, 0.0)
                .expect("Output buffer resize failed");

            res.resample(&self.processed_pcm_48k, &mut self.output_pcm_buffer);
            &self.output_pcm_buffer
        } else {
            // If rates match, we can return the processed buffer directly.
            &self.processed_pcm_48k
        }
    }
}
