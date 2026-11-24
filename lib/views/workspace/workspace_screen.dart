// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../models/file_item.dart';
import '../../models/tool_info.dart';
import '../../services/file_pick_service.dart';
import '../../services/tool_catalog.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brutal.dart';
import '../../widgets/file_list.dart';
import 'tool_launcher.dart';
import 'tool_tile.dart';

/// The picked files and every tool that works on them, grouped by purpose.
class WorkspaceScreen extends StatefulWidget {
  final List<FileItem> files;

  const WorkspaceScreen({super.key, required this.files});

  static Future<void> open(BuildContext context, List<FileItem> files) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => WorkspaceScreen(files: files)),
      );

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final List<FileItem> _files = List.of(widget.files);
  bool _picking = false;

  FileCategory get _category => _files.first.category;

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await FilePickService.pick(
      category: _category,
      onLoading: (v) => mounted ? setState(() => _picking = v) : null,
    );
    if (!mounted) return;
    final error = outcome.error;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (outcome.skipped > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Skipped ${outcome.skipped} that ${outcome.skipped == 1 ? 'is' : 'are'} '
            'not ${_category.label.toLowerCase()} files.',
          ),
        ),
      );
    }
    setState(() {
      for (final f in outcome.files) {
        if (!_files.any((e) => e.path == f.path)) _files.add(f);
      }
    });
  }

  void _remove(int index) {
    setState(() => _files.removeAt(index));
    // Nothing left to work on: go back to the start page.
    if (_files.isEmpty) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.watch(context);
    if (_files.isEmpty) return const Scaffold();
    final tools = ToolCatalog.toolsFor(_files);
    final total = FileItem.formatBytes(
      _files.fold<int>(0, (s, f) => s + f.sizeInBytes),
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _header(total),
            const SizedBox(height: 16),
            FileList(
              files: _files,
              onReorder: (from, to) =>
                  setState(() => _files.insert(to, _files.removeAt(from))),
              onRemove: _remove,
              onRename: (i, name) =>
                  setState(() => _files[i] = _files[i].withBaseName(name)),
            ),
            for (final group in ToolGroup.values)
              ..._section(group, tools.where((t) => t.group == group).toList()),
          ],
        ),
      ),
    );
  }

  Widget _header(String total) {
    final count = _files.length;
    return Row(
      children: [
        BrutalIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_category.label, style: AppTheme.display),
              Text(
                '$count ${count == 1 ? 'file' : 'files'}, $total',
                style: AppTheme.caption,
              ),
            ],
          ),
        ),
        BrutalIconButton(
          icon: Icons.add,
          tooltip: 'Add files',
          onPressed: _picking ? null : _add,
        ),
      ],
    );
  }

  List<Widget> _section(ToolGroup group, List<ToolInfo> tools) {
    if (tools.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      SectionLabel(group.label),
      for (final (i, tool) in tools.indexed) ...[
        if (i > 0) const SizedBox(height: 8),
        ToolTile(
          tool: tool,
          blockedReason: ToolCatalog.blockedReason(tool, _files),
          onTap: () => ToolLauncher.open(context, tool.id, _files),
        ),
      ],
    ];
  }
}
