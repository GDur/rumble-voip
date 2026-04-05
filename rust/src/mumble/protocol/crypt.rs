use aes::cipher::{BlockDecrypt, BlockEncrypt, KeyInit};
use aes::{Aes128, Block};
use rand::RngExt;

pub const KEY_SIZE: usize = 16;
pub const BLOCK_SIZE: usize = 16;

pub struct CryptState {
    key: [u8; KEY_SIZE],
    encrypt_nonce: u128,
    decrypt_nonce: u128,
    decrypt_history: [u8; 0x100],

    good: u32,
    late: u32,
    lost: u32,

    aes: Aes128,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DecryptError {
    Eof,
    Repeat,
    Late,
    Mac,
}

impl CryptState {
    pub fn new(
        key: [u8; KEY_SIZE],
        encrypt_nonce: [u8; BLOCK_SIZE],
        decrypt_nonce: [u8; BLOCK_SIZE],
    ) -> Self {
        let aes = Aes128::new(&key.into());
        Self {
            key,
            encrypt_nonce: u128::from_le_bytes(encrypt_nonce),
            decrypt_nonce: u128::from_le_bytes(decrypt_nonce),
            decrypt_history: [0; 0x100],
            good: 0,
            late: 0,
            lost: 0,
            aes,
        }
    }

    pub fn generate() -> Self {
        let mut key = [0u8; KEY_SIZE];
        rand::rng().fill(&mut key);
        Self::new(key, [0; BLOCK_SIZE], (1u128 << 127).to_le_bytes())
    }

    pub fn get_key(&self) -> &[u8; KEY_SIZE] {
        &self.key
    }

    pub fn get_encrypt_nonce(&self) -> [u8; BLOCK_SIZE] {
        self.encrypt_nonce.to_le_bytes()
    }

    pub fn get_decrypt_nonce(&self) -> [u8; BLOCK_SIZE] {
        self.decrypt_nonce.to_le_bytes()
    }

    pub fn set_decrypt_nonce(&mut self, nonce: [u8; BLOCK_SIZE]) {
        self.decrypt_nonce = u128::from_le_bytes(nonce);
    }

    pub fn encrypt(&mut self, buf: &mut [u8], len: usize) -> [u8; 4] {
        self.encrypt_nonce = self.encrypt_nonce.wrapping_add(1);
        let tag = self.ocb_encrypt(&mut buf[..len]);
        let mut header = [0u8; 4];
        header[0] = self.encrypt_nonce as u8;
        header[1..4].copy_from_slice(&tag.to_be_bytes()[0..3]);
        header
    }

    pub fn decrypt(&mut self, header: [u8; 4], buf: &mut [u8]) -> Result<(), DecryptError> {
        let nonce_0 = header[0];
        let saved_nonce = self.decrypt_nonce;
        let mut late = false;
        let mut lost = 0i32;

        if (self.decrypt_nonce.wrapping_add(1) as u8) == nonce_0 {
            self.decrypt_nonce = self.decrypt_nonce.wrapping_add(1);
        } else {
            let diff = (nonce_0.wrapping_sub(self.decrypt_nonce as u8)) as i8;
            self.decrypt_nonce = self.decrypt_nonce.wrapping_add(diff as u128);
            if diff > 0 {
                lost = (diff - 1) as i32;
            } else if diff > -30 {
                if self.decrypt_history[nonce_0 as usize] == (self.decrypt_nonce >> 8) as u8 {
                    self.decrypt_nonce = saved_nonce;
                    return Err(DecryptError::Repeat);
                }
                late = true;
                lost = -1;
            } else {
                return Err(DecryptError::Late);
            }
        }

        let tag = self.ocb_decrypt(buf);
        if tag.to_be_bytes()[0..3] != header[1..4] {
            self.decrypt_nonce = saved_nonce;
            return Err(DecryptError::Mac);
        }

        self.decrypt_history[nonce_0 as usize] = (self.decrypt_nonce >> 8) as u8;
        self.good += 1;
        if late {
            self.late += 1;
            self.decrypt_nonce = saved_nonce;
        }
        self.lost = (self.lost as i32 + lost) as u32;

        Ok(())
    }

    fn aes_encrypt(&self, block: u128) -> u128 {
        let mut b = Block::from(block.to_be_bytes());
        self.aes.encrypt_block(&mut b);
        u128::from_be_bytes(b.into())
    }

    fn aes_decrypt(&self, block: u128) -> u128 {
        let mut b = Block::from(block.to_be_bytes());
        self.aes.decrypt_block(&mut b);
        u128::from_be_bytes(b.into())
    }

    fn ocb_encrypt(&self, mut buf: &mut [u8]) -> u128 {
        let mut offset = self.aes_encrypt(self.encrypt_nonce.to_be());
        let mut checksum = 0u128;

        while buf.len() > BLOCK_SIZE {
            let (chunk, remainder) = buf.split_at_mut(BLOCK_SIZE);
            buf = remainder;
            let chunk: &mut [u8; BLOCK_SIZE] = chunk.try_into().unwrap();

            offset = s2(offset);

            let plain = u128::from_be_bytes(*chunk);
            let encrypted = self.aes_encrypt(offset ^ plain) ^ offset;
            chunk.copy_from_slice(&encrypted.to_be_bytes());

            checksum ^= plain;
        }

        offset = s2(offset);

        let len = buf.len();
        let pad = self.aes_encrypt((len as u128 * 8) ^ offset);
        let mut block = pad.to_be_bytes();
        block[..len].copy_from_slice(buf);
        let plain = u128::from_be_bytes(block);
        let encrypted = pad ^ plain;
        buf.copy_from_slice(&encrypted.to_be_bytes()[..len]);

        checksum ^= plain;

        self.aes_encrypt(offset ^ s2(offset) ^ checksum)
    }

    fn ocb_decrypt(&self, mut buf: &mut [u8]) -> u128 {
        let mut offset = self.aes_encrypt(self.decrypt_nonce.to_be());
        let mut checksum = 0u128;

        while buf.len() > BLOCK_SIZE {
            let (chunk, remainder) = buf.split_at_mut(BLOCK_SIZE);
            buf = remainder;
            let chunk: &mut [u8; BLOCK_SIZE] = chunk.try_into().unwrap();

            offset = s2(offset);

            let encrypted = u128::from_be_bytes(*chunk);
            let plain = self.aes_decrypt(offset ^ encrypted) ^ offset;
            chunk.copy_from_slice(&plain.to_be_bytes());

            checksum ^= plain;
        }

        offset = s2(offset);

        let len = buf.len();
        let pad = self.aes_encrypt((len as u128 * 8) ^ offset);
        let mut block = [0u8; BLOCK_SIZE];
        block[..len].copy_from_slice(buf);
        let plain = u128::from_be_bytes(block) ^ pad;
        buf.copy_from_slice(&plain.to_be_bytes()[..len]);

        checksum ^= plain;

        self.aes_encrypt(offset ^ s2(offset) ^ checksum)
    }

    pub fn stats(&self) -> (u32, u32, u32) {
        (self.good, self.late, self.lost)
    }
}

fn s2(block: u128) -> u128 {
    let rot = block.rotate_left(1);
    let carry = rot & 1;
    rot ^ (carry * 0x86)
}
