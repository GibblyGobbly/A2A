import 'package:flutter/material.dart';
import '../models/legal.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal.dart';
import 'legal_screens.dart';

/// Shown once, before first use: what A2A does and the Terms to accept.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _agreed = false;

  void _read(LegalDocument document) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LegalDocumentScreen(document: document),
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    final points = [
      (Icons.wifi_off, 'Works offline. A2A has no internet access at all.'),
      (
        Icons.phone_android,
        'Your files are converted on this phone and never uploaded.',
      ),
      (Icons.block, 'No accounts, no ads, no analytics, no tracking.'),
      (Icons.code, 'Free and open source under the GNU GPLv3.'),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: AppTheme.radiusSmall,
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 64,
                          height: 64,
                          cacheWidth: 192,
                          semanticLabel: 'A2A logo',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text('WELCOME TO A2A', style: AppTheme.display),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  for (final (icon, text) in points) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CategoryTile(
                          color: AppTheme.muted,
                          icon: icon,
                          size: 40,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(text, style: AppTheme.body),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Before you start, please read and accept:',
                    style: AppTheme.body,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: BrutalButton(
                          label: 'Terms',
                          color: AppTheme.surface,
                          onPressed: () => _read(Legal.terms),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BrutalButton(
                          label: 'Privacy',
                          color: AppTheme.surface,
                          onPressed: () => _read(Legal.privacy),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 27, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MergeSemantics(
                    child: InkWell(
                      borderRadius: AppTheme.radius,
                      onTap: () => setState(() => _agreed = !_agreed),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _agreed,
                              onChanged: (v) =>
                                  setState(() => _agreed = v ?? false),
                              activeColor: AppTheme.accent,
                              checkColor: AppTheme.onAccent,
                              side: BorderSide(
                                color: AppTheme.ink,
                                width: AppTheme.strokeHeavy,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'I have read and accept the Terms of Use and the Privacy Policy.',
                                style: AppTheme.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BrutalButton(
                    label: 'Accept and continue',
                    icon: Icons.arrow_forward,
                    onPressed: _agreed ? SettingsService.acceptTerms : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
