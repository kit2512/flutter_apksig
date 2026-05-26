import 'package:flutter/material.dart';

import 'pages/verify_page.dart';
import 'pages/verify_certificate_page.dart';
import 'pages/sign_page.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_apksig',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_apksig')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),
          Text('APK Tools', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Verify and sign Android APK files.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          _FeatureCard(
            icon: Icons.verified_outlined,
            color: Colors.green,
            title: 'Verify APK',
            description:
                'Check whether an APK\'s signatures (v1 / v2 / v3 / v4) are '
                'cryptographically valid and inspect each signer\'s certificate.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerifyPage()),
            ),
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            icon: Icons.fingerprint,
            color: Colors.blue,
            title: 'Certificate Check',
            description:
                'Confirm an APK was signed with a specific key by comparing '
                'its certificate SHA-256 fingerprint against an expected value.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerifyCertificatePage()),
            ),
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            icon: Icons.draw_outlined,
            color: Colors.orange,
            title: 'Sign APK',
            description:
                'Sign an APK with a Java keystore (.jks / .p12). '
                'Supports in-place signing and all APK signature scheme versions.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
