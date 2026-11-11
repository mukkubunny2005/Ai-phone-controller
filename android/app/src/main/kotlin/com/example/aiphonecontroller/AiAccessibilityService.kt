package com.example.aiphonecontroller

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.util.Log

/**
 * Opt-in foundation: observes foreground window package changes only.
 * No screenshots, text extraction, credential collection, or automated clicks.
 */
class AiAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            Log.d(TAG, "Foreground package changed: ${event.packageName ?: "unknown"}")
        }
    }

    override fun onInterrupt() {
        Log.i(TAG, "Accessibility service interrupted")
    }

    companion object {
        private const val TAG = "AiPhoneController"
    }
}