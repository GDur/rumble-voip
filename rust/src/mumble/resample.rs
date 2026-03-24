use sonora_common_audio::push_sinc_resampler::PushSincResampler;

pub struct AudioResampler {
    resampler: PushSincResampler,
    in_buffer: Vec<f32>,
    out_buffer: Vec<f32>,
    input_samples: usize,
}

impl AudioResampler {
    pub fn new(in_rate: u32, out_rate: u32, frame_ms: u32) -> anyhow::Result<Self> {
        let input_samples = (in_rate as f32 * (frame_ms as f32 / 1000.0)).ceil() as usize;
        let output_samples = (out_rate as f32 * (frame_ms as f32 / 1000.0)).ceil() as usize;

        let resampler = PushSincResampler::new(input_samples, output_samples);

        Ok(Self {
            resampler,
            in_buffer: Vec::with_capacity(8192),
            out_buffer: vec![0.0; output_samples],
            input_samples,
        })
    }

    pub fn process(&mut self, data: &[f32], accumulator: &mut Vec<f32>) {
        // The in_buffer is required for frame alignment. Input data may arrive in
        // chunks that don't match the resampler's expected frame size (input_samples).
        // We accumulate data until we have at least one full frame, then process and
        // drain it, keeping any leftovers for the next call.
        self.in_buffer.extend_from_slice(data);

        while self.in_buffer.len() >= self.input_samples {
            self.resampler
                .resample(&self.in_buffer[..self.input_samples], &mut self.out_buffer);
            accumulator.extend_from_slice(&self.out_buffer);
            self.in_buffer.drain(..self.input_samples);
        }
    }
}
