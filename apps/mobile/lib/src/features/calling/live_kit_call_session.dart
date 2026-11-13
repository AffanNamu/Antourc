import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

/// Credentials are issued by the authenticated AssistLink backend.
/// Never construct these from user-entered tokens or ship a LiveKit API secret.
class LiveKitConnectionCredentials {
  const LiveKitConnectionCredentials({
    required this.serverUrl,
    required this.accessToken,
  });

  final String serverUrl;
  final String accessToken;

  void validate() {
    final uri = Uri.tryParse(serverUrl);
    if (uri == null || !{'wss', 'ws', 'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw ArgumentError.value(serverUrl, 'serverUrl', 'Must be a valid LiveKit URL.');
    }
    if (accessToken.trim().isEmpty) {
      throw ArgumentError.value(accessToken, 'accessToken', 'A server-issued token is required.');
    }
  }
}

/// Owns one LiveKit room and the local media lifecycle for a one-to-one call.
/// The backend must authorize room membership and issue short-lived tokens.
class LiveKitCallSession extends ChangeNotifier {
  LiveKitCallSession(this.credentials);

  final LiveKitConnectionCredentials credentials;
  Room? _room;
  bool _connecting = false;
  bool _connected = false;
  bool _sharingScreen = false;
  bool _microphoneEnabled = false;
  bool _cameraEnabled = false;
  String? _failure;
  bool _closed = false;

  Room? get room => _room;
  bool get connecting => _connecting;
  bool get connected => _connected;
  bool get sharingScreen => _sharingScreen;
  bool get microphoneEnabled => _microphoneEnabled;
  bool get cameraEnabled => _cameraEnabled;
  String? get failure => _failure;

  Future<void> connect() async {
    if (_connected || _connecting || _closed) return;
    _connecting = true;
    _failure = null;
    notifyListeners();

    try {
      credentials.validate();
      final camera = await Permission.camera.request();
      final microphone = await Permission.microphone.request();

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      _room = room;
      room.addListener(_onRoomChanged);

      await room.connect(credentials.serverUrl, credentials.accessToken);

      if (microphone.isGranted) {
        await room.localParticipant.setMicrophoneEnabled(true);
        _microphoneEnabled = true;
      }
      if (camera.isGranted) {
        await room.localParticipant.setCameraEnabled(true);
        _cameraEnabled = true;
      }

      _connected = true;
    } catch (error) {
      _failure = _safeMessage(error);
      await _disposeRoom();
      rethrow;
    } finally {
      _connecting = false;
      if (!_closed) notifyListeners();
    }
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    final room = _requireRoom();
    if (_microphoneEnabled == enabled) return;
    if (enabled) {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        throw StateError('Microphone permission was not granted.');
      }
    }
    await room.localParticipant.setMicrophoneEnabled(enabled);
    _microphoneEnabled = enabled;
    notifyListeners();
  }

  Future<void> setCameraEnabled(bool enabled) async {
    final room = _requireRoom();
    if (_cameraEnabled == enabled) return;
    if (enabled) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        throw StateError('Camera permission was not granted.');
      }
    }
    await room.localParticipant.setCameraEnabled(enabled);
    _cameraEnabled = enabled;
    notifyListeners();
  }

  /// Requests Android's OS capture consent before publishing a screen track.
  /// A foreground notification remains visible while capture is active.
  Future<void> startScreenShare() async {
    final room = _requireRoom();
    if (_sharingScreen) return;
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Screen sharing is currently implemented for Android only.');
    }

    final approvedBySystem = await Helper.requestCapturePermission();
    if (!approvedBySystem) {
      throw StateError('Android screen-capture permission was declined.');
    }

    final initialized = await FlutterBackground.initialize(
      androidConfig: const FlutterBackgroundAndroidConfig(
        notificationTitle: 'AssistLink screen sharing',
        notificationText: 'Your screen is being shared in an active call.',
        notificationImportance: AndroidNotificationImportance.normal,
        enableWifiLock: true,
      ),
    );
    if (!initialized) {
      throw StateError('Could not initialize the screen-sharing foreground service.');
    }

    final foregroundStarted = await FlutterBackground.enableBackgroundExecution();
    if (!foregroundStarted) {
      throw StateError('Android did not start the screen-sharing foreground service.');
    }

    try {
      await room.localParticipant.setScreenShareEnabled(true);
      _sharingScreen = true;
      notifyListeners();
    } catch (_) {
      await FlutterBackground.disableBackgroundExecution();
      rethrow;
    }
  }

  Future<void> stopScreenShare() async {
    final room = _room;
    if (room == null || !_sharingScreen) return;
    try {
      await room.localParticipant.setScreenShareEnabled(false);
    } finally {
      _sharingScreen = false;
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
      if (!_closed) notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      if (_sharingScreen) await stopScreenShare();
    } finally {
      await _disposeRoom();
      _connected = false;
      _microphoneEnabled = false;
      _cameraEnabled = false;
      if (!_closed) notifyListeners();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    await disconnect();
    _closed = true;
    super.dispose();
  }

  Room _requireRoom() {
    final current = _room;
    if (!_connected || current == null) {
      throw StateError('The call is not connected.');
    }
    return current;
  }

  void _onRoomChanged() {
    if (!_closed) notifyListeners();
  }

  Future<void> _disposeRoom() async {
    final current = _room;
    _room = null;
    if (current == null) return;
    current.removeListener(_onRoomChanged);
    await current.disconnect();
    await current.dispose();
  }

  String _safeMessage(Object error) {
    final message = error.toString();
    return message.length > 240 ? message.substring(0, 240) : message;
  }
}
