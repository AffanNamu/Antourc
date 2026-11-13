// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../data/assistlink_api_client.dart';
import '../assistance/accessibility_disclosure_page.dart';
import '../assistance/assistance_session_controller.dart';
import 'live_kit_call_session.dart';

class RoomCallPage extends StatefulWidget {
  const RoomCallPage({
    required this.api,
    required this.callId,
    required this.currentUserId,
    required this.credentials,
    required this.peerLabel,
    this.onCallEnded,
    super.key,
  });

  final AssistLinkApiClient api;
  final String callId;
  final String currentUserId;
  final LiveKitConnectionCredentials credentials;
  final String peerLabel;
  final Future<void> Function()? onCallEnded;

  @override
  State<RoomCallPage> createState() => _RoomCallPageState();
}

class _RoomCallPageState extends State<RoomCallPage> {
  late final LiveKitCallSession _session;
  AssistanceSessionController? _assistance;
  dynamic _roomListener;

  @override
  void initState() {
    super.initState();
    _session = LiveKitCallSession(widget.credentials)..addListener(_refresh);
    _connect();
  }

  Future<void> _connect() async {
    try {
      await _session.connect();
      final room = _session.room;
      if (room == null) throw StateError('LiveKit room was not created.');
      _assistance = AssistanceSessionController(
        api: widget.api,
        callId: widget.callId,
        currentUserId: widget.currentUserId,
        room: room,
      )..addListener(_refresh);
      _roomListener = room.createListener()
        ..on<DataReceivedEvent>((event) {
          final controller = _assistance;
          if (controller != null) unawaited(controller.handleDataReceived(event));
        });
      _assistance!.startAsHelper();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _startScreenShare() async {
    await _session.startScreenShare();
    try {
      await _assistance?.startAsHost();
    } catch (_) {
      await _session.stopScreenShare();
      rethrow;
    }
  }

  Future<void> _stopScreenShare() async {
    try {
      await _session.stopScreenShare();
    } finally {
      await _assistance?.endHostSession();
    }
  }

  Future<void> _approveControl() async {
    try {
      await _assistance?.approvePendingRequest();
    } catch (error) {
      if (!mounted) return;
      final shouldSetup = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remote assistance needs setup'),
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Set up')),
          ],
        ),
      );
      if (shouldSetup == true && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccessibilityDisclosurePage()),
        );
      }
    }
  }

  Future<void> _requestControl() async {
    try {
      await _assistance?.requestControl();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _rejectControl() async {
    try {
      await _assistance?.rejectPendingRequest();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _revokeControl() async {
    try {
      await _assistance?.revokeControl();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _assistancePanel() {
    final controller = _assistance!;
    final snapshot = controller.snapshot;
    final latest = controller.latestRequest;
    if (snapshot == null) return const SizedBox.shrink();
    if (controller.isHost) {
      if (controller.hasPendingRequest) {
        return _AssistancePanel(
          title: 'Someone is requesting remote assistance',
          detail: 'They can send basic taps and swipes only after you approve.',
          actions: [
            TextButton(onPressed: _rejectControl, child: const Text('Decline')),
            FilledButton(onPressed: _approveControl, child: const Text('Approve')),
          ],
        );
      }
      if (controller.hostControlActive) {
        return _AssistancePanel(
          title: 'Remote assistance is active',
          detail: 'The approved helper can tap and swipe. Revoke access whenever you want.',
          actions: [FilledButton.tonal(onPressed: _revokeControl, child: const Text('Revoke access'))],
        );
      }
      return const _AssistancePanel(
        title: 'You are sharing your screen',
        detail: 'No remote gestures are enabled. A helper must request access and you must approve it.',
      );
    }
    if (controller.controlApproved) {
      return const _AssistancePanel(
        title: 'Remote assistance approved',
        detail: 'Tap or swipe directly on the shared screen above to help.',
      );
    }
    if (latest?.status == 'pending') {
      return const _AssistancePanel(
        title: 'Waiting for host approval',
        detail: 'The phone owner must approve before your gestures can be sent.',
      );
    }
    return _AssistancePanel(
      title: 'Help with this phone',
      detail: controller.notice ?? 'Request permission to tap and swipe on the shared screen.',
      actions: [FilledButton(onPressed: controller.busy ? null : _requestControl, child: const Text('Request remote control'))],
    );
  }

  @override
  void dispose() {
    _session.removeListener(_refresh);
    _assistance?.removeListener(_refresh);
    _roomListener?.dispose();
    final assistance = _assistance;
    if (assistance != null) unawaited(assistance.close());
    unawaited(_session.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _session.room;
    final localParticipant = room?.localParticipant;
    final canSendGestures = _assistance?.controlApproved == true;
    final participantTiles = <Widget>[
      if (localParticipant != null)
        _ParticipantTile(participant: localParticipant, label: 'You', isLocal: true),
      if (room != null)
        for (final remote in room.remoteParticipants.values)
          _ParticipantTile(
            participant: remote,
            label: remote.name,
            isLocal: false,
            onScreenTap: canSendGestures ? _assistance!.sendTap : null,
            onScreenSwipe: canSendGestures
                ? (startX, startY, endX, endY) => _assistance!.sendSwipe(
                      startX: startX,
                      startY: startY,
                      endX: endX,
                      endY: endY,
                    )
                : null,
          ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF080B11),
      appBar: AppBar(
        title: Text(widget.peerLabel),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _ConnectionLabel(
                label: _session.connected
                    ? 'Connected'
                    : _session.connecting
                        ? 'Connecting'
                        : 'Disconnected',
                connected: _session.connected,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _session.connecting
                  ? const Center(child: CircularProgressIndicator())
                  : _session.failure != null
                      ? _CallError(message: _session.failure!, onRetry: _connect)
                      : participantTiles.isEmpty
                          ? const Center(child: Text('Waiting for call connection…'))
                          : GridView.count(
                              padding: const EdgeInsets.all(12),
                              crossAxisCount: participantTiles.length > 1 ? 2 : 1,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: participantTiles.length > 1 ? 0.72 : 0.9,
                              children: participantTiles,
                            ),
            ),
            if (_session.sharingScreen)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _SharingBanner(),
              ),
            if (_assistance != null) _assistancePanel(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 12,
                children: [
                  _CallAction(
                    icon: _session.microphoneEnabled ? Icons.mic : Icons.mic_off,
                    label: 'Microphone',
                    active: _session.microphoneEnabled,
                    onPressed: () => _runAction(
                      () => _session.setMicrophoneEnabled(!_session.microphoneEnabled),
                    ),
                  ),
                  _CallAction(
                    icon: _session.cameraEnabled ? Icons.videocam : Icons.videocam_off,
                    label: 'Camera',
                    active: _session.cameraEnabled,
                    onPressed: () => _runAction(
                      () => _session.setCameraEnabled(!_session.cameraEnabled),
                    ),
                  ),
                  _CallAction(
                    icon: _session.sharingScreen ? Icons.stop_screen_share : Icons.screen_share,
                    label: _session.sharingScreen ? 'Stop sharing' : 'Share screen',
                    active: _session.sharingScreen,
                    onPressed: () => _runAction(
                      _session.sharingScreen ? _stopScreenShare : _startScreenShare,
                    ),
                  ),
                  _CallAction(
                    icon: Icons.call_end,
                    label: 'End call',
                    active: false,
                    destructive: true,
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await _session.disconnect();
                      final assistance = _assistance;
                      if (assistance != null) await assistance.close();
                      try {
                        await widget.onCallEnded?.call();
                      } catch (_) {
                        // Local media is already stopped; server cleanup can expire the call.
                      }
                      navigator.pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }
}

class _ParticipantTile extends StatefulWidget {
  const _ParticipantTile({
    required this.participant,
    required this.label,
    required this.isLocal,
    this.onScreenTap,
    this.onScreenSwipe,
  });

  final dynamic participant;
  final String label;
  final bool isLocal;
  final Future<void> Function(double x, double y)? onScreenTap;
  final Future<void> Function(double startX, double startY, double endX, double endY)? onScreenSwipe;

  @override
  State<_ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<_ParticipantTile> {
  Offset? _swipeStart;
  Offset? _swipeCurrent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.participant,
      builder: (context, _) {
        VideoTrack? screenTrack;
        VideoTrack? cameraTrack;
        VideoDimensions? screenDimensions;
        for (final publication in widget.participant.videoTrackPublications) {
          final candidate = publication.track;
          if (candidate is VideoTrack && !publication.muted) {
            if (publication.isScreenShare) {
              screenTrack = candidate;
              screenDimensions = publication.dimensions;
            } else {
              cameraTrack = candidate;
            }
          }
        }
        final track = screenTrack ?? cameraTrack;
        final interactive = screenTrack != null &&
            !widget.isLocal &&
            widget.onScreenTap != null &&
            widget.onScreenSwipe != null;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: const Color(0xFF151D2A),
                child: track == null
                    ? const Center(
                        child: Icon(Icons.person_rounded, size: 64, color: Color(0xFF71819A)),
                      )
                    : interactive
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              Offset? normalize(Offset position) {
                                final width = constraints.maxWidth;
                                final height = constraints.maxHeight;
                                if (width <= 0 || height <= 0) return null;
                                final sourceWidth = screenDimensions?.width.toDouble() ?? width;
                                final sourceHeight = screenDimensions?.height.toDouble() ?? height;
                                if (sourceWidth <= 0 || sourceHeight <= 0) return null;
                                final sourceAspect = sourceWidth / sourceHeight;
                                final boxAspect = width / height;
                                final contentWidth = boxAspect > sourceAspect ? height * sourceAspect : width;
                                final contentHeight = boxAspect > sourceAspect ? height : width / sourceAspect;
                                final offsetX = (width - contentWidth) / 2;
                                final offsetY = (height - contentHeight) / 2;
                                if (position.dx < offsetX || position.dx > offsetX + contentWidth ||
                                    position.dy < offsetY || position.dy > offsetY + contentHeight) return null;
                                return Offset((position.dx - offsetX) / contentWidth,
                                    (position.dy - offsetY) / contentHeight);
                              }
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (details) {
                                  final point = normalize(details.localPosition);
                                  if (point == null) return;
                                  unawaited(widget.onScreenTap!(point.dx, point.dy));
                                },
                                onPanStart: (details) {
                                  _swipeStart = details.localPosition;
                                  _swipeCurrent = details.localPosition;
                                },
                                onPanUpdate: (details) { _swipeCurrent = details.localPosition; },
                                onPanEnd: (_) {
                                  final start = _swipeStart;
                                  final end = _swipeCurrent;
                                  _swipeStart = null;
                                  _swipeCurrent = null;
                                  if (start == null || end == null || (end - start).distance < 18) return;
                                  final normalizedStart = normalize(start);
                                  final normalizedEnd = normalize(end);
                                  if (normalizedStart == null || normalizedEnd == null) return;
                                  unawaited(widget.onScreenSwipe!(normalizedStart.dx, normalizedStart.dy,
                                      normalizedEnd.dx, normalizedEnd.dy));
                                },
                                child: SizedBox.expand(
                                  child: VideoTrackRenderer(track, fit: VideoViewFit.contain),
                                ),
                              );
                            },
                          )
                        : VideoTrackRenderer(track),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      screenTrack != null ? '${widget.label} · Screen' : widget.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              if (interactive)
                const Positioned(
                  top: 10,
                  right: 10,
                  child: Icon(Icons.touch_app_rounded, color: Colors.white70, size: 20),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AssistancePanel extends StatelessWidget {
  const _AssistancePanel({
    required this.title,
    required this.detail,
    this.actions = const [],
  });

  final String title;
  final String detail;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF172131),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2B3B52)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(detail, style: const TextStyle(color: Colors.white70, height: 1.35, fontSize: 12)),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: actions),
            ],
          ],
        ),
      );
}

class _ConnectionLabel extends StatelessWidget {
  const _ConnectionLabel({required this.label, required this.connected});

  final String label;
  final bool connected;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.circle, size: 8, color: connected ? Colors.greenAccent : Colors.orangeAccent),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _SharingBanner extends StatelessWidget {
  const _SharingBanner();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF3B2712),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF946021)),
        ),
        child: const Row(
          children: [
            Icon(Icons.screen_share, color: Color(0xFFFFC36A)),
            SizedBox(width: 10),
            Expanded(child: Text('Your screen is being shared. Tap Stop sharing to end capture.')),
          ],
        ),
      );
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool destructive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFFF5555)
        : active
            ? const Color(0xFF78A9FF)
            : const Color(0xFF283449);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            fixedSize: const Size(54, 54),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _CallError extends StatelessWidget {
  const _CallError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 14),
              const Text('Could not connect to the call', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}
