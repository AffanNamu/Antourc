package com.assistlink.app

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.assistlink/host_engine",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> {
                    val enabled = isAccessibilityServiceEnabled()
                    result.success(
                        mapOf(
                            "available" to true,
                            "accessibilityEnabled" to enabled,
                            "activeGrant" to AssistLinkAccessibilityService.hasGrant(this),
                            "reason" to if (enabled) "Gesture service is enabled." else "Gesture service needs manual activation in Android Settings.",
                        ),
                    )
                }

                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }

                "activateControlGrant" -> {
                    val args = call.arguments as? Map<*, *>
                    val sessionId = args?.get("sessionId") as? String
                    val helperIdentity = args?.get("helperIdentity") as? String
                    val expiresAt = (args?.get("expiresAtMillis") as? Number)?.toLong()
                    val capabilities = (args?.get("capabilities") as? List<*>)
                        ?.filterIsInstance<String>()?.toSet()
                    if (sessionId == null || helperIdentity.isNullOrBlank() ||
                        expiresAt == null || expiresAt <= System.currentTimeMillis() ||
                        capabilities.isNullOrEmpty() ||
                        !capabilities.all { it == "tap" || it == "swipe" }
                    ) {
                        result.error("INVALID_GRANT", "Invalid or unsupported local control grant.", null)
                    } else {
                        try {
                            UUID.fromString(sessionId)
                            AssistLinkAccessibilityService.saveGrant(
                                this,
                                sessionId,
                                helperIdentity,
                                expiresAt,
                                capabilities,
                            )
                            result.success(true)
                        } catch (_: IllegalArgumentException) {
                            result.error("INVALID_GRANT", "Session ID must be a UUID.", null)
                        }
                    }
                }

                "revokeControlGrant" -> {
                    AssistLinkAccessibilityService.clearGrant(this)
                    result.success(true)
                }

                "dispatchTap" -> {
                    val args = call.arguments as? Map<*, *>
                    val accepted = dispatchTap(args)
                    result.success(accepted)
                }

                "dispatchSwipe" -> {
                    val args = call.arguments as? Map<*, *>
                    val accepted = dispatchSwipe(args)
                    result.success(accepted)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun dispatchTap(args: Map<*, *>?): Boolean {
        val service = AssistLinkAccessibilityService.activeService ?: return false
        val sessionId = args?.get("sessionId") as? String ?: return false
        val sender = args["senderIdentity"] as? String ?: return false
        val sequence = (args["sequence"] as? Number)?.toLong() ?: return false
        val x = (args["x") as? Number)?.toDouble() ?: return false
        val y = (args["y") as? Number)?.toDouble() ?: return false
        return service.dispatchTap(sessionId, sender, sequence, x, y)
    }

    private fun dispatchSwipe(args: Map<*, *>?): Boolean {
        val service = AssistLinkAccessibilityService.activeService ?: return false
        val sessionId = args?.get("sessionId") as? String ?: return false
        val sender = args["senderIdentity"] as? String ?: return false
        val sequence = (args["sequence"] as? Number)?.toLong() ?: return false
        val startX = (args["startX"] as? Number)?.toDouble() ?: return false
        val startY = (args["startY"] as? Number)?.toDouble() ?: return false
        val endX = (args["endX"] as? Number)?.toDouble() ?: return false
        val endY = (args["endY"] as? Number)?.toDouble() ?: return false
        val duration = (args["durationMs"] as? Number)?.toLong() ?: return false
        return service.dispatchSwipe(
            sessionId,
            sender,
            sequence,
            startX,
            startY,
            endX,
            endY,
            duration,
        )
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = ComponentName(this, AssistLinkAccessibilityService::class.java)
            .flattenToString()
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        return splitter.any { it.equals(expected, ignoreCase = true) }
    }
}
