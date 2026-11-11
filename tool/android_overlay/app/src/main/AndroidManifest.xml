package com.example.aiphonecontroller

import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.aiphonecontroller/accessibility"
    private val allowedPackages = setOf("com.android.chrome", "com.google.android.youtube", "com.android.settings", "com.google.android.apps.maps", "com.google.android.calculator")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAccessibilityStatus" -> result.success(if (isAccessibilityServiceEnabled()) "enabled" else "disabled")
                "openAccessibilitySettings" -> { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)); result.success(true) }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName == null || packageName !in allowedPackages) result.error("NOT_ALLOWED", "This app is not in the launch allow-list.", null)
                    else {
                        val intent = packageManager.getLaunchIntentForPackage(packageName)
                        if (intent == null) result.success(false) else { intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); startActivity(intent); result.success(true) }
                    }
                }
                "readVisibleElements" -> {
                    val service = AiAccessibilityService.instance
                    if (service == null) result.error("SERVICE_DISABLED", "Enable the AI Phone Controller accessibility service first.", null)
                    else result.success(service.readVisibleElements())
                }
                "clickElement" -> {
                    val index = call.argument<Int>("index")
                    val service = AiAccessibilityService.instance
                    if (index == null || index < 0) result.error("BAD_INDEX", "Invalid element index.", null)
                    else if (service == null) result.error("SERVICE_DISABLED", "Enable accessibility service first.", null)
                    else result.success(service.clickElement(index))
                }
                "enterText" -> {
                    val index = call.argument<Int>("index")
                    val value = call.argument<String>("text")
                    val service = AiAccessibilityService.instance
                    if (index == null || index < 0 || value == null || value.length > 2000) result.error("BAD_INPUT", "Invalid field or text too long.", null)
                    else if (service == null) result.error("SERVICE_DISABLED", "Enable accessibility service first.", null)
                    else result.success(service.enterText(index, value))
                }
                "goBack" -> result.success(AiAccessibilityService.instance?.goBack() == true)
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = "$packageName/${AiAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        return splitter.any { it.equals(expected, ignoreCase = true) }
    }
}