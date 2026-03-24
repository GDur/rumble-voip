pub mod api;
pub mod mumble;
mod frb_generated;

#[cfg(target_os = "android")]
mod init_android_context {
    use jni::{objects::Global, objects::JClass, objects::JObject, EnvUnowned};
    use std::ffi::c_void;
    use std::sync::OnceLock;

    static CTX: OnceLock<Global<JObject>> = OnceLock::new();

    // On Android many system services are implemented in Java and need the JVM, like the audio system.
    // The NDK requires the vm pointer to work, Dart does not initialize it by default.
    // To fix this MainActivity.kt initializes it now and lib.rs passes it to the NDK.
    #[no_mangle]
    pub extern "system" fn Java_com_rumbledev_rumble_MyPlugin_init_1android(
        mut env_unowned: EnvUnowned,
        _class: JClass,
        ctx: JObject,
    ) {
        let _ = env_unowned.with_env(|env| {
            let global_ref = env.new_global_ref(&ctx).expect("to make global reference");
            let vm = env.get_java_vm().unwrap();
            let vm_ptr = vm.get_raw() as *mut c_void;
            unsafe {
                ndk_context::initialize_android_context(vm_ptr, global_ref.as_obj().as_raw() as _);
            }
            
            CTX.get_or_init(|| global_ref);
            Ok::<(), jni::errors::Error>(())
        });
    }
}