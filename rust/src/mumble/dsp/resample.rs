use sonora_common_audio::push_sinc_resampler::PushSincResampler;

pub struct Resampler {
    resampler: PushSincResampler,
    in_buffer: Box<heapless::Vec<f32, 8192>>,
    out_buffer: Box<heapless::Vec<f32, 8192>>,
    input_samples: usize,
}

impl Resampler {
    pub fn new(in_rate: u32, out_rate: u32, frame_ms: u32) -> anyhow::Result<Self> {
        let input_samples = (in_rate as f32 * (frame_ms as f32 / 1000.0)).ceil() as usize;
        let output_samples = (out_rate as f32 * (frame_ms as f32 / 1000.0)).ceil() as usize;

        let resampler = PushSincResampler::new(input_samples, output_samples);

        let mut out_buffer = Box::new(heapless::Vec::new());
        out_buffer.resize(output_samples, 0.0).unwrap();

        Ok(Self {
            resampler,
            in_buffer: Box::new(heapless::Vec::new()),
            out_buffer,
            input_samples,
        })
    }

    pub fn process(&mut self, data: &[f32], accumulator: &mut heapless::Vec<f32, 8192>) {
        // The in_buffer is required for frame alignment. Input data may arrive in
        // chunks that don't match the resampler's expected frame size (input_samples).
        // We accumulate data until we have at least one full frame, then process and
        // drain it, keeping any leftovers for the next call.
        self.in_buffer.extend_from_slice(data).unwrap();

        while self.in_buffer.len() >= self.input_samples {
            self.resampler
                .resample(&self.in_buffer[..self.input_samples], &mut self.out_buffer);
            accumulator.extend_from_slice(&self.out_buffer).unwrap();

            self.in_buffer.rotate_left(self.input_samples);
            self.in_buffer
                .truncate(self.in_buffer.len() - self.input_samples);
        }
    }
}
