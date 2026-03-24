use crate::mumble::opus_codec::SafeOpusEncoder;
use crate::mumble::resample::AudioResampler;
use crate::mumble::types::{AudioPacket, MumbleConfig, MUMBLE_SAMPLE_RATE};
use bytes::BytesMut;
use opus_head_sys::*;
use sonora::config::{GainController2, HighPassFilter, NoiseSuppression};
use sonora::{AudioProcessing, Config, StreamConfig};

pub struct InputPipeline {
    resampler: Option<AudioResampler>,
    apm: AudioProcessing,
    encoder: SafeOpusEncoder,
    pcm_buffer: Box<heapless::Vec<f32, 8192>>,
    f32_48k_buffer: Box<heapless::Vec<f32, 8192>>,
    processed_frame: Vec<f32>,
    opus_buf: Vec<u8>,
    payload_buf: BytesMut,
    frame_size: usize,
}

impl InputPipeline {
    pub fn new(input_rate: u32, config: &MumbleConfig) -> Self {
        let sample_rate = MUMBLE_SAMPLE_RATE;
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

        let resampler = if input_rate != sample_rate {
            Some(AudioResampler::new(input_rate, sample_rate, config.audio_frame_ms).unwrap())
        } else {
            None
        };

        let apm_config = Config {
            noise_suppression: Some(NoiseSuppression::default()),
            gain_controller2: Some(GainController2::default()),
            high_pass_filter: Some(HighPassFilter::default()),
            ..Default::default()
        };

        let apm = AudioProcessing::builder()
            .config(apm_config)
            .capture_config(StreamConfig::new(sample_rate, 1))
            .render_config(StreamConfig::new(sample_rate, 1))
            .build();

        Self {
            resampler,
            apm,
            encoder,
            pcm_buffer: Box::new(heapless::Vec::new()),
            f32_48k_buffer: Box::new(heapless::Vec::new()),
            processed_frame: vec![0.0; frame_size],
            opus_buf: vec![0u8; 1024],
            payload_buf: BytesMut::with_capacity(4096),
            frame_size,
        }
    }

    pub fn push_pcm(&mut self, data: &[f32]) {
        self.pcm_buffer.extend_from_slice(data).unwrap();
    }

    pub fn process(&mut self) -> Vec<AudioPacket> {
        if let Some(res) = &mut self.resampler {
            res.process(&self.pcm_buffer, &mut self.f32_48k_buffer);
            self.pcm_buffer.clear();
        } else {
            self.f32_48k_buffer
                .extend_from_slice(&self.pcm_buffer)
                .unwrap();
            self.pcm_buffer.clear();
        }

        let mut packets = Vec::new();
        while self.f32_48k_buffer.len() >= self.frame_size {
            let frame = &self.f32_48k_buffer[..self.frame_size];

            // Sonora APM processing
            self.apm
                .process_capture_f32(&[frame], &mut [&mut self.processed_frame])
                .unwrap();

            if let Ok(len) =
                self.encoder
                    .encode(&self.processed_frame, self.frame_size, &mut self.opus_buf)
            {
                let mut payload = heapless::Vec::new();
                payload
                    .extend_from_slice(&self.opus_buf[..len.min(512)])
                    .unwrap();

                packets.push(AudioPacket {
                    payload,
                    is_last: false,
                });
            }

            self.f32_48k_buffer.rotate_left(self.frame_size);
            self.f32_48k_buffer
                .truncate(self.f32_48k_buffer.len() - self.frame_size);
        }
        packets
    }

    pub fn clear(&mut self) {
        self.pcm_buffer.clear();
        self.f32_48k_buffer.clear();
    }
}
