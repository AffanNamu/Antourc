import 'package:flutter/services.dart';

/// Typed boundary for host-side Android capabilities.
class RemoteAssistancePlatform {
  RemoteAssistancePlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.assistlink/host_engine');

  final MethodChannel _channel;

  Future<HostEngineStatus> getStatus() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('getStatus');
      return HostEngineStatus.fromMap(result);
    } on MissingPluginException {
      return const HostEngineStatus.unavailable();
    } on PlatformException {
      return const HostEngineStatus.unavailable();
    }
  }

  Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod<bool>('openAccessibilitySettings');
  }

  Future<void> activateControlGrant({
    required String sessionId,
    required String helperIdentity,
    required int expiresAtMillis,
    required List<String> capabilities,
  }) async {
    await _channel.invokeMethod<bool>('activateControlGrant', {
      'sessionId': sessionId,
      'helperIdentity': helperIdentity,
      'expiresAtMillis': expiresAtMillis,
      'capabilities': capabilities,
    });
  }

  Future<void> revokeControlGrant() async {
    await _channel.invokeMethod<bool>('revokeControlGrant');
  }

  Future<bool> dispatchTap({
    required String sessionId,
    required String senderIdentity,
    required int sequence,
    required double x,
    required double y,
  }) async {
    return await _channel.invokeMethod<bool>('dispatchTap', {
          'sessionId': sessionId,
          'senderIdentity': senderIdentity,
          'sequence': sequence,
          'x': x,
          'y': y,
        }) ??
        false;
  }

  Future<bool> dispatchSwipe({
    required String sessionId,
    required String senderIdentity,
    required int sequence,
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    required int durationMs,
  }) async {
    return await _channel.invokeMethod<bool>('dispatchSwipe', {
          'sessionId': sessionId,
          'senderIdentity': senderIdentity,
          'sequence': sequence,
          'startX': startX,
          'startY': startY,
          'endX': endX,
          'endY': endY,
          'durationMs': durationMs,
        }) ??
        false;
  }
}

class HostEngineStatus {
  const HostEngineStatus({
    required this.available,
    required this.reason,
    this.accessibilityEnabled = false,
    this.activeGrant = false,
  });

  const HostEngineStatus.unavailable()
      : available = false,
        reason = 'Native host engine is not installed.',
        accessibilityEnabled = false,
        activeGrant = false;

  final bool available;
  final String reason;
  final bool accessibilityEnabled;
  final bool activeGrant;

  factory HostEngineStatus.fromMap(Map<String, Object?>? value) {
    if (value == null) return const HostEngineStatus.unavailable();
    return HostEngineStatus(
      available: value['available'] == true,
      reason: value['reason'] as String? ?? 'Unknown native engine state.',
      accessibilityEnabled: value['accessibilityEnabled'] == true,
      activeGrant: value['activeGrant'] == true,
    );
  }
}
