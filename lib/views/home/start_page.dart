// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../models/file_item.dart';
import '../../services/file_pick_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brutal.dart';
import '../settings_screen.dart';
import '../workspace/workspace_screen.dart';
import 'recent_list.dart';
import 'type_grid.dart';

/// First tab: open files, or pick by type, plus the most recent outputs.
class StartPage extends StatefulWidget {
  final VoidCallback onSeeAllFiles;

  const StartPage({super.key, required this.onSeeAllFiles});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  bool _picking = false;

  Future<void> _pick([FileCategory? category]) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await FilePickService.pick(
      category: category,
      onLoading: (v) => mounted ? setState(() => _picking = v) : null,
    );
    if (!mounted) return;
    final error = outcome.error;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (outcome.skipped > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            outcome.files.isEmpty
                ? 'A2A cannot open ${outcome.skipped == 1 ? 'that file' : 'those files'}.'
                : 'Opened one kind of file at a time; skipped ${outcome.skipped}.',
          ),
        ),
      );
    }
    if (outcome.files.isNotEmpty) {
      await WorkspaceScreen.open(context, outcome.files);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text('A2A', style: AppTheme.display)),
            BrutalIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onPressed: () => SettingsScreen.open(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Edit, convert and shrink files. Everything stays on this phone.',
          style: AppTheme.body,
        ),
        const SizedBox(height: 16),
        _openButton(),
        const SizedBox(height: 24),
        const SectionLabel('Or pick by type'),
        TypeGrid(enabled: !_picking, onPick: _pick),
        RecentList(
          onSeeAll: widget.onSeeAllFiles,
          onEdit: (file) => WorkspaceScreen.open(context, [file]),
        ),
      ],
    );
  }

  Widget _openButton() {
    return Pressable(
      onTap: _picking ? null : _pick,
      raised: true,
      color: AppTheme.accent,
      stroke: AppTheme.strokeHeavy,
      padding: const EdgeInsets.all(16),
      semanticLabel: 'Open files',
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: _picking
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppTheme.onAccent,
                    ),
                  )
                : Icon(Icons.add, size: 32, color: AppTheme.onAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _picking ? 'LOADING FILES' : 'OPEN FILES',
                  style: AppTheme.label.copyWith(
                    fontSize: 16,
                    color: AppTheme.onAccent,
                  ),
                ),
                Text(
                  'Photos, videos, music or PDFs. One or many.',
                  style: AppTheme.caption.copyWith(color: AppTheme.onAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
