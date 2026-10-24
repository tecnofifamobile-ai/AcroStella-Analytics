package com.acrostella.acrostella_analytics

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private var studio: MethodChannel? = null
    private var updates: UpdateChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        studio = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "acrostella/studio").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "keepAwake") {
                    if (call.argument<Boolean>("enabled") == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                } else result.notImplemented()
            }
        }
        updates = UpdateChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        studio?.setMethodCallHandler(null)
        studio = null
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        updates?.close()
        updates = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
