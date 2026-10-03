package com.tam.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onStart() {
        super.onStart()
        // Screen recording protection
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
