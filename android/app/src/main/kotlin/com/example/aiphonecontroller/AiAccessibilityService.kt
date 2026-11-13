package com.example.aiphonecontroller

import android.accessibilityservice.AccessibilityService
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AiAccessibilityService : AccessibilityService() {
    private val visiblePaths = mutableListOf<List<Int>>()
    private var confirmationView: LinearLayout? = null
    private var confirmationCallback: ((Boolean) -> Unit)? = null
    private var protectionWarningView: LinearLayout? = null
    private var lastProtectionCheckAt = 0L
    private var lastWarningAt = 0L

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    fun requestConfirmation(message: String, callback: (Boolean) -> Unit) {
        dismissConfirmation(false)
        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(14), dp(16), dp(12))
            background = GradientDrawable().apply {
                setColor(Color.rgb(20, 28, 45))
                cornerRadius = dp(18).toFloat()
                setStroke(dp(1), Color.rgb(116, 132, 240))
            }
            elevation = dp(10).toFloat()
        }
        val title = TextView(this).apply {
            text = "AI Phone Controller · Confirm action"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
        }
        val detail = TextView(this).apply {
            text = message.take(500)
            setTextColor(Color.rgb(224, 229, 242))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(0, dp(8), 0, dp(12))
        }
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }
        val cancel = Button(this).apply {
            text = "Cancel"
            isAllCaps = false
            setOnClickListener { dismissConfirmation(false) }
        }
        val confirm = Button(this).apply {
            text = "Confirm"
            isAllCaps = false
            setOnClickListener { dismissConfirmation(true) }
        }
        actions.addView(cancel)
        actions.addView(confirm)
        panel.addView(title)
        panel.addView(detail)
        panel.addView(actions)

        val params = WindowManager.LayoutParams(
            resources.displayMetrics.widthPixels - dp(28),
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(28)
        }
        try {
            confirmationCallback = callback
            confirmationView = panel
            windowManager.addView(panel, params)
        } catch (error: Exception) {
            confirmationView = null
            confirmationCallback = null
            callback(false)
            Log.e(TAG, "Could not show confirmation overlay", error)
        }
    }

    private fun dismissConfirmation(confirmed: Boolean) {
        val panel = confirmationView
        confirmationView = null
        val callback = confirmationCallback
        confirmationCallback = null
        if (panel != null) {
            try {
                (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(panel)
            } catch (_: Exception) { }
        }
        callback?.invoke(confirmed)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.packageName?.toString() != YOUTUBE_PACKAGE) return
        val now = SystemClock.elapsedRealtime()
        if (now - lastProtectionCheckAt < PROTECTION_CHECK_INTERVAL_MS) return
        lastProtectionCheckAt = now

        val root = rootInActiveWindow ?: return
        val accessibleText = StringBuilder()
        collectProtectionText(root, accessibleText, 0)
        root.recycle()

        if (containsInappropriateSignal(accessibleText.toString()) &&
            now - lastWarningAt >= WARNING_COOLDOWN_MS
        ) {
            lastWarningAt = now
            showProtectionWarning()
            // Stop playback/navigation by leaving YouTube. Android may keep its task in Recents.
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
    }

    private fun collectProtectionText(
        node: AccessibilityNodeInfo,
        output: StringBuilder,
        depth: Int
    ) {
        if (depth > 16 || output.length >= MAX_PROTECTION_TEXT_LENGTH) return
        if (!node.isPassword) {
            node.text?.toString()?.let { if (it.isNotBlank()) output.append(' ').append(it.take(250)) }
            node.contentDescription?.toString()?.let { if (it.isNotBlank()) output.append(' ').append(it.take(250)) }
        }
        for (i in 0 until node.childCount) {
            if (output.length >= MAX_PROTECTION_TEXT_LENGTH) break
            val child = node.getChild(i) ?: continue
            collectProtectionText(child, output, depth + 1)
            child.recycle()
        }
    }

    private fun containsInappropriateSignal(text: String): Boolean {
        if (text.isBlank()) return false
        return INAPPROPRIATE_TEXT_PATTERN.containsMatchIn(text.lowercase())
    }

    private fun showProtectionWarning() {
        if (protectionWarningView != null) return
        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(14))
            background = GradientDrawable().apply {
                setColor(Color.rgb(35, 24, 30))
                cornerRadius = dp(18).toFloat()
                setStroke(dp(2), Color.rgb(235, 112, 112))
            }
            elevation = dp(12).toFloat()
        }
        val title = TextView(this).apply {
            text = "Content protection warning"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
        val detail = TextView(this).apply {
            text = "This content may be inappropriate. Please don't watch it. YouTube has been exited."
            setTextColor(Color.rgb(245, 226, 230))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(0, dp(9), 0, dp(12))
        }
        val dismiss = Button(this).apply {
            text = "OK"
            isAllCaps = false
            setOnClickListener { dismissProtectionWarning() }
        }
        panel.addView(title)
        panel.addView(detail)
        panel.addView(dismiss)
        val params = WindowManager.LayoutParams(
            resources.displayMetrics.widthPixels - dp(28),
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(28)
        }
        try {
            protectionWarningView = panel
            windowManager.addView(panel, params)
        } catch (error: Exception) {
            protectionWarningView = null
            Log.e(TAG, "Could not show content protection warning", error)
        }
    }

    private fun dismissProtectionWarning() {
        val panel = protectionWarningView
        protectionWarningView = null
        if (panel != null) {
            try {
                (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(panel)
            } catch (_: Exception) { }
        }
    }

    override fun onInterrupt() {
        dismissConfirmation(false)
        dismissProtectionWarning()
        Log.i(TAG, "Accessibility service interrupted")
    }

    fun readVisibleElements(): List<Map<String, Any>> {
        val root = rootInActiveWindow ?: return emptyList()
        visiblePaths.clear()
        val result = mutableListOf<Map<String, Any>>()
        collect(root, emptyList(), 0, result)
        root.recycle()
        return result
    }

    private fun collect(node: AccessibilityNodeInfo, path: List<Int>, depth: Int, output: MutableList<Map<String, Any>>) {
        if (depth > 18 || output.size >= 160) return
        if (!node.isPassword) {
            val label = listOfNotNull(node.text?.toString()?.takeIf { it.isNotBlank() }, node.contentDescription?.toString()?.takeIf { it.isNotBlank() }).distinct().joinToString(" ").take(300)
            if (label.isNotBlank() || node.isClickable || node.isEditable) {
                val index = visiblePaths.size
                visiblePaths.add(path)
                output.add(mapOf("index" to index, "label" to if (label.isBlank()) node.className?.toString().orEmpty() else label, "clickable" to node.isClickable, "editable" to node.isEditable, "className" to node.className?.toString().orEmpty()))
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collect(child, path + i, depth + 1, output)
            child.recycle()
            if (output.size >= 160) break
        }
    }

    private fun resolve(path: List<Int>): AccessibilityNodeInfo? {
        var node = rootInActiveWindow ?: return null
        for (index in path) {
            val next = node.getChild(index) ?: run { node.recycle(); return null }
            node.recycle()
            node = next
        }
        return node
    }

    fun clickElement(index: Int): Boolean {
        val path = visiblePaths.getOrNull(index) ?: return false
        var target = resolve(path) ?: return false
        while (!target.isClickable) {
            val parent = target.parent ?: break
            target.recycle()
            target = parent
        }
        val success = target.isClickable && target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        target.recycle()
        return success
    }

    fun enterText(index: Int, value: String): Boolean {
        val node = resolve(visiblePaths.getOrNull(index) ?: return false) ?: return false
        val success = !node.isPassword && node.isEditable && node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, value)
        })
        node.recycle()
        return success
    }

    fun goBack(): Boolean = performGlobalAction(GLOBAL_ACTION_BACK)

    companion object {
        private const val TAG = "AiPhoneController"
        private const val YOUTUBE_PACKAGE = "com.google.android.youtube"
        private const val PROTECTION_CHECK_INTERVAL_MS = 700L
        private const val WARNING_COOLDOWN_MS = 45_000L
        private const val MAX_PROTECTION_TEXT_LENGTH = 12_000
        private val INAPPROPRIATE_TEXT_PATTERN = Regex(
            """(?i)(\\b18\\s*\\+\\b|\\badult\\b|\\bexplicit\\b|\\bsexual\\b|\\bnudity\\b|\\bnude\\b|\\bsuggestive\\b|\\bmature content\\b|అశ్లీల|వయోజన|నగ్న)"""
        )
        @Volatile var instance: AiAccessibilityService? = null
            private set
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "Accessibility service connected; YouTube content protection is active")
    }

    override fun onDestroy() {
        dismissConfirmation(false)
        dismissProtectionWarning()
        instance = null
        super.onDestroy()
    }
}
