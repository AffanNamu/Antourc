package com.assistlink.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.app.KeyguardManager
import android.graphics.Path
import android.os.PowerManager
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent

/**
 * Narrow gesture executor for an explicitly approved, time-limited live support session.
 * It does not read window text, inspect view hierarchies, capture credentials, or execute scripts.
 */
class AssistLinkAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile
        var activeService: AssistLinkAccessibilityService? = null
            private set

        private const val PREFS = "assistlink_control_grant"
        private const val KEY_SESSION = "session_id"
        private const val KEY_HELPER = "helper_identity"
        private const val KEY_EXPIRY = "expires_at"
        private const val KEY_CAPABILITIES = "capabilities"
        private const val KEY_SEQUENCE = "last_sequence"

        fun clearGrant(context: android.content.Context) {
            context.getSharedPreferences(PREFS, android.content.Context.MODE_PRIVATE)
                .edit().clear().commit()
        }

        fun saveGrant(
            context: android.content.Context,
            sessionId: String,
            helperIdentity: String,
            expiresAt: Long,
            capabilities: Set<String>,
        ) {
            context.getSharedPreferences(PREFS, android.content.Context.MODE_PRIVATE).edit()
                .putString(KEY_SESSION, sessionId)
                .putString(KEY_HELPER, helperIdentity)
                .putLong(KEY_EXPIRY, expiresAt)
                .putStringSet(KEY_CAPABILITIES, capabilities)
                .putLong(KEY_SEQUENCE, 0L)
                .commit()
        }

        fun hasGrant(context: android.content.Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS, android.content.Context.MODE_PRIVATE)
            return !prefs.getString(KEY_SESSION, null).isNullOrBlank() &&
                prefs.getLong(KEY_EXPIRY, 0L) > System.currentTimeMillis()
        }
    }

    @Volatile
    private var blockedForeground = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        activeService = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString().orEmpty()
        val protectedSystemPackage =
            packageName == "com.android.systemui" ||
            packageName == "com.android.settings" ||
            packageName == "com.android.permissioncontroller" ||
            packageName == "com.google.android.permissioncontroller" ||
            packageName == "com.android.packageinstaller" ||
            packageName == "com.google.android.packageinstaller"
        blockedForeground = protectedSystemPackage || event.isPassword
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        if (activeService === this) activeService = null
        clearGrant(this)
        super.onDestroy()
    }

    fun dispatchTap(
        sessionId: String,
        senderIdentity: String,
        sequence: Long,
        normalizedX: Double,
        normalizedY: Double,
    ): Boolean {
        if (!validateCommand(sessionId, senderIdentity, sequence, "tap")) return false
        if (normalizedX !in 0.0..1.0 || normalizedY !in 0.0..1.0) return false
        val metrics = displayMetrics() ?: return false
        val x = (normalizedX * (metrics.widthPixels - 1)).toFloat()
        val y = (normalizedY * (metrics.heightPixels - 1)).toFloat()
        val path = Path().apply { moveTo(x, y) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 70))
            .build()
        return dispatchGesture(gesture, null, null)
    }

    fun dispatchSwipe(
        sessionId: String,
        senderIdentity: String,
        sequence: Long,
        normalizedStartX: Double,
        normalizedStartY: Double,
        normalizedEndX: Double,
        normalizedEndY: Double,
        durationMs: Long,
    ): Boolean {
        if (!validateCommand(sessionId, senderIdentity, sequence, "swipe")) return false
        val values = listOf(normalizedStartX, normalizedStartY, normalizedEndX, normalizedEndY)
        if (values.any { it !in 0.0..1.0 } || durationMs !in 120L..1000L) return false
        val metrics = displayMetrics() ?: return false
        val path = Path().apply {
            moveTo(normalizedStartX * (metrics.widthPixels - 1), normalizedStartY * (metrics.heightPixels - 1))
            lineTo(normalizedEndX * (metrics.widthPixels - 1), normalizedEndY * (metrics.heightPixels - 1))
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs))
            .build()
        return dispatchGesture(gesture, null, null)
    }

    private fun validateCommand(
        sessionId: String,
        senderIdentity: String,
        sequence: Long,
        capability: String,
    ): Boolean {
        if (blockedForeground) return false
        val keyguard = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
        val power = getSystemService(POWER_SERVICE) as PowerManager
        if (keyguard.isKeyguardLocked || !power.isInteractive) return false

        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        if (prefs.getString(KEY_SESSION, null) != sessionId) return false
        if (prefs.getString(KEY_HELPER, null) != senderIdentity) return false
        if (prefs.getLong(KEY_EXPIRY, 0L) <= System.currentTimeMillis()) {
            clearGrant(this)
            return false
        }
        if (capability !in (prefs.getStringSet(KEY_CAPABILITIES, emptySet()) ?: emptySet())) return false

        synchronized(this) {
            val lastSequence = prefs.getLong(KEY_SEQUENCE, 0L)
            if (sequence <= lastSequence) return false
            if (!prefs.edit().putLong(KEY_SEQUENCE, sequence).commit()) return false
        }
        return true
    }

    private fun displayMetrics(): DisplayMetrics? {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        val manager = getSystemService(WINDOW_SERVICE) as WindowManager
        @Suppress("DEPRECATION")
        manager.defaultDisplay.getRealMetrics(metrics)
        return metrics.takeIf { it.widthPixels > 0 && it.heightPixels > 0 }
    }
}
