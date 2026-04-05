pub mod control;
pub mod crypt;
pub mod varint;
pub mod voice;

pub mod msgs {
    include!(concat!(env!("OUT_DIR"), "/mumble_proto.rs"));
}

pub mod udp_msgs {
    include!(concat!(env!("OUT_DIR"), "/mumble_udp.rs"));
}
