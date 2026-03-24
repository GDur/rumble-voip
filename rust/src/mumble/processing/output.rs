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
    pub users: HashMap<u32, RemoteUser>,
    resampler: Option<AudioResampler>,
    apm: AudioProcessing,
    global_volume: Arc<AtomicU32>,
    mixed_48k: Vec<f32>,
    user_frame: Vec<f32>,
    leveled_frame: Vec<f32>,
    final_out_buf: Vec<f32>,
    pub frame_size: usize,
    pub out_frame_size: usize,
    #[allow(dead_with_capacity)]
    sample_rate: u32,
    #[allow(dead_with_capacity)]
    output_rate: u32,
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

        Self {
            users: HashMap::new(),
            resampler,
            apm,
            global_volume,
            mixed_48k: vec![0.0; frame_size],
            user_frame: vec![0.0; frame_size],
            leveled_frame: vec![0.0; frame_size],
            final_out_buf: Vec::with_capacity(8192),
            frame_size,
            out_frame_size,
            sample_rate,
            output_rate,
        }
    }

    pub fn mix_frame(&mut self, event_sink: &StreamSink<MumbleEvent>) -> &[f32] {
        self.mixed_48k.fill(0.0);
        let mut active_users = 0;
        let now = std::time::Instant::now();

        // Clean up inactive users and mix
        self.users.retain(|sid, user| {
            if user.is_talking && now.duration_since(user.last_packet_time).as_millis() > 500 {
                user.is_talking = false;
                let _ = event_sink.add(MumbleEvent::UserTalking(*sid, false));
            }
            now.duration_since(user.last_packet_time).as_secs() < 10
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
            self.final_out_buf.resize(self.out_frame_size, 0.0);
            return &self.final_out_buf;
        }

        // Master processing with Sonora
        self.apm
            .process_render_f32(&[&self.mixed_48k], &mut [&mut self.leveled_frame])
            .unwrap();

        if let Some(resampler) = &mut self.resampler {
            self.final_out_buf.clear();
            resampler.process(&self.leveled_frame, &mut self.final_out_buf);
            &self.final_out_buf
        } else {
            &self.leveled_frame
        }
    }
}
