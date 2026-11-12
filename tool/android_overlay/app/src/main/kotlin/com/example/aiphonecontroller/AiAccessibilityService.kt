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
    private val visiblePaths = mutableListOf<List<Int>>()
    private var confirmationView: LinearLayout? = null
    private var confirmationCallback: ((Boolean) -> Unit)? = null

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
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {\n        // Element indices are valid only for the exact UI snapshot that produced them.\n        visiblePaths.clear()\n    }
    override fun onInterrupt() { dismissConfirmation(false); Log.i(TAG, "Accessibility service interrupted") }

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
        @Volatile var instance: AiAccessibilityService? = null
            private set
    }
    override fun onServiceConnected() { super.onServiceConnected(); instance = this }
    override fun onDestroy() { dismissConfirmation(false); instance = null; super.onDestroy() }
}