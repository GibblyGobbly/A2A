import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/conversion_options.dart';
import '../models/conversion_target.dart';
import '../models/file_item.dart';
import '../services/av1_encoder_service.dart';
import '../services/conversion_service.dart';
import '../services/format_catalog.dart';
import '../services/share_intake_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal.dart';
import '../widgets/file_list.dart';
import '../widgets/progress_dialog.dart';
import '../widgets/result_sheet.dart';
import '../widgets/settings_panel.dart';
import 'settings_screen.dart';

/// One tool page (image, video, audio or documents): pick files, choose an
/// output, adjust settings, convert. State is kept while swiping between pages.
class ToolScreen extends StatefulWidget {
  final FileCategory category;

  const ToolScreen({super.key, required this.category});

  static String headline(FileCategory c) => switch (c) {
    FileCategory.image =>
      'Compress, resize and convert photos. Turn images into PDFs.',
    FileCategory.video => 'Shrink videos, change format or pull out the audio.',
    FileCategory.audio =>
      'Convert and compress music, voice notes and recordings.',
    FileCategory.document =>
      'PDF, Word, PowerPoint, text and Markdown. Merge PDFs.',
    FileCategory.unknown => '',
  };

  @override
  State<ToolScreen> createState() => _ToolScreenState();
}

class _ToolScreenState extends State<ToolScreen>
    with AutomaticKeepAliveClientMixin {
  final List<FileItem> _files = [];
  ConversionTarget? _target;
  ConversionOptions _options = const ConversionOptions();
  bool _hasAv1 = false;
  bool _picking = false;

  FileCategory get _category => widget.category;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (_category == FileCategory.video) {
      Av1EncoderService.isAvailable().then((value) {
        if (mounted && value) setState(() => _hasAv1 = true);
      });
    }
    ShareIntakeService.pending.addListener(_takeShared);
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeShared());
  }

  @override
  void dispose() {
    ShareIntakeService.pending.removeListener(_takeShared);
    super.dispose();
  }

  void _takeShared() {
    final shared = ShareIntakeService.take(_category);
    if (shared.isNotEmpty && mounted) _addFiles(shared);
  }

  List<ConversionTarget> get _targets =>
      FormatCatalog.targetsFor(_files, av1Available: _hasAv1);

  void _addFiles(List<FileItem> items) {
    setState(() {
      for (final item in items) {
        if (!_files.any((f) => f.path == item.path)) _files.add(item);
      }
      _syncTarget();
    });
  }

  /// Keeps the selected target valid for the current files.
  void _syncTarget() {
    final targets = _targets;
    if (_target == null || !targets.any((t) => t.id == _target!.id)) {
      _target = FormatCatalog.defaultTarget(_files, targets);
    } else {
      _target = targets.firstWhere((t) => t.id == _target!.id);
    }
  }

  void _selectTarget(ConversionTarget target) {
    setState(() {
      // GIF width and video resolution share one setting; reset it when switching between them.
      if ((target.settings == TargetSettings.gif) !=
          (_target?.settings == TargetSettings.gif)) {
        _options = _options.copyWith(maxVideoShortEdge: () => null);
      }
      _target = target;
    });
  }

  Future<void> _pick() async {
    final messenger = ScaffoldMessenger.of(context);
    final type = switch (_category) {
      FileCategory.image => FileType.image,
      FileCategory.video => FileType.video,
      FileCategory.audio => FileType.audio,
      _ => FileType.custom,
    };
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        type: type,
        allowedExtensions: type == FileType.custom
            ? FormatCatalog.inputExtensionsFor(_category)
            : null,
        onFileLoading: (status) {
          if (mounted) {
            setState(() => _picking = status == FilePickerStatus.picking);
          }
        },
      );
    } on PlatformException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open the file picker: ${e.message}')),
      );
      return;
    } finally {
      if (mounted) setState(() => _picking = false);
    }

    final items = <FileItem>[];
    var skipped = 0;
    for (final p in picked) {
      final path = p.path;
      if (path == null) continue;
      final item = FileItem.fromFile(File(path));
      if (item.category == _category) {
        items.add(item);
      } else {
        skipped++;
      }
    }
    if (skipped > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Skipped $skipped unsupported ${skipped == 1 ? 'file' : 'files'}.',
          ),
        ),
      );
    }
    if (items.isNotEmpty) _addFiles(items);
  }

  void _remove(int index) {
    setState(() {
      _files.removeAt(index);
      _syncTarget();
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      _files.insert(newIndex, _files.removeAt(oldIndex));
    });
  }

  Future<void> _convert() async {
    final target = _target;
    if (target == null || _files.isEmpty) return;
    final state = ValueNotifier<({double? progress, String status})>((
      progress: null,
      status: 'Starting',
    ));
    var cancelled = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProgressDialog(
        state: state,
        onCancel: () {
          cancelled = true;
          state.value = (progress: null, status: 'Cancelling');
          ConversionService.cancel();
        },
      ),
    );

    final results = await ConversionService.run(
      files: List.of(_files),
      target: target,
      options: _options,
      onProgress: (p, status) => state.value = (progress: p, status: status),
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    state.dispose();
    if (cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancelled. Partial files were deleted.')),
      );
      if (results.isEmpty) return;
    }
    await ResultSheet.show(context, results);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    AppTheme.watch(context);
    final targets = _targets;
    final target = _target;
    final duration = motion(context, 200);
    final groups = <String, List<ConversionTarget>>{};
    for (final t in targets) {
      groups.putIfAbsent(t.group, () => []).add(t);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _header(),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: duration,
                child: _files.isEmpty
                    ? _emptyState()
                    : FileList(
                        key: const ValueKey('files'),
                        files: _files,
                        onReorder: _reorder,
                        onRemove: _remove,
                      ),
              ),
              if (_files.isNotEmpty && target != null) ...[
                for (final entry in groups.entries) ...[
                  const SizedBox(height: 16),
                  SectionLabel(entry.key),
                  ChoiceRow<ConversionTarget>(
                    values: entry.value,
                    selected: target,
                    labelOf: (t) => t.label,
                    onSelected: _selectTarget,
                  ),
                ],
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: duration,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, ?current],
                  ),
                  child: Text(
                    target.hint,
                    key: ValueKey(target.id),
                    style: AppTheme.caption,
                  ),
                ),
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
              ] else if (_files.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'These files have no common output format. Remove some to continue.',
                  style: AppTheme.body,
                ),
              ],
            ],
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: Curves.easeOut,
          child: _files.isEmpty || target == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 19, 12),
                  child: BrutalButton(
                    label: _actionLabel(target),
                    icon: Icons.bolt,
                    onPressed: _convert,
                  ),
                ),
        ),
      ],
    );
  }

  /// One line: tool name, file count, and add / clear actions.
  Widget _header() {
    final total = FileItem.formatBytes(
      _files.fold<int>(0, (s, f) => s + f.sizeInBytes),
    );
    return Row(
      children: [
        Container(
          width: 12,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            border: Border.all(color: AppTheme.ink, width: AppTheme.stroke),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_category.label, style: AppTheme.display),
              if (_files.isNotEmpty)
                Text(
                  '${_files.length} ${_files.length == 1 ? 'file' : 'files'}, $total',
                  style: AppTheme.caption,
                ),
            ],
          ),
        ),
        if (_files.isNotEmpty) ...[
          BrutalIconButton(
            icon: Icons.add,
            tooltip: 'Add files',
            onPressed: _picking ? null : _pick,
          ),
          const SizedBox(width: 8),
          BrutalIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Clear all',
            onPressed: () => setState(() {
              _files.clear();
              _target = null;
            }),
          ),
          const SizedBox(width: 8),
        ],
        BrutalIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onPressed: () => SettingsScreen.open(context),
        ),
      ],
    );
  }

  String _actionLabel(ConversionTarget target) {
    if (target.combinesInputs) {
      return '${target.label} (${_files.length} files)';
    }
    return _files.length == 1
        ? 'Convert to ${target.label}'
        : 'Convert ${_files.length} to ${target.label}';
  }

  Widget _emptyState() {
    final formats = FormatCatalog.inputExtensionsFor(_category)
        .where((e) => e != 'jpeg' && e != 'tif' && e != 'aif' && e != 'oga')
        .map((e) => e.toUpperCase());
    return Column(
      key: const ValueKey('empty'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ToolScreen.headline(_category), style: AppTheme.body),
        const SizedBox(height: 12),
        Pressable(
          onTap: _picking ? null : _pick,
          raised: true,
          padding: const EdgeInsets.all(16),
          semanticLabel: 'Pick ${_category.label.toLowerCase()} files',
          child: Row(
            children: [
              _picking
                  ? SizedBox(
                      width: 44,
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppTheme.ink,
                        ),
                      ),
                    )
                  : CategoryTile(
                      color: AppTheme.accent,
                      icon: Icons.add,
                      size: 44,
                    ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _picking ? 'LOADING FILES' : 'PICK FILES',
                      style: AppTheme.label.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'One or many. Or share them to A2A from any app.',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(formats.join('  '), style: AppTheme.caption),
      ],
    );
  }
}
