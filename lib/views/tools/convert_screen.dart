// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../models/conversion_options.dart';
import '../../models/conversion_target.dart';
import '../../models/file_item.dart';
import '../../services/av1_encoder_service.dart';
import '../../services/conversion_service.dart';
import '../../services/format_catalog.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brutal.dart';
import '../../widgets/settings_panel.dart';
import '../../widgets/task_runner.dart';
import '../../widgets/tool_scaffold.dart';

/// Pick an output format and its settings, then convert every file.
class ConvertScreen extends StatefulWidget {
  final List<FileItem> files;

  const ConvertScreen({super.key, required this.files});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  ConversionTarget? _target;
  ConversionOptions _options = const ConversionOptions();
  bool _hasAv1 = false;

  List<FileItem> get _files => widget.files;

  List<ConversionTarget> get _targets =>
      FormatCatalog.targetsFor(_files, av1Available: _hasAv1);

  @override
  void initState() {
    super.initState();
    _target = FormatCatalog.defaultTarget(_files, _targets);
    if (_files.first.category == FileCategory.video) {
      Av1EncoderService.isAvailable().then((value) {
        if (mounted && value) setState(() => _hasAv1 = true);
      });
    }
  }

  void _select(ConversionTarget target) {
    setState(() {
      // GIF width and video resolution share one setting; reset it when
      // switching between them.
      if ((target.settings == TargetSettings.gif) !=
          (_target?.settings == TargetSettings.gif)) {
        _options = _options.copyWith(maxVideoShortEdge: () => null);
      }
      _target = target;
    });
  }

  Future<void> _convert(ConversionTarget target) => runTask(
    context,
    work: (progress) => ConversionService.run(
      files: List.of(_files),
      target: target,
      options: _options,
      onProgress: progress,
    ),
    onCancel: ConversionService.cancel,
    // Video and audio encodes can take minutes; keep them alive with the
    // screen off.
    keepAlive: _files.first.category == FileCategory.document
        ? null
        : 'Converting ${_files.length == 1 ? _files.first.name : '${_files.length} files'}',
  );

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final total = FileItem.formatBytes(
      _files.fold<int>(0, (s, f) => s + f.sizeInBytes),
    );
    final count = _files.length;
    return ToolScaffold(
      title: 'Convert',
      subtitle: count == 1
          ? '${_files.first.name}, $total'
          : '$count files, $total',
      actionLabel: target == null ? null : _actionLabel(target),
      actionIcon: Icons.bolt,
      onAction: target == null ? null : () => _convert(target),
      children: target == null
          ? [
              Text(
                'These files have no common output format. Go back and '
                'remove some to continue.',
                style: AppTheme.body,
              ),
            ]
          : _controls(target),
    );
  }

  List<Widget> _controls(ConversionTarget target) {
    final duration = motion(context, 200);
    final groups = <String, List<ConversionTarget>>{};
    for (final t in _targets) {
      groups.putIfAbsent(t.group, () => []).add(t);
    }
    return [
      for (final entry in groups.entries) ...[
        SectionLabel(entry.key),
        ChoiceRow<ConversionTarget>(
          values: entry.value,
          selected: target,
          labelOf: (t) => t.label,
          onSelected: _select,
        ),
        const SizedBox(height: 16),
      ],
      Text(target.hint, style: AppTheme.caption),
      const SizedBox(height: 16),
      AnimatedSize(
        duration: duration,
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: SettingsPanel(
          target: target,
          options: _options,
          files: _files,
          onChanged: (o) => setState(() => _options = o),
        ),
      ),
    ];
  }

  String _actionLabel(ConversionTarget target) {
    if (target.combinesInputs) {
      return '${target.label} (${_files.length} files)';
    }
    return _files.length == 1
        ? 'Convert to ${target.label}'
        : 'Convert ${_files.length} to ${target.label}';
  }
}
