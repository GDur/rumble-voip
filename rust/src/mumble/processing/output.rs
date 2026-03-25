use crate::api::client::MumbleEvent;
use crate::frb_generated::StreamSink;
use crate::mumble::processing::user::RemoteUser;
use crate::mumble::resample::AudioResampler;
use crate::mumble::types::{MumbleConfig, MUMBLE_SAMPLE_RATE};
use sonora::config::GainController2;
use sonora::{AudioProcessing, Config, StreamConfig};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;

pub struct OutputMixer {
    users: HashMap<u32, RemoteUser>,
    resampler: Option<AudioResampler>,
    apm: AudioProcessing,
    global_volume: Arc<AtomicU32>,
    mixed_48k: Box<heapless::Vec<f32, 8192>>,
    user_frame: Box<heapless::Vec<f32, 8192>>,
    leveled_frame: Box<heapless::Vec<f32, 8192>>,
    // Size 8192 is used safely to keep mixed outgoing streams
    final_out_buf: Box<heapless::Vec<f32, 8192>>,
    frame_size: usize,
    out_frame_size: usize,
}

impl OutputMixer {
    pub fn new(output_rate: u32, config: &MumbleConfig, global_volume: Arc<AtomicU32>) -> Self {
        let sample_rate = MUMBLE_SAMPLE_RATE;
        let frame_ms = config.audio_frame_ms;
        let frame_size = (sample_rate * frame_ms / 1000) as usize;

        let resampler = if output_rate != sample_rate {
            Some(AudioResampler::new(sample_rate, output_rate, config.audio_frame_ms).unwrap())
        } else {
            None
        };

        let out_frame_size = if output_rate == sample_rate {
            frame_size
        } else {
            (frame_size as f32 * (output_rate as f32 / sample_rate as f32)).ceil() as usize
        };

        let apm_config = Config {
            gain_controller2: Some(GainController2::default()),
            ..Default::default()
        };

        let apm = AudioProcessing::builder()
            .config(apm_config)
            .capture_config(StreamConfig::new(sample_rate, 1))
            .render_config(StreamConfig::new(sample_rate, 1))
            .build();

        let mut mixed_48k = Box::new(heapless::Vec::new());
        mixed_48k
            .resize(frame_size, 0.0)
            .expect("mixed_48k resize failed");
        let mut user_frame = Box::new(heapless::Vec::new());
        user_frame
            .resize(frame_size, 0.0)
            .expect("user_frame resize failed");
        let mut leveled_frame = Box::new(heapless::Vec::new());
        leveled_frame
            .resize(frame_size, 0.0)
            .expect("leveled_frame resize failed");

        Self {
            users: HashMap::with_capacity(64),
            resampler,
            apm,
            global_volume,
            mixed_48k,
            user_frame,
            leveled_frame,
            final_out_buf: Box::new(heapless::Vec::new()),
            frame_size,
            out_frame_size,
        }
    }

    pub fn get_user_mut(&mut self, session_id: u32) -> Option<&mut RemoteUser> {
        self.users.get_mut(&session_id)
    }

    pub fn get_or_insert_user(&mut self, session_id: u32) -> &mut RemoteUser {
        self.users
            .entry(session_id)
            .or_insert_with(|| RemoteUser::new(MUMBLE_SAMPLE_RATE as i32, 1))
    }

    pub fn out_frame_size(&self) -> usize {
        self.out_frame_size
    }

    pub fn mix_frame(&mut self, event_sink: &StreamSink<MumbleEvent>) -> &[f32] {
        self.mixed_48k.fill(0.0);
        let mut active_users = 0;

        // Clean up inactive users and mix
        self.users.retain(|sid, user| {
            if user.is_talking() && user.time_since_last_packet().as_millis() > 500 {
                user.set_talking(false);
                let _ = event_sink.add(MumbleEvent::UserTalking(*sid, false));
            }
            user.time_since_last_packet().as_secs() < 10
        });

        let master_gain = f32::from_bits(self.global_volume.load(Ordering::Relaxed));

        for user in self.users.values_mut() {
            if user.has_audio() && user.decode_frame(self.frame_size, &mut self.user_frame) {
                for i in 0..self.frame_size {
                    self.mixed_48k[i] += self.user_frame[i] * master_gain;
                }
                active_users += 1;
            }
        }

        if active_users == 0 {
            self.final_out_buf.clear();
            self.final_out_buf
                .resize(self.out_frame_size, 0.0)
                .expect("Final out buffer resize failed");
            return &self.final_out_buf;
        }

        // Master processing with Sonora
        self.apm
            .process_render_f32(&[&self.mixed_48k], &mut [&mut self.leveled_frame])
            .expect("APM render processing failed");

        if let Some(resampler) = &mut self.resampler {
            self.final_out_buf.clear();
            resampler.process(&self.leveled_frame, &mut self.final_out_buf);
            &self.final_out_buf
        } else {
            &self.leveled_frame
        }
    }
}
