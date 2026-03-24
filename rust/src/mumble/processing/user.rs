use crate::mumble::opus_codec::SafeOpusDecoder;
use crate::mumble::types::AudioPacket;
use std::collections::VecDeque;
use std::time::Instant;

pub struct RemoteUser {
    pub decoder: SafeOpusDecoder,
    pub jitter_buffer: VecDeque<AudioPacket>,
    pub is_talking: bool,
    pub last_packet_time: Instant,
    pub volume: f32,
}

impl RemoteUser {
    pub fn new(sample_rate: i32, channels: i32) -> Self {
        Self {
            decoder: SafeOpusDecoder::new(sample_rate, channels).unwrap(),
            jitter_buffer: VecDeque::with_capacity(10),
            is_talking: false,
            last_packet_time: Instant::now(),
            volume: 1.0,
        }
    }

    pub fn decode_frame(&mut self, frame_size: usize, out: &mut [f32]) -> bool {
        let packet = self.jitter_buffer.pop_front();
        let payload = packet.as_ref().map(|p| p.payload.as_ref());

        if self.decoder.decode(payload, frame_size, out).is_ok() {
            if self.volume != 1.0 {
                for sample in out.iter_mut() {
                    *sample *= self.volume;
                }
            }
            true
        } else {
            false
        }
    }
}
