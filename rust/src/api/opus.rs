use flutter_rust_bridge::frb;
use opus_rs::{Application, OpusDecoder, OpusEncoder};

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub struct RustOpusEncoder {
    pub(crate) inner: OpusEncoder,
    pub(crate) channels: i32,
    // Internal buffer for i16 -> f32 conversion (unavoidable due to library requirements)
    pub(crate) f32_buf: Vec<f32>,
}

impl RustOpusEncoder {
    #[frb(sync)]
    pub fn new(sample_rate: i32, channels: i32, application: i32) -> Result<Self, String> {
        let app = match application {
            2048 => Application::Voip,
            2049 => Application::Audio,
            _ => Application::Voip,
        };
        let encoder = OpusEncoder::new(sample_rate, channels as usize, app).map_err(|e| format!("{:?}", e))?;
        Ok(Self {
            inner: encoder,
            channels,
            f32_buf: Vec::with_capacity(5760), 
        })
    }

    /// ZERO-COPY ENCODE
    /// Reads from pcm_ptr and writes directly to output_ptr.
    /// Both pointers are managed by Dart (FFI malloc).
    #[frb(sync)]
    pub fn encode_raw(
        &mut self, 
        pcm_ptr: u64, 
        pcm_len: i32, 
        output_ptr: u64, 
        output_capacity: i32
    ) -> i32 {
        unsafe {
            let pcm = std::slice::from_raw_parts(pcm_ptr as *const i16, pcm_len as usize);
            let output = std::slice::from_raw_parts_mut(output_ptr as *mut u8, output_capacity as usize);

            // Conversion to f32 is required by opus-rs
            self.f32_buf.clear();
            for &x in pcm.iter() {
                self.f32_buf.push(x as f32 / 32768.0);
            }

            let frame_size = pcm_len / self.channels;

            match self.inner.encode(&self.f32_buf, frame_size as usize, output) {
                Ok(len) => len as i32,
                Err(_) => -1,
            }
        }
    }

    #[frb(sync)]
    pub fn set_bitrate(&mut self, bitrate_bps: i32) {
        self.inner.bitrate_bps = bitrate_bps;
    }

    #[frb(sync)]
    pub fn set_complexity(&mut self, complexity: i32) {
        self.inner.complexity = complexity;
    }

    #[frb(sync)]
    pub fn set_vbr(&mut self, vbr: bool) {
        self.inner.use_cbr = !vbr;
    }

    #[frb(sync)]
    pub fn set_inband_fec(&mut self, enabled: bool) {
        self.inner.use_inband_fec = enabled;
    }

    #[frb(sync)]
    pub fn set_packet_loss_perc(&mut self, percentage: i32) {
        self.inner.packet_loss_perc = percentage;
    }
}

pub struct RustOpusDecoder {
    pub(crate) inner: OpusDecoder,
    pub(crate) channels: i32,
    // Internal buffer for f32 -> i16 conversion
    pub(crate) output_f32: Vec<f32>,
}

impl RustOpusDecoder {
    #[frb(sync)]
    pub fn new(sample_rate: i32, channels: i32) -> Result<Self, String> {
        let decoder = OpusDecoder::new(sample_rate, channels as usize).map_err(|e| format!("{:?}", e))?;
        Ok(Self {
            inner: decoder,
            channels,
            output_f32: vec![0.0f32; 5760 * channels as usize],
        })
    }

    /// ZERO-COPY DECODE
    /// Reads from opus_ptr and writes directly to output_ptr.
    /// Both pointers are managed by Dart (FFI malloc).
    #[frb(sync)]
    pub fn decode_raw(
        &mut self,
        opus_ptr: u64,
        opus_len: i32,
        output_ptr: u64,
        frame_size: i32,
    ) -> i32 {
        unsafe {
            let opus_data = std::slice::from_raw_parts(opus_ptr as *const u8, opus_len as usize);
            let output = std::slice::from_raw_parts_mut(output_ptr as *mut i16, (frame_size * self.channels) as usize);

            match self.inner.decode(opus_data, frame_size as usize, &mut self.output_f32) {
                Ok(samples) => {
                    for i in 0..(samples * self.channels as usize) {
                        output[i] = (self.output_f32[i] * 32767.0).clamp(-32768.0, 32767.0) as i16;
                    }
                    samples as i32
                }
                Err(_) => -1,
            }
        }
    }
}
