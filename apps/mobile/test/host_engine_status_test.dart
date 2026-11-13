import 'package:assistlink/src/platform/remote_assistance_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HostEngineStatus', () {
    test('reads Android service and active grant state', () {
      final status = HostEngineStatus.fromMap({
        'available': true,
        'accessibilityEnabled': true,
        'activeGrant': true,
        'reason': 'ready',
      });

      expect(status.available, isTrue);
      expect(status.accessibilityEnabled, isTrue);
      expect(status.activeGrant, isTrue);
      expect(status.reason, 'ready');
    });

    test('fails closed when the native channel is unavailable', () {
      const status = HostEngineStatus.unavailable();

      expect(status.available, isFalse);
      expect(status.accessibilityEnabled, isFalse);
      expect(status.activeGrant, isFalse);
    });
  });
}
