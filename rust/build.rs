use std::env;

fn main() {
    let target = env::var("TARGET").unwrap_or_default();

    if target.contains("apple") {
        println!("cargo:rustc-link-lib=framework=CoreAudio");
        println!("cargo:rustc-link-lib=framework=AudioToolbox");
        println!("cargo:rustc-link-lib=framework=CoreFoundation");

        if target.contains("apple-ios") {
            println!("cargo:rustc-link-lib=framework=AVFoundation");
        } else if target.contains("apple-darwin") {
            println!("cargo:rustc-link-lib=framework=AudioUnit");
        }
    }

    if target.contains("android") {
        println!("cargo:rustc-link-lib=aaudio");
    }
}
