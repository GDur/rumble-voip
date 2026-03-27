package com.rumbledev.rumble

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(
        @NonNull flutterEngine: FlutterEngine,
    ) {
        flutterEngine.plugins.add(MyPlugin())
        super.configureFlutterEngine(flutterEngine)
    }
}

// On Android many system services are implemented in Java and need the JVM, like the audio system.
// The NDK requires the vm pointer to work, Dart does not initialize it by default.
// To fix this MainActivity.kt initializes it now and lib.rs passes it to the NDK.
class MyPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        init {
            System.loadLibrary("rust_lib_rumble")
        }
    }

    external fun init_android(ctx: Context)

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding,
    ) {
        init_android(flutterPluginBinding.applicationContext)
    }

    override fun onMethodCall(
        @NonNull call: MethodCall,
        @NonNull result: Result,
    ) {
        result.notImplemented()
    }

    override fun onDetachedFromEngine(
        @NonNull binding: FlutterPlugin.FlutterPluginBinding,
    ) {
    }
}