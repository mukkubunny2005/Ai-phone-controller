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
                    "readVisibleElements" -> {
                        val elements = AiAccessibilityService.readVisibleElements()
                        if (elements == null) result.error("SERVICE_OFF", "Enable the AI Phone Controller accessibility service first.", null)
                        else result.success(elements)
                    }
                    "clickElement" -> {
                        val index = call.argument<Int>("index")
                        if (index == null || index < 0) result.error("BAD_INDEX", "A valid element index is required.", null)
                        else {
                            val clicked = AiAccessibilityService.click(index)
                            if (clicked == null) result.error("SERVICE_OFF", "Enable the accessibility service first.", null)
                            else result.success(clicked)
                        }
                    }
                    "enterText" -> {
                        val index = call.argument<Int>("index")
                        val value = call.argument<String>("text")
                        if (index == null || index < 0 || value == null || value.length > 2000) {
                            result.error("BAD_INPUT", "A valid element index and text up to 2000 characters are required.", null)
                        } else {
                            val entered = AiAccessibilityService.setText(index, value)
                            if (entered == null) result.error("SERVICE_OFF", "Enable the accessibility service first.", null)
                            else result.success(entered)
                        }
                    }
                    "goBack" -> {
                        val backed = AiAccessibilityService.goBack()
                        if (backed == null) result.error("SERVICE_OFF", "Enable the accessibility service first.", null)
                        else result.success(backed)
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