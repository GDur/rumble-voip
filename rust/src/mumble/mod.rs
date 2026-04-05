pub mod codec;
pub mod config;
pub mod dsp;
pub mod hardware;
pub mod net;
pub mod protocol;

use crate::mumble::config::MumbleConfig;

pub enum MumbleCommand {
    Disconnect,
    SetPtt(bool),
    SetUserVolume(u32, f32),
    SetOutputVolume(f32),
    SetInputGain(f32),
    UpdateConfig(MumbleConfig),
}
