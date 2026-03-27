use crate::mumble::{codec::opus::OpusDecoder, dsp::AudioPacket, dsp::INTERNAL_FRAME_SIZE};
use std::time::Instant;

pub struct UserVoiceStream {
    decoder: OpusDecoder,
    // Buffer for incoming network packets.
    // Size 64 allows buffering up to ~640ms of audio (at 10ms frames).
    jitter_buffer: Box<heapless::Deque<AudioPacket, 64>>,
    // Buffer for decoded PCM samples at 48kHz.
    // Capacity of 8192 covers common decode buffer sizes and multiple frames.
    decoded_pcm_buffer: Box<heapless::Vec<f32, 8192>>,
    is_talking: bool,
    last_packet_time: Instant,
    volume_multiplier: f32,
}

impl UserVoiceStream {
    pub fn new(sample_rate: u32, channels: u32) -> Self {
        Self {
            decoder: OpusDecoder::new(sample_rate, channels).unwrap(),
            jitter_buffer: Box::new(heapless::Deque::new()),
            decoded_pcm_buffer: Box::new(heapless::Vec::new()),
            is_talking: false,
            last_packet_time: Instant::now(),
            volume_multiplier: 1.0,
        }
    }

    pub fn has_audio(&self) -> bool {
        self.is_talking || !self.jitter_buffer.is_empty() || !self.decoded_pcm_buffer.is_empty()
    }

    pub fn set_volume(&mut self, volume: f32) {
        self.volume_multiplier = volume;
    }

    pub fn set_talking(&mut self, is_talking: bool) {
        self.is_talking = is_talking;
    }

    pub fn is_talking(&self) -> bool {
        self.is_talking
    }

    pub fn update_last_packet_time(&mut self) {
        self.last_packet_time = Instant::now();
    }

    pub fn time_since_last_packet(&self) -> std::time::Duration {
        self.last_packet_time.elapsed()
    }

    pub fn push_packet(&mut self, packet: AudioPacket) {
        if self.jitter_buffer.is_full() {
            // Drop oldest packet to make room if we overflow due to clock drift or network pileup.
            let _ = self.jitter_buffer.pop_front();
        }
        let _ = self.jitter_buffer.push_back(packet);
    }

    /// Decodes audio into the provided buffer. Returns true if the buffer was filled.
    pub fn decode_frame(&mut self, out: &mut [f32; INTERNAL_FRAME_SIZE]) -> bool {
        // Scratch buffer for Opus decoding.
        // Max Opus frame size: 120ms at 48kHz (5760 samples).
        let mut opus_decode_buf = [0.0f32; 5760];

        // Ensure we have enough samples for a full frame.
        // If packets are always multiples of 10ms (480 samples), this usually
        // decodes one or more full frames.
        while self.decoded_pcm_buffer.len() < INTERNAL_FRAME_SIZE {
            match self.jitter_buffer.pop_front() {
                Some(packet) => {
                    if let Ok(decoded_count) = self.decoder.decode(
                        Some(packet.payload()),
                        opus_decode_buf.len(),
                        &mut opus_decode_buf,
                    ) {
                        self.decoded_pcm_buffer
                            .extend_from_slice(&opus_decode_buf[..decoded_count])
                            .expect("PCM buffer overflow during decode");
                    } else {
                        // Decode error, skip packet.
                        continue;
                    }
                }
                None if self.is_talking => {
                    // Packet loss concealment: synthesize exactly INTERNAL_FRAME_SIZE samples.
                    if let Ok(synthesized_count) =
                        self.decoder
                            .decode(None, INTERNAL_FRAME_SIZE, &mut opus_decode_buf)
                    {
                        self.decoded_pcm_buffer
                            .extend_from_slice(&opus_decode_buf[..synthesized_count])
                            .expect("PCM buffer overflow during PLC");
                    } else {
                        break;
                    }
                }
                None => break,
            }
        }

        // Return a full frame if available.
        if self.decoded_pcm_buffer.len() >= INTERNAL_FRAME_SIZE {
            // Copy samples to output.
            out.copy_from_slice(&self.decoded_pcm_buffer[..INTERNAL_FRAME_SIZE]);

            // Apply volume multiplier if necessary.
            if (self.volume_multiplier - 1.0).abs() > f32::EPSILON {
                for sample in out.iter_mut() {
                    *sample *= self.volume_multiplier;
                }
            }

            // Remove consumed samples from buffer.
            self.decoded_pcm_buffer.rotate_left(INTERNAL_FRAME_SIZE);
            self.decoded_pcm_buffer
                .truncate(self.decoded_pcm_buffer.len() - INTERNAL_FRAME_SIZE);
            true
        } else {
            false
        }
    }
}
