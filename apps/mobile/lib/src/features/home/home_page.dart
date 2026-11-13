// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/assistlink_api_client.dart';
import '../auth/auth_page.dart';
import '../calling/call_connection_page.dart';
import '../assistance/accessibility_disclosure_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.api,
    required this.userId,
    required this.userEmail,
    required this.displayName,
    super.key,
  });

  final AssistLinkApiClient api;
  final String userId;
  final String userEmail;
  final String displayName;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _calleeEmail = TextEditingController();
  Timer? _pollTimer;
  List<IncomingCall> _incomingCalls = const [];
  bool _loadingCalls = false;
  bool _startingCall = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _refreshIncoming();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshIncoming());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _calleeEmail.dispose();
    super.dispose();
  }

  Future<void> _refreshIncoming() async {
    if (_loadingCalls) return;
    _loadingCalls = true;
    try {
      final calls = await widget.api.incomingCalls();
      if (mounted) setState(() => _incomingCalls = calls);
    } catch (error) {
      if (mounted && error is ApiException && error.statusCode != 401) {
        setState(() => _notice = 'Could not refresh incoming calls.');
      }
    } finally {
      _loadingCalls = false;
    }
  }

  Future<void> _startCall() async {
    final email = _calleeEmail.text.trim();
    if (!email.contains('@')) {
      setState(() => _notice = 'Enter the email address of the person you want to call.');
      return;
    }
    setState(() {
      _startingCall = true;
      _notice = null;
    });
    try {
      final callId = await widget.api.createCall(email);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallConnectionPage(
            api: widget.api,
            callId: callId,
            currentUserId: widget.userId,
            peerLabel: email,
            isIncoming: false,
          ),
        ),
      );
      await _refreshIncoming();
    } catch (error) {
      if (mounted) {
        setState(() => _notice = error is ApiException
            ? error.code.replaceAll('_', ' ')
            : 'Could not start the call.');
      }
    } finally {
      if (mounted) setState(() => _startingCall = false);
    }
  }

  Future<void> _answer(IncomingCall call) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallConnectionPage(
          api: widget.api,
          callId: call.id,
          currentUserId: widget.userId,
          peerLabel: call.callerName,
          isIncoming: true,
        ),
      ),
    );
    await _refreshIncoming();
  }

  Future<void> _reject(IncomingCall call) async {
    try {
      await widget.api.rejectCall(call.id);
      await _refreshIncoming();
    } catch (_) {
      if (mounted) setState(() => _notice = 'This call is no longer available.');
    }
  }

  Future<void> _signOut() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthPage(api: widget.api)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.hub_rounded, color: Color(0xFF78A9FF)),
              SizedBox(width: 10),
              Text('AssistLink', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshIncoming,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  'Hello, ${widget.displayName}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(widget.userEmail, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.video_call_rounded, size: 30, color: Color(0xFF78A9FF)),
                        const SizedBox(height: 12),
                        const Text('Start a secure call', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        const Text('Enter the verified email address of the person you want to call.'),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _calleeEmail,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Contact email',
                            hintText: 'person@example.com',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _startingCall ? null : _startCall,
                            icon: const Icon(Icons.call),
                            label: Text(_startingCall ? 'Starting…' : 'Call'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Incoming calls', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _refreshIncoming,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_incomingCalls.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141B27),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.call_received_rounded, color: Colors.white54),
                        SizedBox(width: 12),
                        Expanded(child: Text('No incoming calls. This list refreshes automatically.')),
                      ],
                    ),
                  )
                else
                  ..._incomingCalls.map(
                    (call) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(child: Icon(Icons.person)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(call.callerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const Text('Incoming video call', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Decline',
                              onPressed: () => _reject(call),
                              icon: const Icon(Icons.call_end, color: Color(0xFFFF7777)),
                            ),
                            IconButton(
                              tooltip: 'Answer',
                              onPressed: () => _answer(call),
                              icon: const Icon(Icons.call, color: Color(0xFF7CD9B1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  Text(_notice!, style: const TextStyle(color: Color(0xFFFFB56B))),
                ],
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF172131),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2B3B52)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFF7CD9B1)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Screen sharing requires Android system approval. Remote assistance requires a separate approval from the person sharing their screen.',
                          style: TextStyle(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccessibilityDisclosurePage()),
                  ),
                  icon: const Icon(Icons.touch_app_rounded),
                  label: const Text('Set up remote assistance on this phone'),
                ),
              ],
            ),
          ),
        ),
      );
}
