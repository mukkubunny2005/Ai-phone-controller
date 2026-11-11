package com.example.aiphonecontroller

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.util.Log

/**
 * Minimal opt-in foundation. It only observes foreground window package changes.
 * It does not capture screenshots, read typed content, or perform clicks.
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
