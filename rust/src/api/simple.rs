#[flutter_rust_bridge::frb(sync)]
pub fn hello_rust() -> String {
    "Hello from Rust! 🦀".to_string()
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
