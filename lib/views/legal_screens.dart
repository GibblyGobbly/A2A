import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/legal.dart';
import '../services/app_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal.dart';

/// Standard page frame: back button, title, scrolling body.
class PageFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const PageFrame({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  BrutalIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: AppTheme.display.copyWith(fontSize: 20),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await AppStorageService.openUrl(url)) {
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(
      const SnackBar(content: Text('No browser found. Link copied.')),
    );
  }
}

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: document.title,
      children: [
        Text(document.effective, style: AppTheme.caption),
        for (final section in document.sections) ...[
          const SizedBox(height: 24),
          Text(section.heading, style: AppTheme.title.copyWith(fontSize: 16)),
          for (final paragraph in section.paragraphs) ...[
            const SizedBox(height: 8),
            SelectableText(paragraph, style: AppTheme.body),
          ],
        ],
      ],
    );
  }
}

/// Full text of one license file from the app's assets.
class LicenseTextScreen extends StatelessWidget {
  final String title;
  final String asset;

  const LicenseTextScreen({
    super.key,
    required this.title,
    required this.asset,
  });

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: title,
      children: [
        FutureBuilder<String>(
          future: rootBundle.loadString(asset),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'The license text could not be loaded.',
                style: AppTheme.body,
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return SelectableText(
              snapshot.data!,
              style: AppTheme.body.copyWith(
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            );
          },
        ),
      ],
    );
  }
}

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Open-source credits',
      children: [
        Text(
          'A2A is free software under the GNU GPLv3 and is built on the work of these projects. Tap one to open its source code.',
          style: AppTheme.body,
        ),
        const SizedBox(height: 16),
        for (final c in Legal.components) ...[
          _CreditRow(component: c),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        BrutalButton(
          label: 'All package licenses',
          icon: Icons.gavel,
          color: AppTheme.surface,
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'A2A',
            applicationLegalese: 'GNU General Public License v3.0',
          ),
        ),
      ],
    );
  }
}

class _CreditRow extends StatelessWidget {
  final OpenSourceComponent component;

  const _CreditRow({required this.component});

  @override
  Widget build(BuildContext context) {
    final asset = component.licenseAsset;
    return Pressable(
      onTap: () => openLink(context, component.url),
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      semanticLabel: 'Open ${component.name} source code',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component.name,
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(component.purpose, style: AppTheme.caption),
                const SizedBox(height: 2),
                Text(
                  component.license,
                  style: AppTheme.caption.copyWith(color: AppTheme.ink),
                ),
              ],
            ),
          ),
          if (asset != null)
            IconButton(
              icon: const Icon(Icons.article_outlined),
              tooltip: 'Read the ${component.name} license',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LicenseTextScreen(
                    title: '${component.name} license',
                    asset: asset,
                  ),
                ),
              ),
            ),
          const Icon(Icons.open_in_new, size: 20),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
