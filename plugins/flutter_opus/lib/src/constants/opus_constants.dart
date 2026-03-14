/// Success code returned by Opus functions.
const int opusOk = 0;

/// Application mode optimized for voice over IP (VoIP).
const int opusApplicationVoip = 2048;

/// Application mode optimized for general audio (e.g., music).
const int opusApplicationAudio = 2049;

/// Request constant to set bitrate in opus_encoder_ctl.
const int opusSetBitrateRequest = 4002;

/// Request constant to set encoder complexity (0–10).
const int opusSetComplexityRequest = 4010;

/// Request constant to enable/disable DTX (discontinuous transmission).
const int opusSetDtxRequest = 4016;
