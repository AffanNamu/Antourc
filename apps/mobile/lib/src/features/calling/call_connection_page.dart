// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../data/assistlink_api_client.dart';
import 'room_call_page.dart';

class CallConnectionPage extends StatefulWidget {
  const CallConnectionPage({
    required this.api,
    required this.callId,
    required this.peerLabel,
    required this.isIncoming,
    super.key,
  });

  final AssistLinkApiClient api;
  final String callId;
  final String peerLabel;
  final bool isIncoming;

  @override
  State<CallConnectionPage> createState() => _CallConnectionPageState();
}

class _CallConnectionPageState extends State<CallConnectionPage> {
  String _status = 'Preparing secure call…';
  String? _error;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _joinCall();
  }

  Future<void> _joinCall() async {
    try {
      if (widget.isIncoming) {
        setState(() => _status = 'Accepting call…');
        await widget.api.acceptCall(widget.callId);
      } else {
        setState(() => _status = 'Waiting for the other person to answer…');
        var accepted = false;
        for (var attempt = 0; attempt < 28 && mounted && !_cancelled; attempt++) {
          final status = await widget.api.callStatus(widget.callId);
          if (status == 'accepted') {
            accepted = true;
            break;
          }
          if (status != 'ringing') {
            throw const ApiException(409, 'call_no_longer_available');
          }
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        if (!accepted) throw const ApiException(408, 'call_timed_out');
      }

      if (!mounted || _cancelled) return;
      setState(() => _status = 'Securing media connection…');
      final credentials = await widget.api.callCredentials(widget.callId);
      if (!mounted || _cancelled) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RoomCallPage(
            credentials: credentials,
            peerLabel: widget.peerLabel,
            onCallEnded: () => widget.api.endCall(widget.callId),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException ? error.code.replaceAll('_', ' ') : 'Could not connect this call.';
      });
    }
  }

  Future<void> _cancel() async {
    _cancelled = true;
    try {
      if (widget.isIncoming) {
        await widget.api.rejectCall(widget.callId);
      } else {
        await widget.api.endCall(widget.callId);
      }
    } catch (_) {
      // The call may already have expired or ended on the other device.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.peerLabel)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_error == null ? Icons.video_call_rounded : Icons.call_end_rounded, size: 58),
                const SizedBox(height: 18),
                Text(_error ?? _status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                if (_error == null) ...[
                  const SizedBox(height: 18),
                  const CircularProgressIndicator(),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.call_end),
                  label: Text(_error == null ? 'Cancel call' : 'Close'),
                ),
              ],
            ),
          ),
        ),
      );
}
