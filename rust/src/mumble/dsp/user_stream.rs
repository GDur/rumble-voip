use crate::mumble::{codec::opus::OpusDecoder, dsp::AudioPacket};
use std::time::Instant;

pub struct UserVoiceStream {
    decoder: OpusDecoder,
    // Size 64 allows buffering up to ~640ms of audio (at 10ms frames)
    jitter_buffer: Box<heapless::Deque<AudioPacket, 64>>,
    // 8192 capacity securely covers common decode buffer sizes
    pcm_buffer: Box<heapless::Deque<f32, 8192>>,
    is_talking: bool,
    last_packet_time: Instant,
    volume: f32,
}

impl UserVoiceStream {
    pub fn new(sample_rate: i32, channels: i32) -> Self {
        Self {
            decoder: OpusDecoder::new(sample_rate, channels).unwrap(),
            jitter_buffer: Box::new(heapless::Deque::new()),
            pcm_buffer: Box::new(heapless::Deque::new()),
            is_talking: false,
            last_packet_time: Instant::now(),
            volume: 1.0,
        }
    }

    pub fn has_audio(&self) -> bool {
        self.is_talking || !self.jitter_buffer.is_empty() || !self.pcm_buffer.is_empty()
    }

    pub fn set_volume(&mut self, volume: f32) {
        self.volume = volume;
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
        self.jitter_buffer
            .push_back(packet)
            .expect("Jitter buffer overflow");
    }

    pub fn decode_frame(&mut self, frame_size: usize, out: &mut [f32]) -> bool {
        // Max Opus frame size: 120ms at 48kHz (5760 samples)
        let mut decode_buf = [0.0f32; 5760];

        while self.pcm_buffer.len() < frame_size {
            let packet = self.jitter_buffer.pop_front();
            match packet {
                Some(p) => {
                    if let Ok(len) = self
                        .decoder
                        .decode(Some(p.payload()), 5760, &mut decode_buf)
                    {
                        for &sample in &decode_buf[..len] {
                            self.pcm_buffer
                                .push_back(sample)
                                .expect("PCM buffer overflow during decode");
                        }
                    } else {
                        break;
                    }
                }
                None if self.is_talking => {
                    // PLC: synthesize exactly frame_size samples
                    if let Ok(len) = self.decoder.decode(None, frame_size, &mut decode_buf) {
                        for &sample in &decode_buf[..len] {
                            self.pcm_buffer
                                .push_back(sample)
                                .expect("PCM buffer overflow during decode (PLC)");
                        }
                    } else {
                        break;
                    }
                }
                None => break,
            }
        }

        if self.pcm_buffer.len() >= frame_size {
            for item in out.iter_mut().take(frame_size) {
                *item = self.pcm_buffer.pop_front().unwrap() * self.volume;
            }
            true
        } else {
            false
        }
    }
}
