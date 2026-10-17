package com.example.amble

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Opens Amble's page in the system settings, for the Dart side's
 * `SystemSettingsService` (channel `com.amble/system_settings`). Calendar
 * permission is switched there once Android has stopped asking.
 */
class SystemSettingsChannel(private val activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "com.amble/system_settings").setMethodCallHandler { call, result ->
            when (call.method) {
                "openCalendarSettings" -> result.success(openAppSettings())
                else -> result.notImplemented()
            }
        }
    }

    private fun openAppSettings(): Boolean {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null)
        )
        return try {
            activity.startActivity(intent)
            true
        } catch (_: android.content.ActivityNotFoundException) {
            false
        }
    }
}
