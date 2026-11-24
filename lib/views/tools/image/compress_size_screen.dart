// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/file_item.dart';
import '../../../services/image/image_tools_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/brutal.dart';
import '../../../widgets/task_runner.dart';
import '../../../widgets/tool_scaffold.dart';

/// Compress photos to fit an upload limit given in KB.
class CompressSizeScreen extends StatefulWidget {
  final List<FileItem> files;

  const CompressSizeScreen({super.key, required this.files});

  @override
  State<CompressSizeScreen> createState() => _CompressSizeScreenState();
}

class _CompressSizeScreenState extends State<CompressSizeScreen> {
  /// Common upload limits in KB; 0 stands for a custom value.
  static const _limits = [50, 100, 200, 500, 1024, 0];
  static const _formats = ['jpg', 'webp'];

  int _limit = 100;
  String _format = 'jpg';
  final _custom = TextEditingController();

  @override
  void initState() {
    super.initState();
    _custom.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  int? get _targetKb {
    if (_limit != 0) return _limit;
    final v = int.tryParse(_custom.text);
    return v == null || v < 5 ? null : v;
  }

  String _label(int kb) => switch (kb) {
    0 => 'OTHER',
    1024 => '1 MB',
    _ => '$kb KB',
  };

  Future<void> _save(int kb) => runTask(
    context,
    work: (progress) => ImageToolsService.compressToSize(
      files: widget.files,
      targetBytes: kb * 1024,
      extension: _format,
      onProgress: progress,
    ),
    onCancel: ImageToolsService.cancel,
  );

  @override
  Widget build(BuildContext context) {
    final kb = _targetKb;
    final count = widget.files.length;
    return ToolScaffold(
      title: 'Compress to size',
      subtitle: count == 1 ? widget.files.first.name : '$count photos',
      actionLabel: kb == null
          ? 'Enter a size'
          : 'Make ${count == 1 ? 'it' : 'each'} under ${_label(kb)}',
      onAction: kb == null ? null : () => _save(kb),
      children: [
        const SectionLabel('Keep each photo under'),
        ChoiceRow<int>(
          values: _limits,
          selected: _limit,
          labelOf: _label,
          onSelected: (v) => setState(() => _limit = v),
        ),
        if (_limit == 0) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _custom,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTheme.body,
            decoration: InputDecoration(
              hintText: 'Size limit',
              suffixText: 'KB',
              suffixStyle: AppTheme.caption,
            ),
          ),
        ],
        const SizedBox(height: 24),
        const SectionLabel('Save as'),
        ChoiceRow<String>(
          values: _formats,
          selected: _format,
          labelOf: (f) => f.toUpperCase(),
          onSelected: (f) => setState(() => _format = f),
        ),
        const SizedBox(height: 8),
        Text(
          _format == 'jpg'
              ? 'JPG is accepted by every website and form.'
              : 'WEBP looks better at the same size, but some forms reject it.',
          style: AppTheme.caption,
        ),
        const SizedBox(height: 16),
        Text(
          'The best quality that fits is chosen for you. A photo is made '
          'smaller in pixels only when quality alone cannot reach the limit.',
          style: AppTheme.caption,
        ),
      ],
    );
  }
}
