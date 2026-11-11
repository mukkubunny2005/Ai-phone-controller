package com.example.aiphonecontroller

import android.accessibilityservice.AccessibilityService
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class AiAccessibilityService : AccessibilityService() {
    private val visiblePaths = mutableListOf<List<Int>>()
    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit
    override fun onInterrupt() { Log.i(TAG, "Accessibility service interrupted") }

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
    override fun onDestroy() { instance = null; super.onDestroy() }
}