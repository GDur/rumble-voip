use crate::mumble::opus_codec::SafeOpusDecoder;
use crate::mumble::types::AudioPacket;
use std::time::Instant;
pub struct RemoteUser {
    pub decoder: SafeOpusDecoder,
    pub jitter_buffer: Box<heapless::Deque<AudioPacket, 64>>,
    pub pcm_buffer: Box<heapless::Deque<f32, 8192>>,
    pub is_talking: bool,
    pub last_packet_time: Instant,
    pub volume: f32,
}

impl RemoteUser {
    pub fn new(sample_rate: i32, channels: i32) -> Self {
        Self {
            decoder: SafeOpusDecoder::new(sample_rate, channels).unwrap(),
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

    pub fn decode_frame(&mut self, frame_size: usize, out: &mut [f32]) -> bool {
        // Max Opus frame size: 120ms at 48kHz
        let mut decode_buf = [0.0f32; 5760];

        while self.pcm_buffer.len() < frame_size {
            let packet = self.jitter_buffer.pop_front();
            match packet {
                Some(p) => {
                    if let Ok(len) = self.decoder.decode(Some(&p.payload), 5760, &mut decode_buf) {
                        for &sample in &decode_buf[..len] {
                            self.pcm_buffer.push_back(sample).unwrap();
                        }
                    } else {
                        break;
                    }
                }
                None if self.is_talking => {
                    // PLC: synthesize exactly frame_size samples
                    if let Ok(len) = self.decoder.decode(None, frame_size, &mut decode_buf) {
                        for &sample in &decode_buf[..len] {
                            self.pcm_buffer.push_back(sample).unwrap();
                        }
                    } else {
                        break;
                    }
                }
                None => break,
            }
        }

        if self.pcm_buffer.len() >= frame_size {
            for i in 0..frame_size {
                out[i] = self.pcm_buffer.pop_front().unwrap() * self.volume;
            }
            true
        } else {
            false
        }
    }
}
