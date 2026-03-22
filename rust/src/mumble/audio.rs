use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use ringbuf::{HeapRb, wrap::{CachingCons, CachingProd}, traits::{Split, Consumer, Producer}};
use std::sync::Arc;

pub type AudioConsumer = CachingCons<Arc<HeapRb<i16>>>;
pub type AudioProducer = CachingProd<Arc<HeapRb<i16>>>;

pub struct AudioManager {
    _input_stream: cpal::Stream,
    _output_stream: cpal::Stream,
    pub input_consumer: AudioConsumer,
    pub output_producer: AudioProducer,
}

impl AudioManager {
    pub fn new() -> anyhow::Result<Self> {
        let host = cpal::default_host();
        
        let input_device = host.default_input_device()
            .ok_or_else(|| anyhow::anyhow!("No input device found"))?;
        let output_device = host.default_output_device()
            .ok_or_else(|| anyhow::anyhow!("No output device found"))?;

        let config = cpal::StreamConfig {
            channels: 1,
            sample_rate: cpal::SampleRate(48000),
            buffer_size: cpal::BufferSize::Fixed(960),
        };

        // Input Ringbuffer (Mic -> Rust)
        let rb_in = Arc::new(HeapRb::<i16>::new(4800));
        let (mut producer_in, consumer_in) = rb_in.split();

        let input_data_fn = move |data: &[i16], _: &cpal::InputCallbackInfo| {
            let _ = producer_in.push_slice(data);
        };

        let input_stream = input_device.build_input_stream(&config, input_data_fn, |_| {}, None)?;

        // Output Ringbuffer (Rust -> Speakers)
        let rb_out = Arc::new(HeapRb::<i16>::new(9600));
        let (producer_out, mut consumer_out) = rb_out.split();

        let output_data_fn = move |data: &mut [i16], _: &cpal::OutputCallbackInfo| {
            let samples_read = consumer_out.pop_slice(data);
            if samples_read < data.len() {
                // Fill remaining with silence if underrun
                for sample in &mut data[samples_read..] {
                    *sample = 0;
                }
            }
        };

        let output_stream = output_device.build_output_stream(&config, output_data_fn, |_| {}, None)?;

        input_stream.play()?;
        output_stream.play()?;

        Ok(Self {
            _input_stream: input_stream,
            _output_stream: output_stream,
            input_consumer: consumer_in,
            output_producer: producer_out,
        })
    }
}

pub fn list_input_devices() -> Vec<String> {
    let host = cpal::default_host();
    host.input_devices().map(|devices| {
        devices.filter_map(|d| d.name().ok()).collect()
    }).unwrap_or_default()
}

pub fn list_output_devices() -> Vec<String> {
    let host = cpal::default_host();
    host.output_devices().map(|devices| {
        devices.filter_map(|d| d.name().ok()).collect()
    }).unwrap_or_default()
}
