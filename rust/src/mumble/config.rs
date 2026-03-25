use crate::mumble::hardware::audio::AudioBufferSize;
use ringbuf::{storage::Heap, SharedRb};
use std::sync::Arc;

pub type RbProducer = ringbuf::wrap::caching::Caching<Arc<SharedRb<Heap<f32>>>, true, false>;
pub type RbConsumer = ringbuf::wrap::caching::Caching<Arc<SharedRb<Heap<f32>>>, false, true>;

#[derive(Debug, Clone)]
pub struct MumbleConfig {
    /// Target bitrate for the Opus encoder in bits per second (e.g. 72000).
    pub outgoing_audio_bitrate: u32,
    /// The size of audio chunks sent over the network in milliseconds (e.g. 10ms or 20ms).
    pub outgoing_audio_ms_per_packet: u32,
    /// Algorithm complexity of the Opus encoder (0-10, default 10).
    pub outgoing_opus_complexity: u32,

    /// The size of the software jitter buffer in milliseconds.
    /// This intentionally delays playback to handle uneven network packet arrival.
    pub incoming_jitter_buffer_ms: u32,

    /// The ID of the audio output device to use. If None, the default device is used.
    pub playback_device_id: Option<String>,
    /// The requested size of the operating system's hardware playback output buffer.
    pub playback_hw_buffer_size: AudioBufferSize,

    /// The requested size of the operating system's hardware capture input buffer.
    pub capture_hw_buffer_size: AudioBufferSize,
    /// The ID of the audio input device to use. If None, the default device is used.
    pub capture_device_id: Option<String>,
}

impl Default for MumbleConfig {
    fn default() -> Self {
        Self {
            outgoing_audio_bitrate: 72000,
            outgoing_audio_ms_per_packet: 10,
            outgoing_opus_complexity: 10,
            incoming_jitter_buffer_ms: 40,
            playback_hw_buffer_size: super::hardware::audio::AudioBufferSize::Default,
            capture_hw_buffer_size: super::hardware::audio::AudioBufferSize::Default,
            capture_device_id: None,
            playback_device_id: None,
        }
    }
}
