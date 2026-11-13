import 'package:flutter/material.dart';

import '../../data/assistlink_api_client.dart';
import '../home/home_page.dart';

enum _AuthMode { login, register, verify }

class AuthPage extends StatefulWidget {
  const AuthPage({required this.api, super.key});

  final AssistLinkApiClient api;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _displayName.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_mode != _AuthMode.verify && !(_formKey.currentState?.validate() ?? false)) return;
    if (_mode == _AuthMode.verify && !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'Enter the six-digit code sent to your email.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });

    try {
      if (_mode == _AuthMode.register) {
        await widget.api.register(
          email: _email.text.trim(),
          displayName: _displayName.text.trim(),
          password: _password.text,
        );
        setState(() {
          _mode = _AuthMode.verify;
          _message = 'Check your email for a six-digit verification code.';
        });
      } else if (_mode == _AuthMode.verify) {
        await widget.api.verifyEmail(email: _email.text.trim(), code: _code.text.trim());
        setState(() {
          _mode = _AuthMode.login;
          _message = 'Email verified. You can now sign in.';
        });
      } else {
        final user = await widget.api.login(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(
              api: widget.api,
              userId: user['id'] as String,
              userEmail: user['email'] as String,
              displayName: user['displayName'] as String,
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error.code));
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(String code) => switch (code) {
        'account_already_exists' => 'An account with this email already exists.',
        'email_verification_required' => 'Verify your email before signing in.',
        'invalid_credentials' => 'Email or password is incorrect.',
        'invalid_or_expired_code' => 'That code is incorrect or has expired.',
        'email_verification_unavailable' => 'Email verification is not configured on the server.',
        'request_failed' => 'The server could not complete this request.',
        _ => code.replaceAll('_', ' '),
      };

  @override
  Widget build(BuildContext context) {
    final verifying = _mode == _AuthMode.verify;
    final registering = _mode == _AuthMode.register;
    final title = verifying ? 'Verify your email' : registering ? 'Create account' : 'Welcome back';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.hub_rounded, size: 46, color: Color(0xFF78A9FF)),
                    const SizedBox(height: 18),
                    Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      verifying
                          ? 'Enter the verification code sent to ${_email.text}.'
                          : 'Secure video calls and screen sharing with explicit permission.',
                      style: const TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    if (!verifying && registering) ...[
                      TextFormField(
                        controller: _displayName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Display name', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.trim().length < 2) ? 'Enter your name.' : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (!verifying) ...[
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email address', border: OutlineInputBorder()),
                        validator: (value) => (value == null || !value.contains('@')) ? 'Enter a valid email.' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.length < (registering ? 10 : 1))
                            ? (registering ? 'Use at least 10 characters.' : 'Enter your password.')
                            : null,
                      ),
                    ] else
                      TextFormField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(labelText: '6-digit code', border: OutlineInputBorder()),
                      ),
                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      Text(_message!, style: const TextStyle(color: Color(0xFF7CD9B1))),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!, style: const TextStyle(color: Color(0xFFFF8585))),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(verifying ? 'Verify email' : registering ? 'Create account' : 'Sign in'),
                    ),
                    if (!verifying) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _mode = registering ? _AuthMode.login : _AuthMode.register;
                                  _error = null;
                                  _message = null;
                                }),
                        child: Text(registering ? 'Already have an account? Sign in' : 'New to AssistLink? Create account'),
                      ),
                    ] else
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _mode = _AuthMode.login;
                                  _error = null;
                                  _message = 'After verifying, sign in with your email and password.';
                                }),
                        child: const Text('Back to sign in'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
