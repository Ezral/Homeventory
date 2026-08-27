package com.homeventory.homeventory

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL,
            )
        channel.setMethodCallHandler { call, result ->
            ReminderNotifications.handle(this, call, result)
        }
        ReminderNotifications.attachChannel(channel)
        ReminderNotifications.onLaunchIntent(this, intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        ReminderNotifications.onLaunchIntent(this, intent)
    }

    companion object {
        private const val CHANNEL = "com.homeventory.homeventory/reminder_notifications"
    }
}
