package com.example.flutter_application_1

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Used by lib/core/background_monitor.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "argus/monitor")
            .setMethodCallHandler { call, result ->
                val intent = Intent(this, MonitorService::class.java)
                when (call.method) {
                    "start" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            // e.g. Android refused to start it from the background.
                            result.error("start_failed", e.message, null)
                        }
                    }
                    "stop" -> {
                        stopService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
