// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../../models/file_item.dart';
import '../../../models/image_edit.dart';
import '../../../services/image/image_tools_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/brutal.dart';
import '../../../widgets/fitted_preview.dart';
import '../../../widgets/gesture_safe_padding.dart';
import '../../../widgets/preview_image.dart';
import '../../../widgets/redact_canvas.dart';
import '../../../widgets/task_runner.dart';
import '../../../widgets/tool_scaffold.dart';

/// Hide parts of a photo with blur, pixels or a solid box.
class RedactScreen extends StatefulWidget {
  final FileItem file;

  const RedactScreen({super.key, required this.file});

  @override
  State<RedactScreen> createState() => _RedactScreenState();
}

class _RedactScreenState extends State<RedactScreen> {
  List<NormRect> _regions = const [];
  RedactStyle _style = RedactStyle.blur;

  Future<void> _save() => runTask(
    context,
    work: (progress) => ImageToolsService.applyEdit(
      files: [widget.file],
      op: RedactOp(_regions, _style),
      suffix: '_hidden',
      onProgress: progress,
    ),
    onCancel: ImageToolsService.cancel,
  );

  @override
  Widget build(BuildContext context) {
    final count = _regions.length;
    return ToolScaffold(
      title: 'Blur or hide parts',
      subtitle: widget.file.name,
      scrollable: false,
      actionLabel: count == 0
          ? 'Mark something to hide'
          : 'Save copy, $count ${count == 1 ? 'area' : 'areas'} hidden',
      onAction: count == 0 ? null : _save,
      children: [
        Expanded(
          child: GestureSafePadding(
            child: AspectLoader(
              path: widget.file.path,
              builder: (context, ratio) => FittedPreview(
                path: widget.file.path,
                aspectRatio: ratio,
                overlayBleed: FittedPreview.handleBleed,
                overlay: (size) => RedactCanvas(
                  size: size,
                  inset: FittedPreview.handleBleed,
                  regions: _regions,
                  onChanged: (r) => setState(() => _regions = r),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Drag over what to hide. Tap a box to remove it.',
                style: AppTheme.caption,
              ),
            ),
            BrutalIconButton(
              icon: Icons.undo,
              tooltip: 'Undo last box',
              onPressed: count == 0
                  ? null
                  : () => setState(
                      () => _regions = _regions.sublist(0, count - 1),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const SectionLabel('Hide with'),
        ChoiceRow<RedactStyle>(
          values: RedactStyle.values,
          selected: _style,
          labelOf: (s) => s.label,
          onSelected: (s) => setState(() => _style = s),
        ),
      ],
    );
  }
}
