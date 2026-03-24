pub mod api;
mod frb_generated;
pub mod mumble;

// On Android many system services are implemented in Java and need the JVM, like the audio system.
// The NDK requires the vm pointer to work, Dart does not initialize it by default.
// To fix this MainActivity.kt initializes it now and lib.rs passes it to the NDK.
#[cfg(target_os = "android")]
mod init_android_context {
    use jni::{objects::GlobalRef, objects::JClass, objects::JObject, JNIEnv};
    use std::ffi::c_void;
    use std::sync::OnceLock;

    static CTX: OnceLock<GlobalRef> = OnceLock::new();

    #[no_mangle]
    pub extern "system" fn Java_com_rumbledev_rumble_MyPlugin_init_1android(
        env: JNIEnv,
        _class: JClass,
        ctx: JObject,
    ) {
        let global_ref = env.new_global_ref(&ctx).expect("to make global reference");
        let vm = env.get_java_vm().unwrap();
        let vm = vm.get_java_vm_pointer() as *mut c_void;
        unsafe {
            ndk_context::initialize_android_context(vm, global_ref.as_obj().as_raw() as _);
        }
        CTX.get_or_init(|| global_ref);
    }
}
