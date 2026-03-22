use crate::api::opus::{RustOpusEncoder, RustOpusDecoder};

#[no_mangle]
pub unsafe extern "C" fn rust_opus_encoder_encode(
    encoder: *mut RustOpusEncoder,
    pcm_ptr: *const i16,
    pcm_len: i32,
    output_ptr: *mut u8,
    output_capacity: i32,
) -> i32 {
    let encoder = &mut *encoder;
    let pcm = std::slice::from_raw_parts(pcm_ptr, pcm_len as usize);
    let output = std::slice::from_raw_parts_mut(output_ptr, output_capacity as usize);

    encoder.f32_buf.clear();
    for &x in pcm.iter() {
        encoder.f32_buf.push(x as f32 / 32768.0);
    }

    let frame_size = pcm_len / encoder.channels;

    match encoder.inner.encode(&encoder.f32_buf, frame_size as usize, output) {
        Ok(len) => len as i32,
        Err(_) => -1,
    }
}

#[no_mangle]
pub unsafe extern "C" fn rust_opus_decoder_decode(
    decoder: *mut RustOpusDecoder,
    opus_ptr: *const u8,
    opus_len: i32,
    output_ptr: *mut i16,
    frame_size: i32,
) -> i32 {
    let decoder = &mut *decoder;
    let opus_data = std::slice::from_raw_parts(opus_ptr, opus_len as usize);
    let output = std::slice::from_raw_parts_mut(output_ptr, (frame_size * decoder.channels) as usize);

    match decoder.inner.decode(opus_data, frame_size as usize, &mut decoder.output_f32) {
        Ok(samples) => {
            for i in 0..(samples * decoder.channels as usize) {
                output[i] = (decoder.output_f32[i] * 32767.0).clamp(-32768.0, 32767.0) as i16;
            }
            samples as i32
        }
        Err(_) => -1,
    }
}
