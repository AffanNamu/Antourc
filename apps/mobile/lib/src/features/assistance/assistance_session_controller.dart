import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../data/assistlink_api_client.dart';
import '../../platform/remote_assistance_platform.dart';

class AssistanceSessionController extends ChangeNotifier {
  AssistanceSessionController({
    required this.api,
    required this.callId,
    required this.currentUserId,
    required this.room,
  });

  static const controlTopic = 'assistlink.control.v1';

  final AssistLinkApiClient api;
  final String callId;
  final String currentUserId;
  final Room room;
  final RemoteAssistancePlatform _platform = RemoteAssistancePlatform();

  AssistanceSnapshot? _snapshot;
  Timer? _pollTimer;
  int _commandSequence = 0;
  bool _busy = false;
  String? _notice;
  bool _closed = false;

  AssistanceSnapshot? get snapshot => _snapshot;
  bool get busy => _busy;
  String? get notice => _notice;
  bool get isHost => _snapshot?.session.hostId == currentUserId;
  bool get isHelper => _snapshot?.session.helperId == currentUserId;

  ControlRequest? get latestRequest {
    final requests = _snapshot?.controlRequests ?? const <ControlRequest>[];
    return requests.isEmpty ? null : requests.first;
  }

  bool get hasPendingRequest =>
      isHost && latestRequest?.status == 'pending' &&
      latestRequest!.expiresAt.isAfter(DateTime.now());

  bool get controlApproved =>
      isHelper && latestRequest?.status == 'approved' &&
      latestRequest!.expiresAt.isAfter(DateTime.now());

  bool get hostControlActive =>
      isHost && latestRequest?.status == 'approved' &&
      latestRequest!.expiresAt.isAfter(DateTime.now());

  Future<void> startAsHost() async {
    if (_busy || _closed) return;
    _busy = true;
    _notice = null;
    notifyListeners();
    try {
      final session = await api.createAssistanceSession(callId);
      _snapshot = await api.assistanceSession(session.id);
      _startPolling();
    } catch (error) {
      _notice = _errorMessage(error);
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void startAsHelper() => _startPolling();

  void _startPolling() {
    _pollTimer?.cancel();
    unawaited(refresh());
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  Future<void> refresh() async {
    if (_closed || _busy) return;
    try {
      final next = await api.assistanceSessionForCall(callId);
      if (_closed) return;
      _snapshot = next;
      if (next == null || next.session.status != 'active') {
        _pollTimer?.cancel();
      } else if (next.session.hostId == currentUserId) {
        final local = room.localParticipant;
        final sharing = local?.videoTrackPublications.any(
              (publication) => publication.isScreenShare && publication.track != null,
            ) ?? false;
        if (!sharing) {
          await endHostSession();
          return;
        }
      }
      notifyListeners();
    } catch (error) {
      if (error is ApiException && error.statusCode == 404) return;
      _notice = _errorMessage(error);
      if (!_closed) notifyListeners();
    }
  }

  Future<void> requestControl() async {
    final current = _snapshot;
    if (current == null || !isHelper || _busy) return;
    _busy = true;
    _notice = null;
    notifyListeners();
    try {
      await api.requestControl(current.session.id);
      _busy = false;
      await refresh();
    } catch (error) {
      _notice = _errorMessage(error);
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> approvePendingRequest() async {
    final current = _snapshot;
    final pending = latestRequest;
    if (current == null || !isHost || pending == null || pending.status != 'pending') return;

    final status = await _platform.getStatus();
    if (!status.accessibilityEnabled) {
      throw StateError('Enable AssistLink in Android Accessibility settings before approving remote gestures.');
    }

    _busy = true;
    notifyListeners();
    try {
      final grant = await api.approveControlRequest(pending.id);
      final expiresAt = DateTime.parse(grant['expires_at'] as String);
      final capabilities = (grant['capabilities'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .where((value) => value == 'tap' || value == 'swipe')
          .toList(growable: false);
      if (capabilities.isEmpty) {
        await api.revokeControlRequest(pending.id);
        throw StateError('The requested gesture capabilities are not supported by this build.');
      }
      await _platform.activateControlGrant(
        sessionId: current.session.id,
        helperIdentity: current.session.helperId,
        expiresAtMillis: expiresAt.millisecondsSinceEpoch,
        capabilities: capabilities,
      );
      _busy = false;
      await refresh();
    } catch (error) {
      _notice = _errorMessage(error);
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> rejectPendingRequest() async {
    final pending = latestRequest;
    if (pending == null || !isHost || pending.status != 'pending') return;
    await api.rejectControlRequest(pending.id);
    await refresh();
  }

  Future<void> revokeControl() async {
    final pending = latestRequest;
    if (pending == null || !isHost || pending.status != 'approved') return;
    await _platform.revokeControlGrant();
    await api.revokeControlRequest(pending.id);
    await refresh();
  }

  Future<void> endHostSession() async {
    final current = _snapshot;
    if (current == null || !isHost) return;
    _pollTimer?.cancel();
    await _platform.revokeControlGrant();
    try {
      await api.endAssistanceSession(current.session.id);
    } finally {
      _snapshot = null;
      notifyListeners();
    }
  }

  Future<void> sendTap(double x, double y) async {
    final current = _snapshot;
    if (!controlApproved || current == null) return;
    final local = room.localParticipant;
    if (local == null) return;
    _commandSequence++;
    final payload = {
      'type': 'tap',
      'sessionId': current.session.id,
      'sequence': _commandSequence,
      'x': x.clamp(0.0, 1.0),
      'y': y.clamp(0.0, 1.0),
    };
    await local.publishData(
      utf8.encode(jsonEncode(payload)),
      reliable: true,
      destinationIdentities: [current.session.hostId],
      topic: controlTopic,
    );
  }

  Future<void> sendSwipe({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    int durationMs = 350,
  }) async {
    final current = _snapshot;
    if (!controlApproved || current == null) return;
    final local = room.localParticipant;
    if (local == null) return;
    _commandSequence++;
    final payload = {
      'type': 'swipe',
      'sessionId': current.session.id,
      'sequence': _commandSequence,
      'startX': startX.clamp(0.0, 1.0),
      'startY': startY.clamp(0.0, 1.0),
      'endX': endX.clamp(0.0, 1.0),
      'endY': endY.clamp(0.0, 1.0),
      'durationMs': durationMs.clamp(120, 1000),
    };
    await local.publishData(
      utf8.encode(jsonEncode(payload)),
      reliable: true,
      destinationIdentities: [current.session.hostId],
      topic: controlTopic,
    );
  }

  Future<void> handleDataReceived(DataReceivedEvent event) async {
    final current = _snapshot;
    if (event.topic != controlTopic || current == null || !isHost) return;
    if ((event.participant?.identity ?? '') != current.session.helperId) return;

    final latest = latestRequest;
    if (latest == null || latest.status != 'approved' ||
        !latest.expiresAt.isAfter(DateTime.now())) return;

    try {
      final payload = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      if (payload['sessionId'] != current.session.id) return;
      final sequence = (payload['sequence'] as num?)?.toInt();
      if (sequence == null || sequence < 1) return;
      final sender = (event.participant?.identity ?? '');

      switch (payload['type']) {
        case 'tap':
          final x = (payload['x'] as num?)?.toDouble();
          final y = (payload['y'] as num?)?.toDouble();
          if (x == null || y == null) return;
          await _platform.dispatchTap(
            sessionId: current.session.id,
            senderIdentity: sender,
            sequence: sequence,
            x: x,
            y: y,
          );
          break;
        case 'swipe':
          final startX = (payload['startX'] as num?)?.toDouble();
          final startY = (payload['startY'] as num?)?.toDouble();
          final endX = (payload['endX'] as num?)?.toDouble();
          final endY = (payload['endY'] as num?)?.toDouble();
          final duration = (payload['durationMs'] as num?)?.toInt();
          if (startX == null || startY == null || endX == null || endY == null || duration == null) return;
          await _platform.dispatchSwipe(
            sessionId: current.session.id,
            senderIdentity: sender,
            sequence: sequence,
            startX: startX,
            startY: startY,
            endX: endX,
            endY: endY,
            durationMs: duration,
          );
          break;
      }
    } catch (_) {
      // Malformed or unsupported data packets are ignored.
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.code.replaceAll('_', ' ');
    return error.toString().replaceFirst('Bad state: ', '');
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _pollTimer?.cancel();
    if (isHost) {
      await _platform.revokeControlGrant();
      final current = _snapshot;
      if (current != null) {
        await api.endAssistanceSession(current.session.id).catchError((_) {});
      }
    }
    super.dispose();
  }
}
