package com.example.aiphonecontroller

import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.aiphonecontroller/accessibility"
    private val allowedPackages = setOf(
        "com.android.chrome",
        "com.google.android.youtube",
        "com.android.settings",
        "com.google.android.apps.maps",
        "com.google.android.calculator"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAccessibilityStatus" -> result.success(
                        if (isAccessibilityServiceEnabled()) "enabled" else "disabled"
                    )
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(true)
                    }
                    "launchApp" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName == null || packageName !in allowedPackages) {
                            result.error("NOT_ALLOWED", "This app is not in the launch allow-list.", null)
                        } else {
                            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                            if (launchIntent == null) {
                                result.success(false)
                            } else {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(launchIntent)
                                result.success(true)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = "$packageName/${AiAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        return splitter.any { it.equals(expected, ignoreCase = true) }
    }
}
