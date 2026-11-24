// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../models/file_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brutal.dart';

/// Two by two grid that opens the picker filtered to one kind of file.
class TypeGrid extends StatelessWidget {
  final ValueChanged<FileCategory> onPick;
  final bool enabled;

  const TypeGrid({super.key, required this.onPick, this.enabled = true});

  static const _types = [
    (FileCategory.image, 'Photos', 'Crop, resize, shrink'),
    (FileCategory.video, 'Videos', 'Shrink, convert, GIF'),
    (FileCategory.audio, 'Music', 'Convert, compress'),
    (FileCategory.document, 'PDF and docs', 'Convert, merge'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tile(int i) {
      final (category, label, hint) = _types[i];
      return Expanded(
        child: Pressable(
          onTap: enabled ? () => onPick(category) : null,
          padding: const EdgeInsets.all(12),
          semanticLabel: 'Pick $label',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryTile(
                color: AppTheme.muted,
                icon: AppTheme.categoryIcon(category),
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.caption,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [tile(0), const SizedBox(width: 8), tile(1)]),
        const SizedBox(height: 8),
        Row(children: [tile(2), const SizedBox(width: 8), tile(3)]),
      ],
    );
  }
}
