import 'package:assistlink/src/features/calling/live_kit_call_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveKitConnectionCredentials', () {
    test('accepts secure LiveKit websocket URL and non-empty server token', () {
      const credentials = LiveKitConnectionCredentials(
        serverUrl: 'wss://example.livekit.cloud',
        accessToken: 'server-issued-short-lived-token',
      );

      expect(credentials.validate, returnsNormally);
    });

    test('rejects an invalid URL', () {
      const credentials = LiveKitConnectionCredentials(
        serverUrl: 'file:///tmp/room',
        accessToken: 'token',
      );

      expect(credentials.validate, throwsArgumentError);
    });

    test('rejects an empty token', () {
      const credentials = LiveKitConnectionCredentials(
        serverUrl: 'wss://example.livekit.cloud',
        accessToken: ' ',
      );

      expect(credentials.validate, throwsArgumentError);
    });
  });
}
