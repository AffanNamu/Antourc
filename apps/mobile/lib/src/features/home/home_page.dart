import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            tooltip: 'Settings',
            onPressed: () => _showNotReady(context, 'Settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const Text('Remote help,\nwith permission.',
                style: TextStyle(fontSize: 30, height: 1.12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'Call someone, see their screen, and help them when they approve.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.call_rounded, size: 30, color: Color(0xFF78A9FF)),
                    const SizedBox(height: 14),
                    const Text('Start a call', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('Connect with a trusted person using an invitation or account ID.'),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _showNotReady(context, 'Calling'),
                        icon: const Icon(Icons.video_call_rounded),
                        label: const Text('New call'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.screen_share_rounded, size: 30, color: Color(0xFF7CD9B1)),
                    const SizedBox(height: 14),
                    const Text('Share your screen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('You stay in control. Android will ask you before screen capture begins.'),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showNotReady(context, 'Screen sharing'),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Share screen during a call'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
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
                      'Remote control is never automatic. Screen sharing and assistance require separate approval, and you can stop them at any time.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('FOUNDATION BUILD', style: TextStyle(letterSpacing: 1.3, fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('Calling and screen-sharing services are not connected yet. This status is shown intentionally; no demo call or fake connection is presented.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
          ],
        ),
      ),
    );
  }

  void _showNotReady(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature service is not connected yet.')),
    );
  }
}
