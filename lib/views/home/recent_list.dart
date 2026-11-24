// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/conversion_result.dart';
import '../../models/file_item.dart';
import '../../services/history_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brutal.dart';
import '../../widgets/result_sheet.dart';

/// The last few saved files. Tap to open one; the edit button takes it back
/// into the workspace so edits can be chained.
class RecentList extends StatelessWidget {
  static const shown = 3;

  final VoidCallback onSeeAll;
  final ValueChanged<FileItem> onEdit;

  const RecentList({super.key, required this.onSeeAll, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ConversionResult>>(
      valueListenable: HistoryService.historyNotifier,
      builder: (context, history, _) {
        if (history.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            SectionLabel(
              'Recent',
              trailing: TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(
                  'SEE ALL',
                  style: AppTheme.label.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            for (final (i, item) in history.take(shown).indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              _RecentRow(item: item, onEdit: onEdit),
            ],
          ],
        );
      },
    );
  }
}

class _RecentRow extends StatelessWidget {
  final ConversionResult item;
  final ValueChanged<FileItem> onEdit;

  const _RecentRow({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final file = File(item.targetPath);
    final exists = file.existsSync();
    final category = FileItem.detectCategory(item.targetExtension);
    return Pressable(
      onTap: exists ? () => openResultFile(context, item.targetPath) : null,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      semanticLabel: 'Open ${item.targetName}',
      child: Row(
        children: [
          Icon(AppTheme.categoryIcon(category), color: AppTheme.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.targetName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body,
                ),
                Text(
                  exists ? item.convertedFormattedSize : 'File was deleted',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
          if (exists && category != FileCategory.unknown)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit this file',
              color: AppTheme.ink,
              onPressed: () => onEdit(FileItem.fromFile(file)),
            ),
        ],
      ),
    );
  }
}
