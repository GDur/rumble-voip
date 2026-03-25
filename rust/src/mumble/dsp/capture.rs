use crate::mumble::codec::opus::OpusEncoder;
use crate::mumble::config::MumbleConfig;
use crate::mumble::dsp::resample::Resampler;
use crate::mumble::dsp::{
    AudioPacket, INTERNAL_FRAME_MS, INTERNAL_FRAME_SIZE, INTERNAL_SAMPLE_RATE,
};
use opus_head_sys::*;
use sonora::config::{GainController2, HighPassFilter, NoiseSuppression};
use sonora::{AudioProcessing, Config, StreamConfig};

pub struct CapturePipeline {
    resampler: Option<Resampler>,
    apm: AudioProcessing,
    encoder: OpusEncoder,
    // Captured PCM with in `input_bitrate`.
    // Buffer size of 8192 accommodates maximum 120ms frames at 48kHz (5760 samples) safely.
    incoming_pcm_buffer: Box<heapless::Vec<f32, 8192>>,
    // Resampled incoming pcm to INTERNAL_SAMPLE_RATE pre processing.
    pcm_48k_buffer: Box<heapless::Vec<f32, 8192>>,
    // Buffer for processed pcm with INTERNAL_SAMPLE_RATE
    processed_pcm_48k_buffer: Box<heapless::Vec<f32, 8192>>,
    // 8192 bytes is the maximum expected Opus payload for a single packet.
    opus_buf: Box<heapless::Vec<u8, 8192>>,
    // Number of samples per outgoing opus packet.
    outgoing_packet_sample_count: usize,
}

impl CapturePipeline {
    pub fn new(input_rate: u32, config: &MumbleConfig) -> Self {
        let encoder =
            OpusEncoder::new(INTERNAL_SAMPLE_RATE as i32, 1, OPUS_APPLICATION_VOIP as i32).unwrap();
        encoder.ctl(OPUS_SET_VBR_REQUEST as i32, 1);
        encoder.ctl(OPUS_SET_INBAND_FEC_REQUEST as i32, 1);
        encoder.ctl(OPUS_SET_PACKET_LOSS_PERC_REQUEST as i32, 10);
        encoder.ctl(
            OPUS_SET_BITRATE_REQUEST as i32,
            config.outgoing_audio_bitrate as i32,
        );
        encoder.ctl(
            OPUS_SET_COMPLEXITY_REQUEST as i32,
            config.outgoing_opus_complexity as i32,
        );

        let resampler = if input_rate != INTERNAL_SAMPLE_RATE {
            Some(Resampler::new(input_rate, INTERNAL_SAMPLE_RATE, INTERNAL_FRAME_MS).unwrap())
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
            .capture_config(StreamConfig::new(INTERNAL_SAMPLE_RATE, 1))
            .render_config(StreamConfig::new(INTERNAL_SAMPLE_RATE, 1))
            .build();

        let mut opus_buf = Box::new(heapless::Vec::new());
        opus_buf.resize(8192, 0).expect("Opus buf resize failed");

        let outgoing_packet_sample_count =
            (INTERNAL_SAMPLE_RATE * config.outgoing_audio_ms_per_packet / 1000) as usize;

        Self {
            resampler,
            apm,
            encoder,
            incoming_pcm_buffer: Box::new(heapless::Vec::new()),
            pcm_48k_buffer: Box::new(heapless::Vec::new()),
            processed_pcm_48k_buffer: Box::new(heapless::Vec::new()),
            opus_buf,
            outgoing_packet_sample_count,
        }
    }

    pub fn push_pcm(&mut self, data: &[f32]) {
        self.incoming_pcm_buffer
            .extend_from_slice(data)
            .expect("PCM buffer overflow in CapturePipeline");
    }

    pub fn process(&mut self) -> heapless::Vec<AudioPacket, 16> {
        // Resample
        if let Some(res) = &mut self.resampler {
            res.process(&self.incoming_pcm_buffer, &mut self.pcm_48k_buffer);
            self.incoming_pcm_buffer.clear();
        } else {
            // Buffer safety: ensure pcm_48k_buffer has enough room
            let to_copy = self
                .incoming_pcm_buffer
                .len()
                .min(self.pcm_48k_buffer.capacity() - self.pcm_48k_buffer.len());
            self.pcm_48k_buffer
                .extend_from_slice(&self.incoming_pcm_buffer[..to_copy])
                .expect("Resampler buffer overflow in CapturePipeline");
            self.incoming_pcm_buffer.clear();
        }

        // Process available frames
        while self.pcm_48k_buffer.len() >= INTERNAL_FRAME_SIZE {
            // Read frame from buffer
            let frame = &self.pcm_48k_buffer[..INTERNAL_FRAME_SIZE];

            // Extend processed buffer and process directly into it
            let start_idx = self.processed_pcm_48k_buffer.len();
            self.processed_pcm_48k_buffer
                .resize(start_idx + INTERNAL_FRAME_SIZE, 0.0)
                .expect("Processed buffer overflow");
            let chunk_out =
                &mut self.processed_pcm_48k_buffer[start_idx..start_idx + INTERNAL_FRAME_SIZE];

            self.apm
                .process_capture_f32(&[frame], &mut [chunk_out])
                .expect("APM capture processing failed");

            // Remove frame from buffer
            self.pcm_48k_buffer.rotate_left(INTERNAL_FRAME_SIZE);
            self.pcm_48k_buffer
                .truncate(self.pcm_48k_buffer.len() - INTERNAL_FRAME_SIZE);
        }

        // Encode available data into network packets
        let mut packets = heapless::Vec::new();
        while self.processed_pcm_48k_buffer.len() >= self.outgoing_packet_sample_count {
            // Read packet data from processed buffer
            let packet_data = &self.processed_pcm_48k_buffer[..self.outgoing_packet_sample_count];

            // Encode packet
            if let Ok(len) = self.encoder.encode(
                packet_data,
                self.outgoing_packet_sample_count,
                &mut self.opus_buf,
            ) {
                let mut payload = heapless::Vec::new();
                payload
                    .extend_from_slice(&self.opus_buf[..len.min(8192)])
                    .expect("Opus payload buffer overflow");
                packets
                    .push(AudioPacket::new(payload, false))
                    .expect("Too many packets generated");
            }

            // Remove packet data from processed buffer
            self.processed_pcm_48k_buffer
                .rotate_left(self.outgoing_packet_sample_count);
            self.processed_pcm_48k_buffer
                .truncate(self.processed_pcm_48k_buffer.len() - self.outgoing_packet_sample_count);
        }

        packets
    }

    pub fn clear(&mut self) {
        self.incoming_pcm_buffer.clear();
        self.pcm_48k_buffer.clear();
        self.processed_pcm_48k_buffer.clear();
    }
}
