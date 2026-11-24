// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../../../models/file_item.dart';
import '../../../models/image_details.dart';
import '../../../services/image/image_tools_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/brutal.dart';
import '../../../widgets/task_runner.dart';
import '../../../widgets/tool_scaffold.dart';

/// Shows what hidden data each photo carries, then removes it.
class StripMetadataScreen extends StatefulWidget {
  final List<FileItem> files;

  const StripMetadataScreen({super.key, required this.files});

  @override
  State<StripMetadataScreen> createState() => _StripMetadataScreenState();
}

class _StripMetadataScreenState extends State<StripMetadataScreen> {
  /// Listing every photo of a large batch would be slow and long.
  static const _listed = 20;

  final Map<String, ImageDetails?> _found = {};

  @override
  void initState() {
    super.initState();
    _scan();
  }

  /// Reads the files one at a time so a large batch never decodes in parallel.
  Future<void> _scan() async {
    for (final file in widget.files.take(_listed)) {
      ImageDetails? details;
      try {
        details = await ImageToolsService.details(file);
      } on Object catch (e) {
        developer.log(
          'Scan failed for ${file.name}: $e',
          name: 'StripMetadata',
        );
      }
      if (!mounted) return;
      setState(() => _found[file.path] = details);
    }
  }

  Future<void> _save() => runTask(
    context,
    work: (progress) => ImageToolsService.stripMetadata(
      files: widget.files,
      onProgress: progress,
    ),
    onCancel: ImageToolsService.cancel,
  );

  @override
  Widget build(BuildContext context) {
    final count = widget.files.length;
    return ToolScaffold(
      title: 'Remove hidden data',
      subtitle: count == 1 ? widget.files.first.name : '$count photos',
      actionLabel: count == 1 ? 'Save clean copy' : 'Save $count clean copies',
      onAction: _save,
      children: [
        Text(
          'Photos can carry the place they were taken, the date and the phone '
          'model. Clean copies keep the picture exactly as it is.',
          style: AppTheme.body,
        ),
        const SizedBox(height: 24),
        const SectionLabel('Found in your photos'),
        BrutalBox(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final (i, file) in widget.files.take(_listed).indexed) ...[
                if (i > 0) const Divider(),
                _row(file),
              ],
            ],
          ),
        ),
        if (count > _listed) ...[
          const SizedBox(height: 8),
          Text(
            'And ${count - _listed} more. All of them are cleaned.',
            style: AppTheme.caption,
          ),
        ],
      ],
    );
  }

  Widget _row(FileItem file) {
    final scanned = _found.containsKey(file.path);
    final details = _found[file.path];
    final String status;
    if (!scanned) {
      status = 'Checking';
    } else if (details == null) {
      status = 'Could not check this file';
    } else {
      final parts = [
        if (details.hasLocation) 'Location',
        if (details.camera != null) 'Camera: ${details.camera}',
        if (details.takenAt != null) 'Date taken',
      ];
      status = parts.isEmpty
          ? (details.hasMetadata ? 'Other hidden data' : 'Nothing found')
          : parts.join(', ');
    }
    final warn = details?.hasLocation ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            warn ? Icons.location_on_outlined : Icons.image_outlined,
            color: warn ? AppTheme.errorInk : AppTheme.ink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body,
                ),
                Text(status, style: AppTheme.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
