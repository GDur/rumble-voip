use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use ringbuf::{
    storage::Heap,
    traits::{Consumer, Producer, Split},
    wrap::caching::Caching,
    HeapRb, SharedRb,
};
use std::sync::Arc;

pub struct SendStream(pub cpal::Stream);
unsafe impl Send for SendStream {}

pub struct AudioStreams {
    pub input_stream: SendStream,
    pub output_stream: SendStream,
    pub input_consumer: Caching<Arc<SharedRb<Heap<i16>>>, false, true>,
    pub output_producer: Caching<Arc<SharedRb<Heap<i16>>>, true, false>,
}

pub fn setup_audio() -> anyhow::Result<AudioStreams> {
    println!("--- RUST: setup_audio starting ---");
    let host = cpal::default_host();

    let input_device = host
        .default_input_device()
        .ok_or_else(|| anyhow::anyhow!("No input device found"))?;
    let output_device = host
        .default_output_device()
        .ok_or_else(|| anyhow::anyhow!("No output device found"))?;

    log::info!("Input device: {}", input_device.name().unwrap_or_default());
    log::info!(
        "Output device: {}",
        output_device.name().unwrap_or_default()
    );

    let input_config = input_device.default_input_config()?;
    let output_config = output_device.default_output_config()?;

    // Ringbuffers
    let rb_in = Arc::new(HeapRb::<i16>::new(48000));
    let (producer_in, consumer_in) = rb_in.split();

    let input_channels = input_config.channels() as usize;
    let mut prod_in = producer_in;
    let input_stream = match input_config.sample_format() {
        cpal::SampleFormat::F32 => input_device.build_input_stream(
            &input_config.into(),
            move |data: &[f32], _| {
                for frame in data.chunks(input_channels) {
                    if let Some(&sample) = frame.get(0) {
                        let s_i16 = (sample * 32767.0).clamp(-32768.0, 32767.0) as i16;
                        let _ = prod_in.try_push(s_i16);
                    }
                }
            },
            |e| log::error!("Input stream error: {}", e),
            None,
        )?,
        cpal::SampleFormat::I16 => input_device.build_input_stream(
            &input_config.into(),
            move |data: &[i16], _| {
                for frame in data.chunks(input_channels) {
                    if let Some(&sample) = frame.get(0) {
                        let _ = prod_in.try_push(sample);
                    }
                }
            },
            |e| log::error!("Input stream error: {}", e),
            None,
        )?,
        _ => return Err(anyhow::anyhow!("Unsupported input sample format")),
    };

    let rb_out = Arc::new(HeapRb::<i16>::new(48000));
    let (producer_out, consumer_out) = rb_out.split();

    let output_channels = output_config.channels() as usize;
    let mut cons_out = consumer_out;
    let output_stream = match output_config.sample_format() {
        cpal::SampleFormat::F32 => output_device.build_output_stream(
            &output_config.into(),
            move |data: &mut [f32], _| {
                for frame in data.chunks_mut(output_channels) {
                    let sample_i16 = cons_out.try_pop().unwrap_or(0);
                    let sample_f32 = sample_i16 as f32 / 32768.0;
                    for out_sample in frame {
                        *out_sample = sample_f32;
                    }
                }
            },
            |e| log::error!("Output stream error: {}", e),
            None,
        )?,
        cpal::SampleFormat::I16 => output_device.build_output_stream(
            &output_config.into(),
            move |data: &mut [i16], _| {
                for frame in data.chunks_mut(output_channels) {
                    let sample_i16 = cons_out.try_pop().unwrap_or(0);
                    for out_sample in frame {
                        *out_sample = sample_i16;
                    }
                }
            },
            |e| log::error!("Output stream error: {}", e),
            None,
        )?,
        _ => return Err(anyhow::anyhow!("Unsupported output sample format")),
    };

    input_stream.play()?;
    output_stream.play()?;

    println!("--- RUST: audio streams started ---");
    Ok(AudioStreams {
        input_stream: SendStream(input_stream),
        output_stream: SendStream(output_stream),
        input_consumer: consumer_in,
        output_producer: producer_out,
    })
}

pub fn list_input_devices() -> Vec<String> {
    let host = cpal::default_host();
    host.input_devices()
        .map(|devices| devices.filter_map(|d| d.name().ok()).collect())
        .unwrap_or_default()
}

pub fn list_output_devices() -> Vec<String> {
    let host = cpal::default_host();
    host.output_devices()
        .map(|devices| devices.filter_map(|d| d.name().ok()).collect())
        .unwrap_or_default()
}
