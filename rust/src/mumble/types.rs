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
pub struct AudioDevice {
    pub name: String,
    pub id: String,
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
    /// The ID of the audio input device to use. If None, the default device is used.
    pub input_device_id: Option<String>,
    /// The ID of the audio output device to use. If None, the default device is used.
    pub output_device_id: Option<String>,
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
            input_device_id: None,
            output_device_id: None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct AudioPacket {
    payload: heapless::Vec<u8, 512>,
    is_last: bool,
}

impl AudioPacket {
    pub fn new(payload: heapless::Vec<u8, 512>, is_last: bool) -> Self {
        Self { payload, is_last }
    }

    pub fn payload(&self) -> &[u8] {
        &self.payload
    }

    pub fn is_last(&self) -> bool {
        self.is_last
    }
}

#[derive(Debug)]
pub struct IncomingAudio {
    session_id: u32,
    packet: AudioPacket,
}

impl IncomingAudio {
    pub fn new(session_id: u32, packet: AudioPacket) -> Self {
        Self { session_id, packet }
    }

    pub fn session_id(&self) -> u32 {
        self.session_id
    }

    pub fn packet(&self) -> &AudioPacket {
        &self.packet
    }

    pub fn into_packet(self) -> AudioPacket {
        self.packet
    }
}
