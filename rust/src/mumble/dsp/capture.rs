use crate::mumble::codec::opus::OpusEncoder;
use crate::mumble::config::MumbleConfig;
use crate::mumble::dsp::{
    AudioPacket, INTERNAL_FRAME_MS, INTERNAL_FRAME_SIZE, INTERNAL_SAMPLE_RATE,
    MAX_OPUS_PACKET_SIZE, MAX_PACKET_SAMPLES,
};
use opus_head_sys::*;
use sonora::config::{AdaptiveDigital, FixedDigital, GainController2, HighPassFilter, NoiseSuppression, EchoCanceller};
use sonora::{AudioProcessing, Config, StreamConfig};
use sonora_common_audio::push_sinc_resampler::PushSincResampler;

pub struct CapturePipeline {
    resampler: Option<PushSincResampler>,
    apm: AudioProcessing,
    encoder: OpusEncoder,
    // Captured PCM with in `input_bitrate`.
    // Buffer size of 8192 accommodates maximum 120ms frames at 48kHz (5760 samples) safely.
    incoming_pcm_buffer: Box<heapless::Vec<f32, 8192>>,
    // Reusable buffer to compute a single outgoing packet.
    opus_buf: Box<heapless::Vec<u8, MAX_OPUS_PACKET_SIZE>>,
    // Number of samples per outgoing opus packet.
    outgoing_packet_sample_count: usize,
    // Number of input samples corresponding to 10ms.
    input_samples_per_10ms: usize,
}

impl CapturePipeline {
    pub fn new(input_sample_rate: u32, config: &MumbleConfig) -> Self {
        // Mumble chooses between VOIP, AUDIO, and RESTRICTED_LOW_DELAY based on bit rate and another flag for low delay mode
        // VoIP mode is only relevant for ultra low sample rates, and RESTRICTED_LOW_DELAY only gains us a few ms of algorithmic delay,
        // but requires higher bit rates. Just always pick AUDIO. Mumble also uses CBR, but who cares, VBR is better.
        // No forward error correction (FEC), and no DTX (discontinuous transmission, for silence) just as in Mumble.

        let encoder = OpusEncoder::new(INTERNAL_SAMPLE_RATE, 1, OPUS_APPLICATION_AUDIO).unwrap();

        encoder.ctl(
            OPUS_SET_BITRATE_REQUEST,
            config.outgoing_audio_bitrate as i32,
        );

        let input_samples_per_frame =
            (input_sample_rate as f32 * (INTERNAL_FRAME_MS as f32 / 1000.0)).ceil() as usize;

        let resampler = if input_sample_rate != INTERNAL_SAMPLE_RATE {
            Some(PushSincResampler::new(
                input_samples_per_frame,
                INTERNAL_FRAME_SIZE,
            ))
        } else {
            None
        };

        let apm_config = Self::build_apm_config(config.echo_cancellation);

        let apm = AudioProcessing::builder()
            .config(apm_config)
            .capture_config(StreamConfig::new(INTERNAL_SAMPLE_RATE, 1))
            .render_config(StreamConfig::new(INTERNAL_SAMPLE_RATE, 1))
            .build();

        let mut opus_buf = Box::new(heapless::Vec::new());
        opus_buf
            .resize(MAX_OPUS_PACKET_SIZE, 0)
            .expect("Opus buf resize failed");

        let outgoing_packet_sample_count =
            (INTERNAL_SAMPLE_RATE * config.outgoing_audio_ms_per_packet / 1000) as usize;

        Self {
            resampler,
            apm,
            encoder,
            incoming_pcm_buffer: Box::new(heapless::Vec::new()),
            opus_buf,
            outgoing_packet_sample_count,
            input_samples_per_10ms: input_samples_per_frame,
        }
    }

    pub fn push_pcm(&mut self, data: &[f32]) {
        self.incoming_pcm_buffer
            .extend_from_slice(data)
            .expect("PCM buffer overflow in CapturePipeline");
    }

    pub fn process(&mut self) -> heapless::Vec<AudioPacket, 16> {
        let mut packets = heapless::Vec::new();

        // outgoing_packet_sample_count is always a multiple of INTERNAL_FRAME_SIZE
        let frames_per_packet = self.outgoing_packet_sample_count / INTERNAL_FRAME_SIZE;
        let input_samples_per_packet = frames_per_packet * self.input_samples_per_10ms;

        // Process available data into network packets
        while self.incoming_pcm_buffer.len() >= input_samples_per_packet {
            // Buffer for a single outgoing packet
            let mut packet_data = heapless::Vec::<f32, MAX_PACKET_SAMPLES>::new();

            for _ in 0..frames_per_packet {
                let input_frame = &self.incoming_pcm_buffer[..self.input_samples_per_10ms];
                let mut frame_48k = [0.0f32; INTERNAL_FRAME_SIZE];

                // Resample to 48kHz
                if let Some(res) = &mut self.resampler {
                    res.resample(input_frame, &mut frame_48k);
                } else {
                    frame_48k.copy_from_slice(input_frame);
                }

                // Process 10ms frame
                let mut processed_frame = [0.0f32; INTERNAL_FRAME_SIZE];
                self.apm
                    .process_capture_f32(&[&frame_48k], &mut [&mut processed_frame])
                    .expect("APM capture processing failed");

                // Add to packet data
                packet_data
                    .extend_from_slice(&processed_frame)
                    .expect("Packet data overflow");

                // Remove frame from buffer
                self.incoming_pcm_buffer
                    .rotate_left(self.input_samples_per_10ms);
                self.incoming_pcm_buffer
                    .truncate(self.incoming_pcm_buffer.len() - self.input_samples_per_10ms);
            }

            // Encode packet
            if let Ok(len) = self.encoder.encode(
                &packet_data,
                self.outgoing_packet_sample_count,
                &mut self.opus_buf,
            ) {
                let mut payload = heapless::Vec::new();
                payload
                    .extend_from_slice(&self.opus_buf[..len.min(MAX_OPUS_PACKET_SIZE)])
                    .expect("Opus payload buffer overflow");
                packets
                    .push(AudioPacket::new(payload, false))
                    .expect("Too many packets generated");
            }
        }

        packets
    }

    pub fn clear(&mut self) {
        self.incoming_pcm_buffer.clear();
        // Clear resampler state by pushing zeros
        if let Some(res) = &mut self.resampler {
            let zero_in = [0.0f32; INTERNAL_FRAME_SIZE];
            let mut zero_out = [0.0f32; INTERNAL_FRAME_SIZE];
            res.resample(&zero_in[..self.input_samples_per_10ms], &mut zero_out);
        }
        self.encoder.reset_state();
    }

    pub fn set_echo_cancellation(&mut self, enabled: bool) {
        self.apm.apply_config(Self::build_apm_config(enabled));
    }

    pub fn process_reverse(&mut self, frame: &[f32; INTERNAL_FRAME_SIZE]) {
        let mut dummy_out = [0.0f32; INTERNAL_FRAME_SIZE];
        self.apm.process_render_f32(&[frame], &mut [&mut dummy_out]).expect("AEC reverse processing failed");
    }

    fn build_apm_config(echo_cancellation: bool) -> Config {
        Config {
            echo_canceller: if echo_cancellation { Some(EchoCanceller::default()) } else { None },
            noise_suppression: Some(NoiseSuppression::default()),
            gain_controller2: Some(GainController2 {
                fixed_digital: FixedDigital { gain_db: 12.0 },
                adaptive_digital: Some(AdaptiveDigital::default()),
                ..GainController2::default()
            }),
            high_pass_filter: Some(HighPassFilter::default()),
            ..Default::default()
        }
    }
}
