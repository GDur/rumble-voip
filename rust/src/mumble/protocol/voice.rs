use crate::mumble::protocol::varint::{read_varint, write_varint};
use byteorder::{ReadBytesExt, WriteBytesExt};
use std::io::{self, Cursor, Read, Write};

#[derive(Debug, Clone, PartialEq)]
pub enum VoicePacket {
    Audio {
        target: u8,
        session_id: Option<u32>, // None for server-bound
        seq_num: u64,
        payload: VoicePacketPayload,
        position_info: Option<Vec<f32>>,
    },
    Ping {
        timestamp: u64,
    },
}

#[derive(Debug, Clone, PartialEq)]
pub enum VoicePacketPayload {
    Opus(Vec<u8>, bool), // data, termination bit
    // Other legacy codecs can be added here if needed, but the app seems to use Opus
    CeltAlpha(Vec<Vec<u8>>),
    CeltBeta(Vec<Vec<u8>>),
    Speex(Vec<Vec<u8>>),
}

impl VoicePacket {
    pub fn decode<R: Read>(reader: &mut R, is_client_bound: bool) -> io::Result<Self> {
        let header = reader.read_u8()?;
        let kind = header >> 5;
        let target = header & 0x1F;

        if kind == 1 {
            let timestamp = read_varint(reader)?;
            return Ok(VoicePacket::Ping { timestamp });
        }

        let session_id = if is_client_bound {
            Some(read_varint(reader)? as u32)
        } else {
            None
        };

        let seq_num = read_varint(reader)?;

        let payload = match kind {
            4 => {
                // Opus
                let len_header = read_varint(reader)?;
                let len = (len_header & !0x2000) as usize;
                let is_terminated = (len_header & 0x2000) != 0;
                let mut data = vec![0u8; len];
                reader.read_exact(&mut data)?;
                VoicePacketPayload::Opus(data, is_terminated)
            }
            0 | 2 | 3 => {
                // CeltAlpha, Speex, CeltBeta
                let mut frames = Vec::new();
                loop {
                    let frame_header = reader.read_u8()?;
                    let len = (frame_header & !0x80) as usize;
                    let mut frame = vec![0u8; len];
                    reader.read_exact(&mut frame)?;
                    frames.push(frame);
                    if (frame_header & 0x80) == 0 {
                        break;
                    }
                }
                match kind {
                    0 => VoicePacketPayload::CeltAlpha(frames),
                    2 => VoicePacketPayload::Speex(frames),
                    3 => VoicePacketPayload::CeltBeta(frames),
                    _ => unreachable!(),
                }
            }
            _ => {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidData,
                    format!("Unknown voice packet kind: {}", kind),
                ))
            }
        };

        // Positional audio (optional, until EOF)
        let mut position_info = None;
        let mut pos_buf = Vec::new();
        reader.read_to_end(&mut pos_buf)?;
        if !pos_buf.is_empty() && pos_buf.len() % 4 == 0 {
            let mut pos_reader = Cursor::new(pos_buf);
            let mut floats = Vec::new();
            while pos_reader.position() < pos_reader.get_ref().len() as u64 {
                floats.push(pos_reader.read_f32::<byteorder::LittleEndian>()?);
            }
            position_info = Some(floats);
        }

        Ok(VoicePacket::Audio {
            target,
            session_id,
            seq_num,
            payload,
            position_info,
        })
    }

    pub fn encode<W: Write>(&self, writer: &mut W, is_client_bound: bool) -> io::Result<()> {
        match self {
            VoicePacket::Ping { timestamp } => {
                writer.write_u8(1 << 5)?;
                write_varint(writer, *timestamp)?;
            }
            VoicePacket::Audio {
                target,
                session_id,
                seq_num,
                payload,
                position_info,
            } => {
                let kind = match payload {
                    VoicePacketPayload::CeltAlpha(_) => 0,
                    VoicePacketPayload::Speex(_) => 2,
                    VoicePacketPayload::CeltBeta(_) => 3,
                    VoicePacketPayload::Opus(_, _) => 4,
                };
                writer.write_u8((kind << 5) | (target & 0x1F))?;

                if is_client_bound {
                    if let Some(sid) = session_id {
                        write_varint(writer, *sid as u64)?;
                    } else {
                        return Err(io::Error::new(
                            io::ErrorKind::InvalidInput,
                            "Session ID required for client-bound audio",
                        ));
                    }
                }

                write_varint(writer, *seq_num)?;

                match payload {
                    VoicePacketPayload::Opus(data, is_terminated) => {
                        let mut len_header = data.len() as u64;
                        if *is_terminated {
                            len_header |= 0x2000;
                        }
                        write_varint(writer, len_header)?;
                        writer.write_all(data)?;
                    }
                    VoicePacketPayload::CeltAlpha(frames)
                    | VoicePacketPayload::CeltBeta(frames)
                    | VoicePacketPayload::Speex(frames) => {
                        for (i, frame) in frames.iter().enumerate() {
                            let mut header = (frame.len() & 0x7F) as u8;
                            if i < frames.len() - 1 {
                                header |= 0x80;
                            }
                            writer.write_u8(header)?;
                            writer.write_all(frame)?;
                        }
                    }
                }

                if let Some(pos) = position_info {
                    for &f in pos {
                        writer.write_f32::<byteorder::LittleEndian>(f)?;
                    }
                }
            }
        }
        Ok(())
    }
}
