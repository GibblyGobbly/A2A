// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../models/conversion_result.dart';
import '../../models/file_item.dart';
import '../../services/batch_runner.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brutal.dart';
import '../../widgets/task_runner.dart';
import '../../widgets/tool_scaffold.dart';

/// A tool with no settings: explains what will happen, lists the files and
/// runs on one tap.
class SimpleToolScreen extends StatelessWidget {
  final String title;
  final String explanation;
  final List<FileItem> files;
  final String actionLabel;
  final IconData actionIcon;
  final Future<List<ConversionResult>> Function(BatchProgress progress) run;
  final VoidCallback onCancel;

  /// Notification title when the job should survive the screen turning off.
  final String? keepAlive;

  const SimpleToolScreen({
    super.key,
    required this.title,
    required this.explanation,
    required this.files,
    required this.actionLabel,
    required this.run,
    required this.onCancel,
    this.actionIcon = Icons.check,
    this.keepAlive,
  });

  @override
  Widget build(BuildContext context) {
    final count = files.length;
    return ToolScaffold(
      title: title,
      subtitle: count == 1 ? files.first.name : '$count files',
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      onAction: () =>
          runTask(context, work: run, onCancel: onCancel, keepAlive: keepAlive),
      children: [
        Text(explanation, style: AppTheme.body),
        const SizedBox(height: 24),
        SectionLabel(count == 1 ? 'File' : 'Files'),
        BrutalBox(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final (i, file) in files.indexed) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(AppTheme.categoryIcon(file.category)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body,
                        ),
                      ),
                      Text(file.formattedSize, style: AppTheme.caption),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
