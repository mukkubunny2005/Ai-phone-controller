package com.example.aiphonecontroller

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.aiphonecontroller/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAccessibilityStatus" -> result.success(if (isAccessibilityServiceEnabled()) "enabled" else "disabled")
                "openAccessibilitySettings" -> { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)); result.success(true) }
                "getLaunchableApps" -> result.success(getLaunchableApps())
                "launchAppByName" -> {
                    val appName = call.argument<String>("appName")?.trim()
                    if (appName.isNullOrBlank() || appName.length > 100) {
                        result.error("BAD_APP_NAME", "Enter a valid installed app name.", null)
                    } else {
                        val match = findLaunchableApp(appName)
                        if (match == null) result.success(false)
                        else {
                            val launchIntent = packageManager.getLaunchIntentForPackage(match.activityInfo.packageName)
                            if (launchIntent == null) result.success(false)
                            else {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(launchIntent)
                                result.success(true)
                            }
                        }
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName == null || packageName.length > 200) result.error("BAD_PACKAGE", "Invalid package name.", null)
                    else {
                        val intent = packageManager.getLaunchIntentForPackage(packageName)
                        if (intent == null) result.success(false)
                        else { intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); startActivity(intent); result.success(true) }
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

    private fun queryLauncherActivities(): List<android.content.pm.ResolveInfo> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, 0)
        }
    }

    private fun getLaunchableApps(): List<Map<String, String>> =
        queryLauncherActivities()
            .filter { it.activityInfo.packageName != packageName }
            .map {
                mapOf(
                    "label" to it.loadLabel(packageManager).toString(),
                    "packageName" to it.activityInfo.packageName
                )
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["label"]?.lowercase() }

    private fun findLaunchableApp(query: String): android.content.pm.ResolveInfo? {
        val apps = queryLauncherActivities().filter { it.activityInfo.packageName != packageName }
        return apps.firstOrNull { it.loadLabel(packageManager).toString().equals(query, ignoreCase = true) }
            ?: apps.firstOrNull { it.loadLabel(packageManager).toString().startsWith(query, ignoreCase = true) }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = "$packageName/${AiAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        return splitter.any { it.equals(expected, ignoreCase = true) }
    }
}
