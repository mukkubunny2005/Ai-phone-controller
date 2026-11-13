package com.example.aiphonecontroller

import android.accessibilityservice.AccessibilityService
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.util.TypedValue
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class AiAccessibilityService : AccessibilityService() {
    private data class VisibleElement(
        val path: List<Int>,
        val label: String,
        val className: String,
        val clickable: Boolean,
        val editable: Boolean
    )
    private val visibleElements = mutableListOf<VisibleElement>()
    private var confirmationView: LinearLayout? = null
    private var confirmationCallback: ((Boolean) -> Unit)? = null

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    // Do not expose or automate fields that commonly contain authentication or payment secrets.
    private fun isSensitiveNode(node: AccessibilityNodeInfo): Boolean {
        if (node.isPassword) return true
        val description = listOfNotNull(
            node.text?.toString(),
            node.contentDescription?.toString(),
            node.hintText?.toString()
        ).joinToString(" ")
        return SENSITIVE_FIELD_PATTERN.containsMatchIn(description)
    }

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
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
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
        // Element indices are valid only for the exact UI snapshot that produced them.
        visibleElements.clear()
    }
    override fun onInterrupt() { dismissConfirmation(false); Log.i(TAG, "Accessibility service interrupted") }

    fun readVisibleElements(): List<Map<String, Any>> {
        visibleElements.clear()
        val root = rootInActiveWindow ?: return emptyList()
        val result = mutableListOf<Map<String, Any>>()
        try {
            collect(root, emptyList(), 0, result)
        } finally {
            root.recycle()
        }
        return result
    }

    private fun collect(node: AccessibilityNodeInfo, path: List<Int>, depth: Int, output: MutableList<Map<String, Any>>) {
        if (depth > 18 || output.size >= 160 || isSensitiveNode(node)) return
        {
            val label = listOfNotNull(node.text?.toString()?.takeIf { it.isNotBlank() }, node.contentDescription?.toString()?.takeIf { it.isNotBlank() }).distinct().joinToString(" ").take(300)
            if (label.isNotBlank() || node.isClickable || node.isEditable) {
                val className = node.className?.toString().orEmpty()
                val visibleLabel = if (label.isBlank()) className else label
                val index = visibleElements.size
                visibleElements.add(VisibleElement(path, visibleLabel, className, node.isClickable, node.isEditable))
                output.add(mapOf("index" to index, "label" to visibleLabel, "clickable" to node.isClickable, "editable" to node.isEditable, "className" to className))
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

    private fun currentLabel(node: AccessibilityNodeInfo): String {
        val parts = listOfNotNull(
            node.text?.toString()?.takeIf { it.isNotBlank() },
            node.contentDescription?.toString()?.takeIf { it.isNotBlank() }
        ).distinct()
        return parts.joinToString(" ").take(300).ifBlank { node.className?.toString().orEmpty() }
    }

    fun clickElement(index: Int, expectedLabel: String, expectedClassName: String): Boolean {
        val snapshot = visibleElements.getOrNull(index) ?: return false
        if (!snapshot.clickable || snapshot.label != expectedLabel || snapshot.className != expectedClassName) return false
        val node = resolve(snapshot.path) ?: return false
        return try {
            !isSensitiveNode(node) && node.isVisibleToUser && node.isClickable &&
                node.className?.toString().orEmpty() == expectedClassName &&
                currentLabel(node) == expectedLabel &&
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        } finally { node.recycle() }
    }

    fun enterText(index: Int, value: String, expectedLabel: String, expectedClassName: String): Boolean {
        if (value.length > 2000) return false
        val snapshot = visibleElements.getOrNull(index) ?: return false
        if (!snapshot.editable || snapshot.label != expectedLabel || snapshot.className != expectedClassName) return false
        val node = resolve(snapshot.path) ?: return false
        return try {
            !isSensitiveNode(node) && node.isVisibleToUser && node.isEditable &&
                node.className?.toString().orEmpty() == expectedClassName &&
                currentLabel(node) == expectedLabel &&
                node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, value)
                })
        } finally { node.recycle() }
    }

    fun goBack(): Boolean = performGlobalAction(GLOBAL_ACTION_BACK)

    companion object {
        private const val TAG = "AiPhoneController"
        private val SENSITIVE_FIELD_PATTERN = Regex(
            """\b(password|passcode|one[- ]time\s*(password|code|pin)?|verification\s*code|security\s*code|otp|pin\s*code|pin|cvv|cvc|card\s*number|credit\s*card|debit\s*card|account\s*number)\b""",
            RegexOption.IGNORE_CASE
        )
        @Volatile var instance: AiAccessibilityService? = null
            private set
    }
    override fun onServiceConnected() { super.onServiceConnected(); instance = this }
    override fun onDestroy() { dismissConfirmation(false); instance = null; super.onDestroy() }
}