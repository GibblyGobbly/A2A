// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/file_item.dart';
import '../../../models/image_details.dart';
import '../../../models/image_edit.dart';
import '../../../services/image/image_ops.dart';
import '../../../services/image/image_tools_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/brutal.dart';
import '../../../widgets/task_runner.dart';
import '../../../widgets/tool_scaffold.dart';

class ResizeScreen extends StatefulWidget {
  final List<FileItem> files;

  const ResizeScreen({super.key, required this.files});

  @override
  State<ResizeScreen> createState() => _ResizeScreenState();
}

class _ResizeScreenState extends State<ResizeScreen> {
  static const _percents = [25, 50, 75, 150, 200];

  ResizeMode _mode = ResizeMode.percent;
  int _percent = 50;
  final _width = TextEditingController();
  final _height = TextEditingController();

  /// Size of the first photo, for the before and after line.
  ImageDetails? _first;

  @override
  void initState() {
    super.initState();
    _width.addListener(_changed);
    _height.addListener(_changed);
    ImageToolsService.details(widget.files.first).then(
      (d) => mounted ? setState(() => _first = d) : null,
      // Only the before and after line needs this; the tool works without it.
      onError: (Object e) =>
          developer.log('Could not read size: $e', name: 'ResizeScreen'),
    );
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  int? _parse(TextEditingController c) {
    final v = int.tryParse(c.text);
    return v == null || v <= 0 ? null : v;
  }

  ResizeOp? get _op {
    if (_mode == ResizeMode.percent) return ResizeOp.percent(_percent);
    final w = _parse(_width);
    final h = _parse(_height);
    if (w == null && h == null) return null;
    return ResizeOp.pixels(width: w, height: h);
  }

  Future<void> _save(ResizeOp op) => runTask(
    context,
    work: (progress) => ImageToolsService.applyEdit(
      files: widget.files,
      op: op,
      suffix: '_resized',
      onProgress: progress,
    ),
    onCancel: ImageToolsService.cancel,
  );

  @override
  Widget build(BuildContext context) {
    final op = _op;
    final count = widget.files.length;
    return ToolScaffold(
      title: 'Resize',
      subtitle: count == 1 ? widget.files.first.name : '$count photos',
      actionLabel: count == 1 ? 'Save resized copy' : 'Resize $count photos',
      onAction: op == null ? null : () => _save(op),
      children: [
        const SectionLabel('Measure by'),
        ChoiceRow<ResizeMode>(
          values: ResizeMode.values,
          selected: _mode,
          labelOf: (m) => m.label,
          onSelected: (m) => setState(() => _mode = m),
        ),
        const SizedBox(height: 24),
        if (_mode == ResizeMode.percent)
          ..._percentControls()
        else
          _pixelFields(),
        const SizedBox(height: 16),
        if (op != null) Text(_preview(op), style: AppTheme.body),
      ],
    );
  }

  List<Widget> _percentControls() => [
    ValueSlider(
      label: 'Size',
      valueText: '$_percent%',
      value: _percent.toDouble(),
      min: 10,
      max: 200,
      divisions: 38,
      onChanged: (v) => setState(() => _percent = v.round()),
      minHint: 'Smaller',
      maxHint: 'Larger',
    ),
    const SizedBox(height: 8),
    ChoiceRow<int>(
      values: _percents,
      selected: _percent,
      labelOf: (p) => '$p%',
      onSelected: (p) => setState(() => _percent = p),
    ),
  ];

  Widget _pixelFields() {
    InputDecoration field(String hint) => InputDecoration(
      hintText: hint,
      suffixText: 'px',
      suffixStyle: AppTheme.caption,
    );
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _width,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                style: AppTheme.body,
                decoration: field('Width'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('x', style: AppTheme.title),
            ),
            Expanded(
              child: TextField(
                controller: _height,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                style: AppTheme.body,
                decoration: field('Height'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Fill one side to keep the shape. Fill both and the photo fits '
          'inside that box without stretching.',
          style: AppTheme.caption,
        ),
      ],
    );
  }

  String _preview(ResizeOp op) {
    final w = _first?.width;
    final h = _first?.height;
    if (w == null || h == null) return '';
    final out = ImageOps.resizedSize(w, h, op);
    final prefix = widget.files.length == 1 ? '' : 'First photo: ';
    return '$prefix$w x $h  ->  ${out.width} x ${out.height}';
  }
}
