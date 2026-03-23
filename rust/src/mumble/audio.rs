use audioadapter_buffers::direct::InterleavedSlice;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use ringbuf::{
    storage::Heap,
    traits::{Consumer, Producer, Split},
    wrap::caching::Caching,
    HeapRb, SharedRb,
};
use rubato::{
    calculate_cutoff, Async, FixedAsync, Indexing, Resampler, SincInterpolationParameters,
    SincInterpolationType, WindowFunction,
};
use std::sync::Arc;

const MUMBLE_SAMPLE_RATE: u32 = 48000;

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

    let input_config = input_device.default_input_config()?;
    let output_config = output_device.default_output_config()?;

    let input_rate = input_config.sample_rate().0;
    let output_rate = output_config.sample_rate().0;

    println!(
        "Input device: {} ({} Hz)",
        input_device.name().unwrap_or_default(),
        input_rate
    );
    println!(
        "Output device: {} ({} Hz)",
        output_device.name().unwrap_or_default(),
        output_rate
    );

    // Ringbuffers: Always MUMBLE_SAMPLE_RATE Hz for Mumble compatibility
    let rb_in = Arc::new(HeapRb::<i16>::new(MUMBLE_SAMPLE_RATE as usize));
    let (producer_in, consumer_in) = rb_in.split();

    // Setup rubato resampler for input: [Native -> MUMBLE_SAMPLE_RATE]
    let resample_ratio = MUMBLE_SAMPLE_RATE as f64 / input_rate as f64;

    let sinc_len = 128;
    let window = WindowFunction::BlackmanHarris2;
    let f_cutoff = calculate_cutoff(sinc_len, window);
    let params = SincInterpolationParameters {
        sinc_len,
        f_cutoff,
        interpolation: SincInterpolationType::Linear,
        oversampling_factor: 128,
        window,
    };

    let mut resampler_in: Option<Async<f32>> = if input_rate != MUMBLE_SAMPLE_RATE {
        Some(
            Async::<f32>::new_sinc(
                resample_ratio,
                1.1,
                &params,
                1024, // Input chunk size
                1,    // channels
                FixedAsync::Input,
            )
            .map_err(|e| anyhow::anyhow!("Failed to create input resampler: {}", e))?,
        )
    } else {
        None
    };

    let input_channels = input_config.channels() as usize;
    let mut prod_in = producer_in;
    let mut input_buffer_f32 = Vec::new();

    let input_stream = match input_config.sample_format() {
        cpal::SampleFormat::F32 => input_device.build_input_stream(
            &input_config.into(),
            move |data: &[f32], _| {
                let mut mono_f32 = Vec::with_capacity(data.len() / input_channels);
                for frame in data.chunks(input_channels) {
                    mono_f32.push(frame[0]);
                }

                if let Some(resampler) = &mut resampler_in {
                    input_buffer_f32.extend_from_slice(&mono_f32);
                    let mut input_frames_next = resampler.input_frames_next();
                    while input_buffer_f32.len() >= input_frames_next {
                        let chunk: Vec<f32> = input_buffer_f32.drain(..input_frames_next).collect();
                        let input_adapter =
                            InterleavedSlice::new(&chunk, 1, input_frames_next).unwrap();

                        let max_out = resampler.output_frames_max();
                        let mut out_buf = vec![0.0f32; max_out];
                        let mut output_adapter =
                            InterleavedSlice::new_mut(&mut out_buf, 1, max_out).unwrap();

                        let indexing = Indexing {
                            input_offset: 0,
                            output_offset: 0,
                            active_channels_mask: None,
                            partial_len: None,
                        };

                        if let Ok((_in_len, out_len)) = resampler.process_into_buffer(
                            &input_adapter,
                            &mut output_adapter,
                            Some(&indexing),
                        ) {
                            for &s in &out_buf[..out_len] {
                                let s_i16 = (s * i16::MAX as f32)
                                    .clamp(i16::MIN as f32, i16::MAX as f32)
                                    as i16;
                                let _ = prod_in.try_push(s_i16);
                            }
                        }
                        input_frames_next = resampler.input_frames_next();
                    }
                } else {
                    for s in mono_f32 {
                        let s_i16 =
                            (s * i16::MAX as f32).clamp(i16::MIN as f32, i16::MAX as f32) as i16;
                        let _ = prod_in.try_push(s_i16);
                    }
                }
            },
            |e| eprintln!("Input stream error: {}", e),
            None,
        )?,
        cpal::SampleFormat::I16 => input_device.build_input_stream(
            &input_config.into(),
            move |data: &[i16], _| {
                let mut mono_f32 = Vec::with_capacity(data.len() / input_channels);
                for frame in data.chunks(input_channels) {
                    // Use i16::MIN (32768) for normalization so that -32768 / 32768.0 == -1.0 exactly
                    mono_f32.push(frame[0] as f32 / -(i16::MIN as f32));
                }

                if let Some(resampler) = &mut resampler_in {
                    input_buffer_f32.extend_from_slice(&mono_f32);
                    let mut input_frames_next = resampler.input_frames_next();
                    while input_buffer_f32.len() >= input_frames_next {
                        let chunk: Vec<f32> = input_buffer_f32.drain(..input_frames_next).collect();
                        let input_adapter =
                            InterleavedSlice::new(&chunk, 1, input_frames_next).unwrap();

                        let max_out = resampler.output_frames_max();
                        let mut out_buf = vec![0.0f32; max_out];
                        let mut output_adapter =
                            InterleavedSlice::new_mut(&mut out_buf, 1, max_out).unwrap();

                        let indexing = Indexing {
                            input_offset: 0,
                            output_offset: 0,
                            active_channels_mask: None,
                            partial_len: None,
                        };

                        if let Ok((_in_len, out_len)) = resampler.process_into_buffer(
                            &input_adapter,
                            &mut output_adapter,
                            Some(&indexing),
                        ) {
                            for &s in &out_buf[..out_len] {
                                let s_i16 = (s * i16::MAX as f32)
                                    .clamp(i16::MIN as f32, i16::MAX as f32)
                                    as i16;
                                let _ = prod_in.try_push(s_i16);
                            }
                        }
                        input_frames_next = resampler.input_frames_next();
                    }
                } else {
                    for s in mono_f32 {
                        let s_i16 =
                            (s * i16::MAX as f32).clamp(i16::MIN as f32, i16::MAX as f32) as i16;
                        let _ = prod_in.try_push(s_i16);
                    }
                }
            },
            |e| eprintln!("Input stream error: {}", e),
            None,
        )?,
        _ => return Err(anyhow::anyhow!("Unsupported input sample format")),
    };

    let rb_out = Arc::new(HeapRb::<i16>::new(MUMBLE_SAMPLE_RATE as usize));
    let (producer_out, consumer_out) = rb_out.split();

    // Setup rubato resampler for output: [MUMBLE_SAMPLE_RATE -> Native]
    let resample_ratio_out = output_rate as f64 / MUMBLE_SAMPLE_RATE as f64;

    let params_out = SincInterpolationParameters {
        sinc_len,
        f_cutoff,
        interpolation: SincInterpolationType::Linear,
        oversampling_factor: 128,
        window,
    };

    let mut resampler_out: Option<Async<f32>> = if output_rate != MUMBLE_SAMPLE_RATE {
        Some(
            Async::<f32>::new_sinc(
                resample_ratio_out,
                1.1,
                &params_out,
                1024, // Input chunk size (from Mumble side)
                1,
                FixedAsync::Input,
            )
            .map_err(|e| anyhow::anyhow!("Failed to create output resampler: {}", e))?,
        )
    } else {
        None
    };

    let output_channels = output_config.channels() as usize;
    let mut cons_out = consumer_out;
    let mut output_buffer_f32 = Vec::new();

    let output_stream = match output_config.sample_format() {
        cpal::SampleFormat::F32 => output_device.build_output_stream(
            &output_config.into(),
            move |data: &mut [f32], _| {
                let frames_needed = data.len() / output_channels;

                if let Some(resampler) = &mut resampler_out {
                    while output_buffer_f32.len() < frames_needed {
                        let needed_in = resampler.input_frames_next();
                        let mut chunk_in = vec![0.0f32; needed_in];
                        for i in 0..needed_in {
                            // Use i16::MIN (32768) for normalization so that -32768 / 32768.0 == -1.0 exactly
                            chunk_in[i] =
                                cons_out.try_pop().unwrap_or(0) as f32 / -(i16::MIN as f32);
                        }
                        let input_adapter = InterleavedSlice::new(&chunk_in, 1, needed_in).unwrap();

                        let max_out = resampler.output_frames_max();
                        let mut out_buf = vec![0.0f32; max_out];
                        let mut output_adapter =
                            InterleavedSlice::new_mut(&mut out_buf, 1, max_out).unwrap();

                        let indexing = Indexing {
                            input_offset: 0,
                            output_offset: 0,
                            active_channels_mask: None,
                            partial_len: None,
                        };

                        if let Ok((_in_len, out_len)) = resampler.process_into_buffer(
                            &input_adapter,
                            &mut output_adapter,
                            Some(&indexing),
                        ) {
                            output_buffer_f32.extend_from_slice(&out_buf[..out_len]);
                        }
                    }

                    let out_chunk: Vec<f32> = output_buffer_f32.drain(..frames_needed).collect();
                    for (i, frame) in data.chunks_mut(output_channels).enumerate() {
                        for out_sample in frame {
                            *out_sample = out_chunk[i];
                        }
                    }
                } else {
                    for frame in data.chunks_mut(output_channels) {
                        let s_i16 = cons_out.try_pop().unwrap_or(0);
                        // Use i16::MIN (32768) for normalization so that -32768 / 32768.0 == -1.0 exactly
                        let s_f32 = s_i16 as f32 / -(i16::MIN as f32);
                        for out_sample in frame {
                            *out_sample = s_f32;
                        }
                    }
                }
            },
            |e| eprintln!("Output stream error: {}", e),
            None,
        )?,
        cpal::SampleFormat::I16 => output_device.build_output_stream(
            &output_config.into(),
            move |data: &mut [i16], _| {
                let frames_needed = data.len() / output_channels;

                if let Some(resampler) = &mut resampler_out {
                    while output_buffer_f32.len() < frames_needed {
                        let needed_in = resampler.input_frames_next();
                        let mut chunk_in = vec![0.0f32; needed_in];
                        for i in 0..needed_in {
                            // Use i16::MIN (32768) for normalization so that -32768 / 32768.0 == -1.0 exactly
                            chunk_in[i] =
                                cons_out.try_pop().unwrap_or(0) as f32 / -(i16::MIN as f32);
                        }
                        let input_adapter = InterleavedSlice::new(&chunk_in, 1, needed_in).unwrap();

                        let max_out = resampler.output_frames_max();
                        let mut out_buf = vec![0.0f32; max_out];
                        let mut output_adapter =
                            InterleavedSlice::new_mut(&mut out_buf, 1, max_out).unwrap();

                        let indexing = Indexing {
                            input_offset: 0,
                            output_offset: 0,
                            active_channels_mask: None,
                            partial_len: None,
                        };

                        if let Ok((_in_len, out_len)) = resampler.process_into_buffer(
                            &input_adapter,
                            &mut output_adapter,
                            Some(&indexing),
                        ) {
                            output_buffer_f32.extend_from_slice(&out_buf[..out_len]);
                        }
                    }

                    let out_chunk: Vec<f32> = output_buffer_f32.drain(..frames_needed).collect();
                    for (i, frame) in data.chunks_mut(output_channels).enumerate() {
                        let s_i16 = (out_chunk[i] * i16::MAX as f32)
                            .clamp(i16::MIN as f32, i16::MAX as f32)
                            as i16;
                        for out_sample in frame {
                            *out_sample = s_i16;
                        }
                    }
                } else {
                    for frame in data.chunks_mut(output_channels) {
                        let s_i16 = cons_out.try_pop().unwrap_or(0);
                        for out_sample in frame {
                            *out_sample = s_i16;
                        }
                    }
                }
            },
            |e| eprintln!("Output stream error: {}", e),
            None,
        )?,
        _ => return Err(anyhow::anyhow!("Unsupported output sample format")),
    };

    input_stream.play()?;
    output_stream.play()?;

    println!("--- RUST: audio streams started with rubato v1.0.1 resampling ---");
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
