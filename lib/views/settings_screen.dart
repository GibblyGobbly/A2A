// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../models/legal.dart';
import '../services/app_storage_service.dart';
import '../services/history_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal.dart';
import '../widgets/result_sheet.dart';
import 'legal_screens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<int> _cacheSize = AppStorageService.temporaryFilesSize();
  final Future<String> _version = AppStorageService.appVersion();

  @override
  void initState() {
    super.initState();
    SettingsService.notifier.addListener(_onSettings);
  }

  @override
  void dispose() {
    SettingsService.notifier.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _chooseFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await AppStorageService.chooseOutputDirectory();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _clearCache() async {
    final messenger = ScaffoldMessenger.of(context);
    await AppStorageService.clearTemporaryFiles();
    setState(() => _cacheSize = AppStorageService.temporaryFilesSize());
    messenger.showSnackBar(
      const SnackBar(content: Text('Temporary files cleared.')),
    );
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('CLEAR HISTORY?', style: AppTheme.title),
        content: Text(
          'This clears the list in Files. Converted files stay in ${AppStorageService.publicFolderLabel}.',
          style: AppTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('KEEP', style: AppTheme.label),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('CLEAR', style: AppTheme.label),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HistoryService.clearHistory();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('History cleared.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.current;
    var index = 0;
    // Sections slide in one after another when the page opens.
    Widget section(String title, List<Widget> rows) => _Entrance(
      order: index++,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(title),
            BrutalBox(
              padding: EdgeInsets.zero,
              child: Column(children: _divided(rows)),
            ),
          ],
        ),
      ),
    );

    return PageFrame(
      title: 'Settings',
      children: [
        section('Appearance', [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: AppTheme.body),
                const SizedBox(height: 8),
                ChoiceRow<ThemeMode>(
                  values: const [
                    ThemeMode.system,
                    ThemeMode.light,
                    ThemeMode.dark,
                  ],
                  selected: settings.themeMode,
                  labelOf: (m) => switch (m) {
                    ThemeMode.system => 'SYSTEM',
                    ThemeMode.light => 'LIGHT',
                    ThemeMode.dark => 'DARK',
                  },
                  onSelected: (m) =>
                      SettingsService.update(settings.copyWith(themeMode: m)),
                ),
              ],
            ),
          ),
          _SwitchRow(
            title: 'Haptic feedback',
            subtitle: 'Small vibrations on taps and selections',
            value: settings.haptics,
            onChanged: (v) =>
                SettingsService.update(settings.copyWith(haptics: v)),
          ),
        ]),
        section('Storage', [
          _LinkRow(
            icon: Icons.drive_folder_upload_outlined,
            title: 'Output folder',
            subtitle: AppStorageService.publicFolderLabel,
            trailing: Icons.edit_outlined,
            onTap: _chooseFolder,
          ),
          if (settings.outputDirectory != null)
            _LinkRow(
              icon: Icons.restart_alt,
              title: 'Use default folder',
              subtitle: 'Download/OmniConvert',
              onTap: AppStorageService.resetOutputDirectory,
            ),
          _LinkRow(
            icon: Icons.folder_open,
            title: 'Open output folder',
            subtitle: 'Show converted files in your file manager',
            onTap: () => openOutputFolder(context),
          ),
          FutureBuilder<int>(
            future: _cacheSize,
            builder: (context, snapshot) => _LinkRow(
              icon: Icons.cleaning_services_outlined,
              title: 'Clear temporary files',
              subtitle: snapshot.hasData
                  ? '${FileItem.formatBytes(snapshot.data!)} of copies of picked and shared files'
                  : 'Measuring',
              onTap: _clearCache,
            ),
          ),
          _LinkRow(
            icon: Icons.history,
            title: 'Clear history',
            subtitle: 'Converted files are kept',
            onTap: _clearHistory,
          ),
        ]),
        section('About', [
          FutureBuilder<String>(
            future: _version,
            builder: (context, snapshot) => _LinkRow(
              icon: Icons.info_outline,
              title: 'A2A ${snapshot.data ?? ''}'.trim(),
              subtitle: 'Offline file converter. Free software, GPLv3.',
            ),
          ),
          _LinkRow(
            icon: Icons.code,
            title: 'Source code',
            subtitle: 'github.com/GibblyGobbly/A2A',
            trailing: Icons.open_in_new,
            onTap: () => openLink(context, Legal.repositoryUrl),
          ),
          _LinkRow(
            icon: Icons.bug_report_outlined,
            title: 'Report a problem',
            subtitle: 'Opens GitHub issues in your browser',
            trailing: Icons.open_in_new,
            onTap: () => openLink(context, Legal.issuesUrl),
          ),
          _LinkRow(
            icon: Icons.favorite_border,
            title: 'Open-source credits',
            subtitle: 'Libraries, fonts and their licenses',
            onTap: () => _push(const CreditsScreen()),
          ),
          _LinkRow(
            icon: Icons.gavel,
            title: 'License',
            subtitle: 'GNU General Public License v3.0',
            onTap: () => _push(
              const LicenseTextScreen(
                title: 'GNU GPL v3',
                asset: Legal.appLicenseAsset,
              ),
            ),
          ),
        ]),
        section('Legal', [
          _LinkRow(
            icon: Icons.description_outlined,
            title: 'Terms of Use',
            subtitle: Legal.terms.effective,
            onTap: () =>
                _push(const LegalDocumentScreen(document: Legal.terms)),
          ),
          _LinkRow(
            icon: Icons.shield_outlined,
            title: 'Privacy Policy',
            subtitle: 'A2A collects no data',
            onTap: () =>
                _push(const LegalDocumentScreen(document: Legal.privacy)),
          ),
        ]),
      ],
    );
  }

  static List<Widget> _divided(List<Widget> rows) => [
    for (var i = 0; i < rows.length; i++) ...[
      if (i > 0) Divider(color: AppTheme.ink.withAlpha(0x33)),
      rows[i],
    ],
  ];
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? trailing;
  final VoidCallback? onTap;

  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing = Icons.chevron_right,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              Haptics.tap();
              onTap!();
            },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.ink),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(subtitle, style: AppTheme.caption),
                  ],
                ),
              ),
              if (onTap != null && trailing != null)
                Icon(trailing, color: AppTheme.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(subtitle, style: AppTheme.caption),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades and slides a section in, staggered by [order].
class _Entrance extends StatelessWidget {
  final int order;
  final Widget child;

  const _Entrance({required this.order, required this.child});

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, 320 + order * 70);
    if (duration == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
