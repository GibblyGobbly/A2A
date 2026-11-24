// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../../models/file_item.dart';
import '../../../models/image_edit.dart';
import '../../../services/image/image_tools_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/fitted_preview.dart';
import '../../../widgets/icon_label_button.dart';
import '../../../widgets/preview_image.dart';
import '../../../widgets/task_runner.dart';
import '../../../widgets/tool_scaffold.dart';

/// Rotate and flip. The same change is applied to every picked photo; the
/// first one is previewed.
class RotateScreen extends StatefulWidget {
  final List<FileItem> files;

  const RotateScreen({super.key, required this.files});

  @override
  State<RotateScreen> createState() => _RotateScreenState();
}

class _RotateScreenState extends State<RotateScreen> {
  RotateFlipOp _op = const RotateFlipOp();

  void _turn(int by) => setState(() {
    _op = RotateFlipOp(
      quarterTurns: (_op.quarterTurns + by) % 4,
      flipHorizontal: _op.flipHorizontal,
      flipVertical: _op.flipVertical,
    );
  });

  /// Mirrors as seen on screen. Flips apply before the rotation, so after a
  /// quarter turn a left-right mirror is a top-bottom flip of the original.
  void _mirror({required bool sideways}) => setState(() {
    final flipsSourceX = sideways != _op.quarterTurns.isOdd;
    _op = RotateFlipOp(
      quarterTurns: _op.quarterTurns,
      flipHorizontal: _op.flipHorizontal != flipsSourceX,
      flipVertical: _op.flipVertical != !flipsSourceX,
    );
  });

  Future<void> _save() => runTask(
    context,
    work: (progress) => ImageToolsService.applyEdit(
      files: widget.files,
      op: _op,
      suffix: '_rotated',
      onProgress: progress,
    ),
    onCancel: ImageToolsService.cancel,
  );

  @override
  Widget build(BuildContext context) {
    final count = widget.files.length;
    final first = widget.files.first;
    return ToolScaffold(
      title: 'Rotate and flip',
      subtitle: count == 1 ? first.name : '$count photos, same change to all',
      scrollable: false,
      actionLabel: count == 1 ? 'Save copy' : 'Save $count copies',
      onAction: _op.isIdentity ? null : _save,
      children: [
        Expanded(
          child: AspectLoader(
            path: first.path,
            builder: (context, ratio) => FittedPreview(
              path: first.path,
              aspectRatio: ratio,
              quarterTurns: _op.quarterTurns,
              flipHorizontal: _op.flipHorizontal,
              flipVertical: _op.flipVertical,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: IconLabelButton(
                icon: Icons.rotate_left,
                label: 'Left',
                onPressed: () => _turn(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: IconLabelButton(
                icon: Icons.rotate_right,
                label: 'Right',
                onPressed: () => _turn(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: IconLabelButton(
                icon: Icons.flip,
                label: 'Mirror',
                onPressed: () => _mirror(sideways: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: IconLabelButton(
                icon: Icons.swap_vert,
                label: 'Flip',
                onPressed: () => _mirror(sideways: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _op.isIdentity ? 'No change yet.' : _describe(),
          style: AppTheme.caption,
        ),
      ],
    );
  }

  String _describe() {
    final parts = <String>[
      if (_op.quarterTurns != 0)
        'Turned ${_op.quarterTurns * 90} degrees right',
      if (_op.flipHorizontal || _op.flipVertical) 'mirrored',
    ];
    final text = parts.join(', ');
    return '${text[0].toUpperCase()}${text.substring(1)}.';
  }
}
