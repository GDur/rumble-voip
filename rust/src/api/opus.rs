use flutter_rust_bridge::frb;
use audiopus::coder::{Encoder as AudiopusEncoder, Decoder as AudiopusDecoder};
use audiopus::{Application, Channels, SampleRate, Bitrate};

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub struct RustOpusEncoder {
    inner: AudiopusEncoder,
    channels: i32,
}

impl RustOpusEncoder {
    #[frb(sync)]
    pub fn new(sample_rate: i32, channels: i32, application: i32) -> Result<Self, String> {
        let app = match application {
            2048 => Application::Voip,
            2049 => Application::Audio,
            2051 => Application::LowDelay,
            _ => Application::Voip,
        };
        let sr = match sample_rate {
            8000 => SampleRate::Hz8000,
            12000 => SampleRate::Hz12000,
            16000 => SampleRate::Hz16000,
            24000 => SampleRate::Hz24000,
            48000 => SampleRate::Hz48000,
            _ => SampleRate::Hz48000,
        };
        let ch = if channels == 2 { Channels::Stereo } else { Channels::Mono };

        let encoder = AudiopusEncoder::new(sr, ch, app)
            .map_err(|e| format!("{:?}", e))?;
        Ok(Self {
            inner: encoder,
            channels,
        })
    }

    #[frb(sync)]
    pub fn encode(&self, pcm: Vec<i16>, frame_size: i32) -> Result<Vec<u8>, String> {
        // Output buffer: max Opus packet is ~4000 bytes
        let mut output = vec![0u8; 4000];
        let len = self
            .inner
            .encode(&pcm[..frame_size as usize * self.channels as usize], &mut output)
            .map_err(|e| format!("{:?}", e))?;
        output.truncate(len);
        Ok(output)
    }

    #[frb(sync)]
    pub fn set_bitrate(&mut self, bitrate_bps: i32) {
        let _ = self.inner.set_bitrate(Bitrate::BitsPerSecond(bitrate_bps));
    }
}

pub struct RustOpusDecoder {
    inner: AudiopusDecoder,
    channels: i32,
}

impl RustOpusDecoder {
    #[frb(sync)]
    pub fn new(sample_rate: i32, channels: i32) -> Result<Self, String> {
        let sr = match sample_rate {
            8000 => SampleRate::Hz8000,
            12000 => SampleRate::Hz12000,
            16000 => SampleRate::Hz16000,
            24000 => SampleRate::Hz24000,
            48000 => SampleRate::Hz48000,
            _ => SampleRate::Hz48000,
        };
        let ch = if channels == 2 { Channels::Stereo } else { Channels::Mono };

        let decoder = AudiopusDecoder::new(sr, ch)
            .map_err(|e| format!("{:?}", e))?;
        Ok(Self {
            inner: decoder,
            channels,
        })
    }

    #[frb(sync)]
    pub fn decode(&mut self, opus_data: Vec<u8>, frame_size: i32) -> Result<Vec<i16>, String> {
        if opus_data.is_empty() {
            return Ok(Vec::new());
        }
        let max_samples = frame_size as usize * self.channels as usize;
        let mut output = vec![0i16; max_samples];
        let samples = self
            .inner
            .decode(Some(&opus_data[..]), &mut output[..], false)
            .map_err(|e| format!("{:?}", e))?;

        // Truncate to actual decoded samples
        output.truncate(samples * self.channels as usize);
        Ok(output)
    }
}
