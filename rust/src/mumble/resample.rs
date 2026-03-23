use audioadapter_buffers::direct::InterleavedSlice;
use rubato::{Fft, FixedSync, Resampler};

pub struct AudioResampler {
    resampler: Fft<f32>,
    in_buffer: Vec<f32>,
    out_buffer: Vec<f32>,
}

impl AudioResampler {
    pub fn new(in_rate: u32, out_rate: u32, frame_ms: u32) -> anyhow::Result<Self> {
        // We use FixedSync::Input with a chunk size representing exactly the frame_ms of audio.
        let chunk_size = (in_rate as f32 * (frame_ms as f32 / 1000.0)).ceil() as usize;

        let resampler = Fft::<f32>::new(
            in_rate as usize,
            out_rate as usize,
            chunk_size,
            1, // sub_chunks
            1, // nbr_channels
            FixedSync::Input,
        )
        .map_err(|e| anyhow::anyhow!("Resampler error: {}", e))?;

        Ok(Self {
            resampler,
            in_buffer: Vec::with_capacity(8192),
            out_buffer: vec![0.0; 8192],
        })
    }

    pub fn process(&mut self, data: &[f32], accumulator: &mut Vec<f32>) {
        self.in_buffer.extend_from_slice(data);

        while self.in_buffer.len() >= self.resampler.input_frames_next() {
            let next = self.resampler.input_frames_next();
            let input_adapter = InterleavedSlice::new(&self.in_buffer[..next], 1, next).unwrap();

            let max_out = self.resampler.output_frames_max();
            if self.out_buffer.len() < max_out {
                self.out_buffer.resize(max_out, 0.0);
            }

            let mut output_adapter =
                InterleavedSlice::new_mut(&mut self.out_buffer, 1, max_out).unwrap();

            if let Ok((_, out_len)) =
                self.resampler
                    .process_into_buffer(&input_adapter, &mut output_adapter, None)
            {
                accumulator.extend_from_slice(&self.out_buffer[..out_len]);
            }

            self.in_buffer.drain(..next);
        }
    }
}
