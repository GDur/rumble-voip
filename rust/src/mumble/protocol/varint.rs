use byteorder::{ReadBytesExt, WriteBytesExt};
use std::io::{self, Read, Write};

pub fn read_varint<R: Read>(reader: &mut R) -> io::Result<u64> {
    let b0 = reader.read_u8()?;
    if b0 & 0b1111_1100 == 0b1111_1000 {
        return Ok(!read_varint(reader)?);
    }
    if b0 & 0b1111_1100 == 0b1111_1100 {
        return Ok(!u64::from(b0 & 0x03));
    }
    if (b0 & 0b1000_0000) == 0 {
        return Ok(u64::from(b0 & 0b0111_1111));
    }
    let b1 = reader.read_u8()?;
    if (b0 & 0b0100_0000) == 0 {
        return Ok(u64::from(b0 & 0b0011_1111) << 8 | u64::from(b1));
    }
    let b2 = reader.read_u8()?;
    if (b0 & 0b0010_0000) == 0 {
        return Ok(u64::from(b0 & 0b0001_1111) << 16 | u64::from(b1) << 8 | u64::from(b2));
    }
    let b3 = reader.read_u8()?;
    if (b0 & 0b0001_0000) == 0 {
        return Ok(u64::from(b0 & 0x0F) << 24
            | u64::from(b1) << 16
            | u64::from(b2) << 8
            | u64::from(b3));
    }
    let b4 = reader.read_u8()?;
    if (b0 & 0b0000_0100) == 0 {
        return Ok(u64::from(b1) << 24 | u64::from(b2) << 16 | u64::from(b3) << 8 | u64::from(b4));
    }
    let b5 = reader.read_u8()?;
    let b6 = reader.read_u8()?;
    let b7 = reader.read_u8()?;
    let b8 = reader.read_u8()?;
    Ok(u64::from(b1) << 56
        | u64::from(b2) << 48
        | u64::from(b3) << 40
        | u64::from(b4) << 32
        | u64::from(b5) << 24
        | u64::from(b6) << 16
        | u64::from(b7) << 8
        | u64::from(b8))
}

pub fn write_varint<W: Write>(writer: &mut W, value: u64) -> io::Result<usize> {
    if value & 0xffff_ffff_ffff_fffc == 0xffff_ffff_ffff_fffc {
        writer.write_u8(0b1111_1100 | (!value as u8))?;
        return Ok(1);
    }
    if value & 0x8000_0000_0000_0000 == 0x8000_0000_0000_0000 {
        writer.write_u8(0b1111_1000)?;
        return Ok(1 + write_varint(writer, !value)?);
    }

    if value > 0xffff_ffff {
        writer.write_u8(0b1111_0100)?;
        writer.write_u8((value >> 56) as u8)?;
        writer.write_u8((value >> 48) as u8)?;
        writer.write_u8((value >> 40) as u8)?;
        writer.write_u8((value >> 32) as u8)?;
        writer.write_u8((value >> 24) as u8)?;
        writer.write_u8((value >> 16) as u8)?;
        writer.write_u8((value >> 8) as u8)?;
        writer.write_u8(value as u8)?;
        return Ok(9);
    }

    if value > 0x0fff_ffff {
        writer.write_u8(0b1111_0000)?;
        writer.write_u8((value >> 24) as u8)?;
        writer.write_u8((value >> 16) as u8)?;
        writer.write_u8((value >> 8) as u8)?;
        writer.write_u8(value as u8)?;
        return Ok(5);
    }

    if value > 0x001f_ffff {
        writer.write_u8(0b1110_0000 | (value >> 24) as u8)?;
        writer.write_u8((value >> 16) as u8)?;
        writer.write_u8((value >> 8) as u8)?;
        writer.write_u8(value as u8)?;
        return Ok(4);
    }

    if value > 0x0000_3fff {
        writer.write_u8(0b1100_0000 | (value >> 16) as u8)?;
        writer.write_u8((value >> 8) as u8)?;
        writer.write_u8(value as u8)?;
        return Ok(3);
    }

    if value > 0x0000_007f {
        writer.write_u8(0b1000_0000 | (value >> 8) as u8)?;
        writer.write_u8(value as u8)?;
        return Ok(2);
    }

    writer.write_u8(value as u8)?;
    Ok(1)
}
