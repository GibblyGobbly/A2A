// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../../models/file_item.dart';
import '../../../models/image_edit.dart';
import '../../../services/image/image_tools_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/brutal.dart';
import '../../../widgets/crop_frame.dart';
import '../../../widgets/fitted_preview.dart';
import '../../../widgets/gesture_safe_padding.dart';
import '../../../widgets/preview_image.dart';
import '../../../widgets/task_runner.dart';
import '../../../widgets/tool_scaffold.dart';

class CropScreen extends StatefulWidget {
  final FileItem file;

  const CropScreen({super.key, required this.file});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  CropAspect _aspect = CropAspect.free;
  NormRect? _rect;
  double? _imageAspect;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    PreviewImage.aspectRatio(widget.file.path).then((ratio) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _imageAspect = ratio;
        if (ratio != null) _rect = CropFrame.fitted(_aspect.ratio, ratio);
      });
    });
  }

  void _setAspect(CropAspect aspect) {
    setState(() {
      _aspect = aspect;
      final imageAspect = _imageAspect;
      if (imageAspect != null) {
        _rect = CropFrame.fitted(aspect.ratio, imageAspect);
      }
    });
  }

  Future<void> _save() async {
    final rect = _rect;
    if (rect == null) return;
    await runTask(
      context,
      work: (progress) => ImageToolsService.applyEdit(
        files: [widget.file],
        op: CropOp(rect),
        suffix: '_crop',
        onProgress: progress,
      ),
      onCancel: ImageToolsService.cancel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Crop',
      subtitle: widget.file.name,
      scrollable: false,
      actionLabel: 'Save cropped copy',
      onAction: _rect == null ? null : _save,
      children: [
        Expanded(child: GestureSafePadding(child: _preview())),
        const SizedBox(height: 16),
        const SectionLabel('Shape'),
        ChoiceRow<CropAspect>(
          values: CropAspect.values,
          selected: _aspect,
          labelOf: (a) => a.label,
          onSelected: _setAspect,
        ),
      ],
    );
  }

  Widget _preview() {
    final ratio = _imageAspect;
    final rect = _rect;
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.ink));
    }
    if (ratio == null || rect == null) return const PreviewUnavailable();
    return FittedPreview(
      path: widget.file.path,
      aspectRatio: ratio,
      overlayBleed: FittedPreview.handleBleed,
      overlay: (size) => CropFrame(
        size: size,
        inset: FittedPreview.handleBleed,
        rect: rect,
        ratio: _aspect.ratio,
        onChanged: (r) => setState(() => _rect = r),
      ),
    );
  }
}
