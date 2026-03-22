use flutter_rust_bridge::frb;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use opus_rs::{Application, OpusEncoder};
use ringbuf::{traits::{Consumer, Producer, Split, Observer}, HeapRb};
use std::sync::{Arc, Mutex};
use std::thread;

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[derive(Debug, Clone)]
pub struct AudioDevice {
    pub name: String,
    pub is_default: bool,
}

pub fn list_input_devices() -> Vec<AudioDevice> {
    let host = cpal::default_host();
    let default_device = host.default_input_device().and_then(|d| d.name().ok());
    
    let mut devices = Vec::new();
    if let Ok(input_devices) = host.input_devices() {
        for device in input_devices {
            if let Ok(name) = device.name() {
                devices.push(AudioDevice {
                    is_default: Some(name.clone()) == default_device,
                    name,
                });
            }
        }
    }
    devices
}

pub struct RustAudioRecorder {
    stop_signal: Arc<std::sync::Mutex<bool>>,
}

impl RustAudioRecorder {
    #[frb(sync)]
    pub fn new() -> Self {
        Self {
            stop_signal: Arc::new(std::sync::Mutex::new(false)),
        }
    }

    pub fn start(
        &self,
        device_name: Option<String>,
        sink: crate::frb_generated::StreamSink<Vec<u8>>,
    ) -> Result<(), String> {
        let stop_signal = self.stop_signal.clone();
        *stop_signal.lock().unwrap() = false;

        thread::spawn(move || {
            let host = cpal::default_host();
            let device = if let Some(ref name) = device_name {
                host.input_devices().ok().and_then(|mut devices| {
                    devices.find(|d| d.name().ok().as_ref() == Some(name))
                })
            } else {
                host.default_input_device()
            };

            let device = match device {
                Some(d) => d,
                None => return,
            };

            let config = cpal::StreamConfig {
                channels: 1,
                sample_rate: cpal::SampleRate(48000),
                buffer_size: cpal::BufferSize::Fixed(960),
            };

            let rb = HeapRb::<i16>::new(4800);
            let (mut producer, mut consumer) = rb.split();

            let input_data_fn = move |data: &[i16], _: &cpal::InputCallbackInfo| {
                let _ = producer.push_slice(data);
            };

            let stream = match device.build_input_stream(&config, input_data_fn, |_| {}, None) {
                Ok(s) => s,
                Err(_) => return,
            };

            if stream.play().is_err() { return; }

            let mut encoder = OpusEncoder::new(48000, 1, Application::Voip).unwrap();
            encoder.bitrate_bps = 48000;
            encoder.complexity = 10;
            
            let mut pcm_frame = vec![0i16; 960];
            let mut f32_frame = vec![0.0f32; 960];
            let mut output_buf = vec![0u8; 4000];

            while !*stop_signal.lock().unwrap() {
                if consumer.occupied_len() >= 960 {
                    consumer.pop_slice(&mut pcm_frame);
                    for (i, &sample) in pcm_frame.iter().enumerate() {
                        f32_frame[i] = sample as f32 / 32768.0;
                    }
                    if let Ok(len) = encoder.encode(&f32_frame, 960, &mut output_buf) {
                        let _ = sink.add(output_buf[..len].to_vec());
                    }
                } else {
                    thread::sleep(std::time::Duration::from_millis(2));
                }
            }
            let _ = stream.pause();
        });

        Ok(())
    }

    #[frb(sync)]
    pub fn stop(&self) {
        *self.stop_signal.lock().unwrap() = true;
    }
}
