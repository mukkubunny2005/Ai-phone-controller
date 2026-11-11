package com.example.aiphonecontroller

import android.accessibilityservice.AccessibilityService
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * User-enabled accessibility integration.
 * Reads only visible accessibility nodes; never captures screenshots.
 */
class AiAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "Accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            Log.d(TAG, "Foreground package changed: ${event.packageName ?: "unknown"}")
        }
    }

    override fun onInterrupt() {
        Log.i(TAG, "Accessibility service interrupted")
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun collectNodes(): List<VisibleElement> {
        val result = mutableListOf<VisibleElement>()
        val root = rootInActiveWindow ?: return result
        fun visit(node: AccessibilityNodeInfo, path: String, depth: Int) {
            if (depth > 18 || result.size >= 160) return
            val label = listOfNotNull(
                node.text?.toString()?.takeIf { it.isNotBlank() },
                node.contentDescription?.toString()?.takeIf { it.isNotBlank() }
            ).distinct().joinToString(" — ")
            if (label.isNotBlank() || node.isClickable || node.isEditable) {
                result.add(VisibleElement(
                    path = path,
                    label = label.ifBlank { node.className?.toString() ?: "Element" },
                    clickable = node.isClickable,
                    editable = node.isEditable,
                    className = node.className?.toString() ?: ""
                ))
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                visit(child, if (path.isEmpty()) "$i" else "$path.$i", depth + 1)
                child.recycle()
            }
        }
        visit(root, "", 0)
        root.recycle()
        return result
    }

    private fun nodeAt(path: String): AccessibilityNodeInfo? {
        var node = rootInActiveWindow ?: return null
        if (path.isBlank()) return node
        for (part in path.split(".")) {
            val index = part.toIntOrNull() ?: return null
            val child = node.getChild(index) ?: return null
            node.recycle()
            node = child
        }
        return node
    }

    fun visibleElements(): List<Map<String, Any>> = collectNodes().mapIndexed { index, item ->
        mapOf(
            "index" to index,
            "label" to item.label,
            "clickable" to item.clickable,
            "editable" to item.editable,
            "className" to item.className
        )
    }

    fun clickElement(index: Int): Boolean {
        val item = collectNodes().getOrNull(index) ?: return false
        val node = nodeAt(item.path) ?: return false
        val target = if (node.isClickable) node else node.parent
        val success = target?.performAction(AccessibilityNodeInfo.ACTION_CLICK) == true
        if (target !== node) target?.recycle()
        node.recycle()
        return success
    }

    fun enterText(index: Int, value: String): Boolean {
        if (value.length > 2000) return false
        val item = collectNodes().getOrNull(index) ?: return false
        val node = nodeAt(item.path) ?: return false
        if (!node.isEditable) {
            node.recycle()
            return false
        }
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, value)
        }
        val success = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        node.recycle()
        return success
    }

    data class VisibleElement(
        val path: String,
        val label: String,
        val clickable: Boolean,
        val editable: Boolean,
        val className: String
    )

    companion object {
        private const val TAG = "AiPhoneController"
        @Volatile private var instance: AiAccessibilityService? = null

        fun readVisibleElements(): List<Map<String, Any>>? = instance?.visibleElements()
        fun click(index: Int): Boolean? = instance?.clickElement(index)
        fun setText(index: Int, value: String): Boolean? = instance?.enterText(index, value)
        fun goBack(): Boolean? = instance?.performGlobalAction(GLOBAL_ACTION_BACK)
    }
}
