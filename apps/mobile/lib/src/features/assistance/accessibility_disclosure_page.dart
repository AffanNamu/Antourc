import 'package:flutter/material.dart';

import '../../platform/remote_assistance_platform.dart';

class AccessibilityDisclosurePage extends StatefulWidget {
  const AccessibilityDisclosurePage({super.key});

  @override
  State<AccessibilityDisclosurePage> createState() => _AccessibilityDisclosurePageState();
}

class _AccessibilityDisclosurePageState extends State<AccessibilityDisclosurePage> {
  final _platform = RemoteAssistancePlatform();
  bool _acknowledged = false;
  bool _openingSettings = false;

  Future<void> _continue() async {
    if (!_acknowledged || _openingSettings) return;
    setState(() => _openingSettings = true);
    try {
      await _platform.openAccessibilitySettings();
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Could not open Android Accessibility settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Remote assistance permission')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const Icon(Icons.touch_app_rounded, size: 48, color: Color(0xFF78A9FF)),
              const SizedBox(height: 18),
              const Text(
                'How AssistLink uses Accessibility',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              const Text(
                'AssistLink uses Android AccessibilityService only to perform basic taps and swipes that a person you explicitly approve sends during an active support call.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              _DisclosureItem(
                title: 'What the service can access',
                body: 'It receives app/window change events and whether a password field has focus so AssistLink can block gestures on known protected system surfaces. It does not retrieve window text, read passwords, or inspect app content.',
              ),
              _DisclosureItem(
                title: 'How it is used and shared',
                body: 'Only the helper identity approved for the current session can send tap and swipe commands. Commands are relayed through the encrypted call data channel and are not stored as screen content.',
              ),
              _DisclosureItem(
                title: 'Your control',
                body: 'Android requires you to enable this service manually in Settings. Screen sharing and remote assistance require separate approvals. You can revoke assistance or stop screen sharing at any time.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF332514),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF8C642F)),
                ),
                child: const Text(
                  'Remote gestures are blocked while the phone is locked, the screen is off, a password field is focused, or selected Android system/permission surfaces are foregrounded. This cannot guarantee detection of every sensitive screen; never approve someone you do not trust.',
                  style: TextStyle(height: 1.45),
                ),
              ),
              const SizedBox(height: 18),
              CheckboxListTile(
                value: _acknowledged,
                onChanged: (value) => setState(() => _acknowledged = value == true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I understand what AssistLink AccessibilityService can access and how approved remote gestures work.',
                  style: TextStyle(height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _acknowledged && !_openingSettings ? _continue : null,
                icon: const Icon(Icons.settings),
                label: Text(_openingSettings ? 'Opening Settings…' : 'Continue to Android Settings'),
              ),
            ],
          ),
        ),
      );
}

class _DisclosureItem extends StatelessWidget {
  const _DisclosureItem({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFF141B27),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF263246)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(body, style: const TextStyle(color: Colors.white70, height: 1.45)),
            ],
          ),
        ),
      );
}
