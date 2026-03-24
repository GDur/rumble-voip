package com.rumbledev.rumble

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    init {
        try {
            System.loadLibrary("rust_lib_rumble")
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private external fun initAndroidContext(context: android.content.Context)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            initAndroidContext(this)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
