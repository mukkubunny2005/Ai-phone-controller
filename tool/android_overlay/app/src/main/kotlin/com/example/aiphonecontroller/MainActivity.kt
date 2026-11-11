package com.example.aiphonecontroller

import android.app.DownloadManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.aiphonecontroller/accessibility"
    private val modelFileName = "Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm"
    private val modelUrl = "https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm?download=true"
    private val modelPreferences by lazy { getSharedPreferences("offline_ai_model", MODE_PRIVATE) }
    private var offlineAiRuntime: OfflineAiRuntime? = null

    private fun modelFile(): File {
        val directory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
        return File(directory, modelFileName)
    }

    private fun downloadManager() = getSystemService(DOWNLOAD_SERVICE) as DownloadManager

    private fun aiModelStatus(): Map<String, Any> {
        val file = modelFile()
        val id = modelPreferences.getLong("download_id", -1L)
        var state = "idle"
        var downloaded = 0L
        var total = 0L
        if (id > 0L) {
            val cursor = downloadManager().query(DownloadManager.Query().setFilterById(id))
            cursor?.use {
                if (it.moveToFirst()) {
                    downloaded = it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                    total = it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                    state = when (it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))) {
                        DownloadManager.STATUS_PENDING -> "pending"
                        DownloadManager.STATUS_RUNNING -> "downloading"
                        DownloadManager.STATUS_PAUSED -> "paused"
                        DownloadManager.STATUS_SUCCESSFUL -> "downloaded"
                        DownloadManager.STATUS_FAILED -> "failed"
                        else -> "unknown"
                    }
                }
            }
        }
        val complete = file.isFile && file.length() > 1_300_000_000L && (state == "downloaded" || state == "unknown" || id <= 0L)
        return mapOf(
            "downloaded" to complete,
            "loaded" to (offlineAiRuntime?.isReady() == true),
            "downloadState" to if (complete) "downloaded" else state,
            "bytesDownloaded" to downloaded,
            "totalBytes" to total,
            "fileBytes" to if (file.exists()) file.length() else 0L,
            "modelSizeLabel" to "about 1.6 GB"
        )
    }

    private fun startAiModelDownload(): Long {
        val file = modelFile()
        if (aiModelStatus()["downloaded"] == true) return -1L
        file.delete()
        val request = DownloadManager.Request(Uri.parse(modelUrl))
            .setTitle("AI Phone Controller offline model")
            .setDescription("Downloading Qwen2.5 1.5B (about 1.6 GB). Wi-Fi only.")
            .setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, modelFileName)
        val id = downloadManager().enqueue(request)
        modelPreferences.edit().putLong("download_id", id).apply()
        return id
    }

    private fun cancelAiModelDownload(): Boolean {
        val id = modelPreferences.getLong("download_id", -1L)
        if (id > 0L) downloadManager().remove(id)
        modelPreferences.edit().remove("download_id").apply()
        modelFile().delete()
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "confirmAction" -> {
                    val message = call.argument<String>("message")?.take(500)
                    val service = AiAccessibilityService.instance
                    if (message.isNullOrBlank()) result.error("BAD_CONFIRMATION", "Confirmation message is required.", null)
                    else if (service == null) result.error("SERVICE_DISABLED", "Enable the accessibility service to confirm actions over other apps.", null)
                    else service.requestConfirmation(message) { approved -> result.success(approved) }
                }
                "getAccessibilityStatus" -> result.success(if (isAccessibilityServiceEnabled()) "enabled" else "disabled")
                "getAiModelStatus" -> result.success(aiModelStatus())
                "getAiModelDownloadStatus" -> result.success(aiModelStatus())
                "downloadAiModel" -> {
                    try { result.success(startAiModelDownload()) }
                    catch (error: Exception) { result.error("MODEL_DOWNLOAD_FAILED", error.message, null) }
                }
                "cancelAiModelDownload" -> result.success(cancelAiModelDownload())
                "loadAiModel" -> {
                    if (aiModelStatus()["downloaded"] != true) {
                        result.error("MODEL_NOT_DOWNLOADED", "Download the offline model first.", null)
                    } else {
                        val runtime = offlineAiRuntime ?: OfflineAiRuntime(modelFile()).also { offlineAiRuntime = it }
                        runtime.load { success, error ->
                            runOnUiThread {
                                if (success) result.success(true)
                                else result.error("MODEL_LOAD_FAILED", error, null)
                            }
                        }
                    }
                }
                "generateAiResponse" -> {
                    val prompt = call.argument<String>("prompt")
                    if (prompt.isNullOrBlank() || prompt.length > 10000) {
                        result.error("BAD_PROMPT", "Prompt must contain 1 to 10000 characters.", null)
                    } else {
                        val runtime = offlineAiRuntime
                        if (runtime == null || !runtime.isReady()) result.error("MODEL_NOT_READY", "Load the offline model first.", null)
                        else runtime.generate(prompt) { response, error ->
                            runOnUiThread {
                                if (response != null) result.success(response)
                                else result.error("AI_GENERATION_FAILED", error, null)
                            }
                        }
                    }
                }
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

    override fun onDestroy() {
        offlineAiRuntime?.close()
        offlineAiRuntime = null
        super.onDestroy()
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
