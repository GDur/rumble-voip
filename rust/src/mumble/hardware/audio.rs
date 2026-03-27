use crate::mumble::config::{RbConsumer, RbProducer};
use anyhow::{anyhow, Context};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use crossbeam_channel::Sender;
use ringbuf::traits::{Consumer, Observer, Producer};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;

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

pub struct SendStream(pub cpal::Stream);
// Safety: cpal::Stream is not Send on all platforms, but for our usage we only store it
// and let it run, we don't access it concurrently.
unsafe impl Send for SendStream {}

pub struct AudioBackend {
    #[allow(dead_code)]
    input_stream: SendStream,
    #[allow(dead_code)]
    output_stream: SendStream,
    input_rate: u32,
    output_rate: u32,
}

impl AudioBackend {
    pub fn new(
        input_stream: cpal::Stream,
        output_stream: cpal::Stream,
        input_rate: u32,
        output_rate: u32,
    ) -> Self {
        Self {
            input_stream: SendStream(input_stream),
            output_stream: SendStream(output_stream),
            input_rate,
            output_rate,
        }
    }

    pub fn input_rate(&self) -> u32 {
        self.input_rate
    }

    pub fn output_rate(&self) -> u32 {
        self.output_rate
    }
}

pub fn setup_audio(
    prod_in: RbProducer,
    mut cons_out: RbConsumer,
    input_notify: Sender<()>,
    output_notify: Sender<()>,
    current_rms: Arc<AtomicU32>,
    input_gain: Arc<AtomicU32>,
    config: &crate::mumble::config::MumbleConfig,
) -> anyhow::Result<AudioBackend> {
    let host = cpal::default_host();

    let input_device = match &config.capture_device_id {
        Some(id) => select_device(&host, id, true)?,
        None => select_first_working_device(&host, true)?,
    };
    let output_device = match &config.playback_device_id {
        Some(id) => select_device(&host, id, false)?,
        None => select_first_working_device(&host, false)?,
    };

    let input_config_full = input_device
        .default_input_config()
        .context("Failed to get input config after selection")?;
    let output_config_full = output_device
        .default_output_config()
        .context("Failed to get output config after selection")?;

    let mut input_config = input_config_full.config();
    let mut output_config = output_config_full.config();

    input_config.buffer_size = match config.capture_hw_buffer_size {
        AudioBufferSize::Default => cpal::BufferSize::Default,
        AudioBufferSize::Fixed(frames) => cpal::BufferSize::Fixed(frames),
    };

    output_config.buffer_size = match config.playback_hw_buffer_size {
        AudioBufferSize::Default => cpal::BufferSize::Default,
        AudioBufferSize::Fixed(frames) => cpal::BufferSize::Fixed(frames),
    };

    let input_rate = input_config.sample_rate;
    let output_rate = output_config.sample_rate;
    let input_channels = input_config.channels as usize;
    let output_channels = output_config.channels as usize;

    // Buffer size of 8192 is used as it safely covers roughly ~170ms of audio at 48kHz,
    // which is more than enough to handle our typical 10-20ms chunks.
    let mut mono_buf_in = Box::new(heapless::Vec::<f32, 8192>::new());
    mono_buf_in
        .resize(8192, 0.0)
        .expect("mono_buf_in resize failed");
    let mut mono_buf_out = Box::new(heapless::Vec::<f32, 8192>::new());
    mono_buf_out
        .resize(8192, 0.0)
        .expect("mono_buf_out resize failed");

    let mut prod_in_cache = prod_in;

    let input_stream = input_device.build_input_stream(
        &input_config,
        move |data: &[f32], _| {
            let frames = data.len() / input_channels;
            let mut sum_sq = 0.0;
            let gain = f32::from_bits(input_gain.load(Ordering::Relaxed));

            if frames > mono_buf_in.len() {
                eprintln!("Input audio frame count {} exceeds buffer capacity", frames);
                return;
            }

            for i in 0..frames {
                let sample = data[i * input_channels] * gain;
                mono_buf_in[i] = sample;
                sum_sq += sample * sample;
            }

            let rms = if frames > 0 {
                (sum_sq / frames as f32).sqrt()
            } else {
                0.0
            };
            current_rms.store(rms.to_bits(), Ordering::Relaxed);

            let _ = prod_in_cache.push_slice(&mono_buf_in[..frames]);

            // Notify encode thread every 10ms worth of frames
            if prod_in_cache.occupied_len() >= (input_rate / 100) as usize {
                let _ = input_notify.try_send(());
            }
        },
        |e| eprintln!("Input error: {}", e),
        None,
    )?;

    let output_stream = output_device.build_output_stream(
        &output_config,
        move |data: &mut [f32], _| {
            let frames = data.len() / output_channels;

            if frames > mono_buf_out.len() {
                eprintln!(
                    "Output audio frame count {} exceeds buffer capacity",
                    frames
                );
                return;
            }

            let popped = cons_out.pop_slice(&mut mono_buf_out[..frames]);

            if popped < frames {
                mono_buf_out[popped..frames].fill(0.0);
            }

            for i in 0..frames {
                let sample = mono_buf_out[i];
                for c in 0..output_channels {
                    data[i * output_channels + c] = sample;
                }
            }

            // Always notify the decode thread to top up the buffer.
            let _ = output_notify.try_send(());
        },
        |e| eprintln!("Output error: {}", e),
        None,
    )?;

    input_stream.play()?;
    output_stream.play()?;

    Ok(AudioBackend::new(
        input_stream,
        output_stream,
        input_rate,
        output_rate,
    ))
}

pub fn list_input_devices() -> Vec<AudioDevice> {
    let host = cpal::default_host();
    host.input_devices()
        .map(|devices| {
            devices
                .filter_map(|d| {
                    // Only include if it actually supports an input config
                    d.default_input_config().ok()?;

                    let id = d.id().ok()?.to_string();
                    let name = d.description().map(|desc| desc.name().to_string()).ok()?;
                    Some(AudioDevice { id, name })
                })
                .collect()
        })
        .unwrap_or_default()
}

pub fn list_output_devices() -> Vec<AudioDevice> {
    let host = cpal::default_host();
    host.output_devices()
        .map(|devices| {
            devices
                .filter_map(|d| {
                    // Only include if it actually supports an output config
                    d.default_output_config().ok()?;

                    let id = d.id().ok()?.to_string();
                    let name = d.description().map(|desc| desc.name().to_string()).ok()?;
                    Some(AudioDevice { id, name })
                })
                .collect()
        })
        .unwrap_or_default()
}

/// Selects a specific audio device by its ID.
fn select_device(
    host: &cpal::Host,
    id: &str,
    is_input: bool,
) -> Result<cpal::Device, anyhow::Error> {
    let mut devices = if is_input {
        host.input_devices()?
    } else {
        host.output_devices()?
    };

    devices
        .find(|d| d.id().map(|v| v.to_string() == *id).unwrap_or(false))
        .ok_or_else(|| anyhow!("Device with ID '{}' not found", id))
}

/// Selects the first functional audio device, preferring the official default.
fn select_first_working_device(
    host: &cpal::Host,
    is_input: bool,
) -> Result<cpal::Device, anyhow::Error> {
    // 1. Try the official default as a priority.
    let official_default = if is_input {
        host.default_input_device()
    } else {
        host.default_output_device()
    };

    if let Some(ref d) = official_default {
        // Probe if the default actually supports a config
        let has_config = if is_input {
            d.default_input_config().is_ok()
        } else {
            d.default_output_config().is_ok()
        };

        if has_config {
            return Ok(official_default.unwrap());
        }
    }

    // 2. Fallback: Brute-force discovery
    // Iterate through all devices and return the first one that doesn't error on config.
    let mut devices = if is_input {
        host.input_devices()?
    } else {
        host.output_devices()?
    };

    devices
        .find(|d| {
            if is_input {
                d.default_input_config().is_ok()
            } else {
                d.default_output_config().is_ok()
            }
        })
        .ok_or_else(|| {
            anyhow!(
                "No functional {} audio devices found on the system",
                if is_input { "input" } else { "output" }
            )
        })
}
