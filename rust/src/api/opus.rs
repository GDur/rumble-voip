use flutter_rust_bridge::frb;
use opus_rs::{Application, OpusDecoder, OpusEncoder};

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub struct RustOpusEncoder {
    inner: OpusEncoder,
    channels: i32,
}

impl RustOpusEncoder {
    #[frb(sync)]
    pub fn new(sample_rate: i32, channels: i32, application: i32) -> Result<Self, String> {
        let app = match application {
            2048 => Application::Voip,
            2049 => Application::Audio,
            // LowDelay is not in opus-rs 0.1
            _ => Application::Voip,
        };
        let encoder = OpusEncoder::new(sample_rate, channels as usize, app).map_err(|e| format!("{:?}", e))?;
        Ok(Self {
            inner: encoder,
            channels,
        })
    }

    #[frb(sync)]
    pub fn encode(&mut self, pcm: Vec<i16>, frame_size: i32) -> Result<Vec<u8>, String> {
        let mut output = vec![0u8; 4000];
        let f32_pcm: Vec<f32> = pcm.iter().map(|&x| x as f32 / 32768.0).collect();

        let len = self
            .inner
            .encode(&f32_pcm, frame_size as usize, &mut output)
            .map_err(|e| format!("{:?}", e))?;
        output.truncate(len);
        Ok(output)
    }

    #[frb(sync)]
    pub fn set_bitrate(&mut self, bitrate_bps: i32) {
        self.inner.bitrate_bps = bitrate_bps;
    }
}

pub struct RustOpusDecoder {
    inner: OpusDecoder,
    channels: i32,
}

impl RustOpusDecoder {
    #[frb(sync)]
    pub fn new(sample_rate: i32, channels: i32) -> Result<Self, String> {
        let decoder = OpusDecoder::new(sample_rate, channels as usize).map_err(|e| format!("{:?}", e))?;
        Ok(Self {
            inner: decoder,
            channels,
        })
    }

    #[frb(sync)]
    pub fn decode(&mut self, opus_data: Vec<u8>, frame_size: i32) -> Result<Vec<i16>, String> {
        let mut output_f32 = vec![0.0f32; (frame_size * self.channels) as usize];
        let _samples = self
            .inner
            .decode(&opus_data, frame_size as usize, &mut output_f32)
            .map_err(|e| format!("{:?}", e))?;

        let i16_pcm: Vec<i16> = output_f32
            .iter()
            .map(|&x| (x * 32767.0).clamp(-32768.0, 32767.0) as i16)
            .collect();
        Ok(i16_pcm)
    }
}
