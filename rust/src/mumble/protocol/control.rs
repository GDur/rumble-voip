use crate::mumble::protocol::msgs;
use byteorder::{BigEndian, ReadBytesExt, WriteBytesExt};
use prost::Message;
use std::io::{self, Read, Write};

#[derive(Debug, Clone)]
pub enum ControlPacket {
    Version(msgs::Version),
    UdpTunnel(Vec<u8>),
    Authenticate(msgs::Authenticate),
    Ping(msgs::Ping),
    Reject(msgs::Reject),
    ServerSync(msgs::ServerSync),
    ChannelRemove(msgs::ChannelRemove),
    ChannelState(msgs::ChannelState),
    UserRemove(msgs::UserRemove),
    UserState(msgs::UserState),
    BanList(msgs::BanList),
    TextMessage(msgs::TextMessage),
    PermissionDenied(msgs::PermissionDenied),
    Acl(msgs::Acl),
    QueryUsers(msgs::QueryUsers),
    CryptSetup(msgs::CryptSetup),
    ContextActionModify(msgs::ContextActionModify),
    ContextAction(msgs::ContextAction),
    UserList(msgs::UserList),
    VoiceTarget(msgs::VoiceTarget),
    PermissionQuery(msgs::PermissionQuery),
    CodecVersion(msgs::CodecVersion),
    UserStats(msgs::UserStats),
    RequestBlob(msgs::RequestBlob),
    ServerConfig(msgs::ServerConfig),
    SuggestConfig(msgs::SuggestConfig),
    PluginDataTransmission(msgs::PluginDataTransmission),
}

impl ControlPacket {
    pub fn id(&self) -> u16 {
        match self {
            ControlPacket::Version(_) => 0,
            ControlPacket::UdpTunnel(_) => 1,
            ControlPacket::Authenticate(_) => 2,
            ControlPacket::Ping(_) => 3,
            ControlPacket::Reject(_) => 4,
            ControlPacket::ServerSync(_) => 5,
            ControlPacket::ChannelRemove(_) => 6,
            ControlPacket::ChannelState(_) => 7,
            ControlPacket::UserRemove(_) => 8,
            ControlPacket::UserState(_) => 9,
            ControlPacket::BanList(_) => 10,
            ControlPacket::TextMessage(_) => 11,
            ControlPacket::PermissionDenied(_) => 12,
            ControlPacket::Acl(_) => 13,
            ControlPacket::QueryUsers(_) => 14,
            ControlPacket::CryptSetup(_) => 15,
            ControlPacket::ContextActionModify(_) => 16,
            ControlPacket::ContextAction(_) => 17,
            ControlPacket::UserList(_) => 18,
            ControlPacket::VoiceTarget(_) => 19,
            ControlPacket::PermissionQuery(_) => 20,
            ControlPacket::CodecVersion(_) => 21,
            ControlPacket::UserStats(_) => 22,
            ControlPacket::RequestBlob(_) => 23,
            ControlPacket::ServerConfig(_) => 24,
            ControlPacket::SuggestConfig(_) => 25,
            ControlPacket::PluginDataTransmission(_) => 26,
        }
    }

    pub fn decode<R: Read>(reader: &mut R) -> io::Result<Self> {
        let id = reader.read_u16::<BigEndian>()?;
        let len = reader.read_u32::<BigEndian>()? as usize;

        // Safety: limit packet size to 8MB to avoid OOM
        if len > 8 * 1024 * 1024 {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "Packet too large",
            ));
        }

        let mut buf = vec![0u8; len];
        reader.read_exact(&mut buf)?;

        match id {
            0 => Ok(ControlPacket::Version(msgs::Version::decode(&buf[..])?)),
            1 => Ok(ControlPacket::UdpTunnel(buf)),
            2 => Ok(ControlPacket::Authenticate(msgs::Authenticate::decode(
                &buf[..],
            )?)),
            3 => Ok(ControlPacket::Ping(msgs::Ping::decode(&buf[..])?)),
            4 => Ok(ControlPacket::Reject(msgs::Reject::decode(&buf[..])?)),
            5 => Ok(ControlPacket::ServerSync(msgs::ServerSync::decode(
                &buf[..],
            )?)),
            6 => Ok(ControlPacket::ChannelRemove(msgs::ChannelRemove::decode(
                &buf[..],
            )?)),
            7 => Ok(ControlPacket::ChannelState(msgs::ChannelState::decode(
                &buf[..],
            )?)),
            8 => Ok(ControlPacket::UserRemove(msgs::UserRemove::decode(
                &buf[..],
            )?)),
            9 => Ok(ControlPacket::UserState(msgs::UserState::decode(&buf[..])?)),
            10 => Ok(ControlPacket::BanList(msgs::BanList::decode(&buf[..])?)),
            11 => Ok(ControlPacket::TextMessage(msgs::TextMessage::decode(
                &buf[..],
            )?)),
            12 => Ok(ControlPacket::PermissionDenied(
                msgs::PermissionDenied::decode(&buf[..])?,
            )),
            13 => Ok(ControlPacket::Acl(msgs::Acl::decode(&buf[..])?)),
            14 => Ok(ControlPacket::QueryUsers(msgs::QueryUsers::decode(
                &buf[..],
            )?)),
            15 => Ok(ControlPacket::CryptSetup(msgs::CryptSetup::decode(
                &buf[..],
            )?)),
            16 => Ok(ControlPacket::ContextActionModify(
                msgs::ContextActionModify::decode(&buf[..])?,
            )),
            17 => Ok(ControlPacket::ContextAction(msgs::ContextAction::decode(
                &buf[..],
            )?)),
            18 => Ok(ControlPacket::UserList(msgs::UserList::decode(&buf[..])?)),
            19 => Ok(ControlPacket::VoiceTarget(msgs::VoiceTarget::decode(
                &buf[..],
            )?)),
            20 => Ok(ControlPacket::PermissionQuery(
                msgs::PermissionQuery::decode(&buf[..])?,
            )),
            21 => Ok(ControlPacket::CodecVersion(msgs::CodecVersion::decode(
                &buf[..],
            )?)),
            22 => Ok(ControlPacket::UserStats(msgs::UserStats::decode(&buf[..])?)),
            23 => Ok(ControlPacket::RequestBlob(msgs::RequestBlob::decode(
                &buf[..],
            )?)),
            24 => Ok(ControlPacket::ServerConfig(msgs::ServerConfig::decode(
                &buf[..],
            )?)),
            25 => Ok(ControlPacket::SuggestConfig(msgs::SuggestConfig::decode(
                &buf[..],
            )?)),
            26 => Ok(ControlPacket::PluginDataTransmission(
                msgs::PluginDataTransmission::decode(&buf[..])?,
            )),
            _ => Err(io::Error::new(
                io::ErrorKind::InvalidData,
                format!("Unknown packet ID: {}", id),
            )),
        }
    }

    pub fn encode<W: Write>(&self, writer: &mut W) -> io::Result<()> {
        let id = self.id();
        let mut buf = Vec::new();
        match self {
            ControlPacket::Version(m) => m.encode(&mut buf)?,
            ControlPacket::UdpTunnel(b) => buf.extend_from_slice(b),
            ControlPacket::Authenticate(m) => m.encode(&mut buf)?,
            ControlPacket::Ping(m) => m.encode(&mut buf)?,
            ControlPacket::Reject(m) => m.encode(&mut buf)?,
            ControlPacket::ServerSync(m) => m.encode(&mut buf)?,
            ControlPacket::ChannelRemove(m) => m.encode(&mut buf)?,
            ControlPacket::ChannelState(m) => m.encode(&mut buf)?,
            ControlPacket::UserRemove(m) => m.encode(&mut buf)?,
            ControlPacket::UserState(m) => m.encode(&mut buf)?,
            ControlPacket::BanList(m) => m.encode(&mut buf)?,
            ControlPacket::TextMessage(m) => m.encode(&mut buf)?,
            ControlPacket::PermissionDenied(m) => m.encode(&mut buf)?,
            ControlPacket::Acl(m) => m.encode(&mut buf)?,
            ControlPacket::QueryUsers(m) => m.encode(&mut buf)?,
            ControlPacket::CryptSetup(m) => m.encode(&mut buf)?,
            ControlPacket::ContextActionModify(m) => m.encode(&mut buf)?,
            ControlPacket::ContextAction(m) => m.encode(&mut buf)?,
            ControlPacket::UserList(m) => m.encode(&mut buf)?,
            ControlPacket::VoiceTarget(m) => m.encode(&mut buf)?,
            ControlPacket::PermissionQuery(m) => m.encode(&mut buf)?,
            ControlPacket::CodecVersion(m) => m.encode(&mut buf)?,
            ControlPacket::UserStats(m) => m.encode(&mut buf)?,
            ControlPacket::RequestBlob(m) => m.encode(&mut buf)?,
            ControlPacket::ServerConfig(m) => m.encode(&mut buf)?,
            ControlPacket::SuggestConfig(m) => m.encode(&mut buf)?,
            ControlPacket::PluginDataTransmission(m) => m.encode(&mut buf)?,
        }

        writer.write_u16::<BigEndian>(id)?;
        writer.write_u32::<BigEndian>(buf.len() as u32)?;
        writer.write_all(&buf)?;
        Ok(())
    }
}
