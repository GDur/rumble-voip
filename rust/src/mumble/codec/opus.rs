use opus_head_sys::*;
use std::ptr;

pub struct OpusEncoder(pub *mut opus_head_sys::OpusEncoder);

impl OpusEncoder {
    pub fn new(sample_rate: u32, channels: u32, application: u32) -> anyhow::Result<Self> {
        let mut err = 0;
        let ptr = unsafe {
            opus_encoder_create(
                sample_rate as i32,
                channels as i32,
                application as i32,
                &mut err,
            )
        };
        if err != OPUS_OK as i32 {
            return Err(anyhow::anyhow!("Opus encoder creation error: {}", err));
        }
        Ok(Self(ptr))
    }

    pub fn ctl(&self, request: u32, value: i32) -> i32 {
        unsafe { opus_encoder_ctl(self.0, request as i32, value) }
    }

    pub fn encode(&self, pcm: &[f32], frame_size: usize, data: &mut [u8]) -> anyhow::Result<usize> {
        let ret = unsafe {
            opus_encode_float(
                self.0,
                pcm.as_ptr(),
                frame_size as i32,
                data.as_mut_ptr(),
                data.len() as i32,
            )
        };
        if ret < 0 {
            return Err(anyhow::anyhow!("Opus encode error: {}", ret));
        }
        Ok(ret as usize)
    }

    pub fn reset_state(&mut self) {
        let _ = self.ctl(OPUS_RESET_STATE, 1);
    }
}

impl Drop for OpusEncoder {
    fn drop(&mut self) {
        unsafe { opus_encoder_destroy(self.0) };
    }
}

pub struct OpusDecoder(pub *mut opus_head_sys::OpusDecoder);

impl OpusDecoder {
    pub fn new(sample_rate: u32, channels: u32) -> anyhow::Result<Self> {
        let mut err = 0;
        let ptr = unsafe { opus_decoder_create(sample_rate as i32, channels as i32, &mut err) };
        if err != OPUS_OK as i32 {
            return Err(anyhow::anyhow!("Opus decoder creation error: {}", err));
        }
        Ok(Self(ptr))
    }

    pub fn decode(
        &self,
        data: Option<&[u8]>,
        frame_size: usize,
        pcm: &mut [f32],
    ) -> anyhow::Result<usize> {
        let (ptr, len) = match data {
            Some(d) => (d.as_ptr(), d.len() as i32),
            None => (ptr::null(), 0),
        };
        let ret = unsafe {
            opus_decode_float(
                self.0,
                ptr,
                len,
                pcm.as_mut_ptr(),
                frame_size as i32,
                0, // decode_fec
            )
        };
        if ret < 0 {
            return Err(anyhow::anyhow!("Opus decode error: {}", ret));
        }
        Ok(ret as usize)
    }
}

impl Drop for OpusDecoder {
    fn drop(&mut self) {
        unsafe { opus_decoder_destroy(self.0) };
    }
}
