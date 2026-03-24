use ringbuf::{storage::Heap, SharedRb};
use std::sync::Arc;

pub type RbProducer = ringbuf::wrap::caching::Caching<Arc<SharedRb<Heap<f32>>>, true, false>;
pub type RbConsumer = ringbuf::wrap::caching::Caching<Arc<SharedRb<Heap<f32>>>, false, true>;

pub const MUMBLE_SAMPLE_RATE: u32 = 48000;

#[derive(Debug, Clone)]
pub enum AudioBufferSize {
    /// Use the operating system's default hardware buffer size.
    Default,
    /// Request a specific hardware buffer size (in frames).
    Fixed(u32),
}

#[derive(Debug, Clone)]
pub struct MumbleConfig {
    /// Target bitrate for the Opus encoder in bits per second (e.g. 72000).
    pub audio_bitrate: u32,
    /// The size of audio chunks sent over the network in milliseconds (e.g. 10ms or 20ms).
    pub audio_frame_ms: u32,
    /// Algorithm complexity of the Opus encoder (0-10, default 10).
    pub opus_complexity: u32,
    /// The size of the software jitter buffer in milliseconds.
    /// This intentionally delays playback to handle uneven network packet arrival.
    pub jitter_buffer_ms: u32,
    /// The requested size of the operating system's hardware audio output buffer.
    pub output_buffer_size: AudioBufferSize,
    /// The requested size of the operating system's hardware audio input buffer.
    pub input_buffer_size: AudioBufferSize,
}

impl Default for MumbleConfig {
    fn default() -> Self {
        Self {
            audio_bitrate: 72000,
            audio_frame_ms: 10,
            opus_complexity: 10,
            jitter_buffer_ms: 40,
            output_buffer_size: AudioBufferSize::Default,
            input_buffer_size: AudioBufferSize::Default,
        }
    }
}

#[derive(Debug, Clone)]
pub struct AudioPacket {
    pub payload: heapless::Vec<u8, 512>,
    pub is_last: bool,
}

#[derive(Debug)]
pub struct IncomingAudio {
    pub session_id: u32,
    pub packet: AudioPacket,
}
