// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../data/assistlink_api_client.dart';
import '../home/home_page.dart';
import 'auth_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({required this.api, super.key});

  final AssistLinkApiClient api;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Map<String, dynamic>?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUser();
  }

  Future<Map<String, dynamic>?> _loadUser() {
    if (!widget.api.isConfigured) return Future.value(null);
    return widget.api.currentUser();
  }

  void _retry() => setState(() => _userFuture = _loadUser());

  @override
  Widget build(BuildContext context) {
    if (!widget.api.isConfigured) return const _ApiConfigurationPage();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not reach the AssistLink server.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          );
        }
        final user = snapshot.data;
        if (user == null) return AuthPage(api: widget.api);
        return HomePage(
          api: widget.api,
          userId: user['id'] as String,
          userEmail: user['email'] as String,
          displayName: user['displayName'] as String,
        );
      },
    );
  }
}

class _ApiConfigurationPage extends StatelessWidget {
  const _ApiConfigurationPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hub_rounded, size: 48, color: Color(0xFF78A9FF)),
                  const SizedBox(height: 18),
                  const Text('Connect AssistLink to its server',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text(
                    'This app does not ship with a hardcoded server or media secret. Configure your deployed API URL at build time.',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151D2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SelectableText(
                      'flutter build apk --release --dart-define=ASSISTLINK_API_BASE_URL=https://your-api.example.com',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The backend must be deployed with PostgreSQL, SMTP verification and LiveKit credentials before sign-in and calls can work.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
