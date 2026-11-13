import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import 'live_kit_call_session.dart';

class RoomCallPage extends StatefulWidget {
  const RoomCallPage({
    required this.credentials,
    required this.peerLabel,
    this.onCallEnded,
    super.key,
  });

  final LiveKitConnectionCredentials credentials;
  final String peerLabel;
  final Future<void> Function()? onCallEnded;

  @override
  State<RoomCallPage> createState() => _RoomCallPageState();
}

class _RoomCallPageState extends State<RoomCallPage> {
  late final LiveKitCallSession _session;

  @override
  void initState() {
    super.initState();
    _session = LiveKitCallSession(widget.credentials)..addListener(_refresh);
    _connect();
  }

  Future<void> _connect() async {
    try {
      await _session.connect();
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session.removeListener(_refresh);
    unawaited(_session.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _session.room;
    final localParticipant = room?.localParticipant;
    final participantTiles = <Widget>[
      if (localParticipant != null)
        _ParticipantTile(participant: localParticipant, label: 'You'),
      if (room != null)
        for (final remote in room.remoteParticipants.values)
          _ParticipantTile(participant: remote, label: remote.name),
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
                      _session.sharingScreen
                          ? _session.stopScreenShare
                          : _session.startScreenShare,
                    ),
                  ),
                  _CallAction(
                    icon: Icons.call_end,
                    label: 'End call',
                    active: false,
                    destructive: true,
                    onPressed: () async {
                      await _session.disconnect();
                      try {
                        await widget.onCallEnded?.call();
                      } catch (_) {
                        // Local media is already stopped; server cleanup can expire the call.
                      }
                      if (mounted) Navigator.of(context).pop();
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

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant, required this.label});

  final dynamic participant;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: participant,
      builder: (context, _) {
        VideoTrack? videoTrack;
        for (final publication in participant.videoTrackPublications) {
          final candidate = publication.track;
          if (publication.subscribed && !publication.muted && candidate is VideoTrack) {
            videoTrack = candidate;
            break;
          }
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: const Color(0xFF151D2A),
                child: videoTrack == null
                    ? const Center(
                        child: Icon(Icons.person_rounded, size: 64, color: Color(0xFF71819A)),
                      )
                    : VideoTrackRenderer(videoTrack),
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
                    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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
