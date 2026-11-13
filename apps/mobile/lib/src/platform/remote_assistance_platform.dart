import 'package:flutter/services.dart';

/// Typed boundary for host-side Android capabilities.
///
/// Methods fail closed until their native implementations and permission
/// flows are connected and device-tested. UI must not infer consent or service
/// availability from a button press.
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
}

class HostEngineStatus {
  const HostEngineStatus({required this.available, required this.reason});

  const HostEngineStatus.unavailable()
      : available = false,
        reason = 'Native host engine is not installed.';

  final bool available;
  final String reason;

  factory HostEngineStatus.fromMap(Map<String, Object?>? value) {
    if (value == null) return const HostEngineStatus.unavailable();
    return HostEngineStatus(
      available: value['available'] == true,
      reason: value['reason'] as String? ?? 'Unknown native engine state.',
    );
  }
}
