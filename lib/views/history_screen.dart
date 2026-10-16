import 'dart:io';
import 'package:flutter/material.dart';
import '../models/conversion_result.dart';
import '../models/file_item.dart';
import '../services/app_storage_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brutal.dart';
import '../widgets/result_sheet.dart';
import 'settings_screen.dart';

enum _DeleteChoice { listOnly, files }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _search = TextEditingController();
  FileCategory? _filter;

  /// Keys of selected items. Selection mode is on while this is not empty.
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _key(ConversionResult r) =>
      '${r.targetPath}|${r.timestamp.microsecondsSinceEpoch}';

  List<ConversionResult> _visible(List<ConversionResult> all) {
    final query = _search.text.trim().toLowerCase();
    return all.where((r) {
      if (_filter != null &&
          FileItem.detectCategory(r.targetExtension) != _filter) {
        return false;
      }
      if (query.isEmpty) return true;
      return r.targetName.toLowerCase().contains(query) ||
          r.sourceName.toLowerCase().contains(query) ||
          r.targetExtension.toLowerCase() == query;
    }).toList();
  }

  void _toggle(ConversionResult item) {
    Haptics.select();
    setState(() {
      final key = _key(item);
      if (!_selected.remove(key)) _selected.add(key);
    });
  }

  List<ConversionResult> _selectedItems() => HistoryService
      .historyNotifier
      .value
      .where((r) => _selected.contains(_key(r)))
      .toList();

  Future<void> _shareSelected() async {
    final paths = [
      for (final r in _selectedItems())
        ...r.outputPaths.where((p) => File(p).existsSync()),
    ];
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The selected files no longer exist.')),
      );
      return;
    }
    await shareResultFiles(paths);
  }

  Future<void> _deleteSelected() async {
    final items = _selectedItems();
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'DELETE ${items.length} ${items.length == 1 ? 'ITEM' : 'ITEMS'}?',
          style: AppTheme.title,
        ),
        content: Text(
          'Remove them from this list only, or also delete the files from your phone.',
          style: AppTheme.body,
        ),
        actionsOverflowDirection: VerticalDirection.up,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: AppTheme.label),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DeleteChoice.listOnly),
            child: Text('REMOVE FROM LIST', style: AppTheme.label),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DeleteChoice.files),
            child: Text(
              'DELETE FILES',
              style: AppTheme.label.copyWith(color: AppTheme.errorInk),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    var failed = 0;
    if (choice == _DeleteChoice.files) {
      for (final item in items) {
        for (final path in item.outputPaths) {
          final file = File(path);
          await AppStorageService.deleteQuietly(file);
          if (file.existsSync()) {
            failed++;
          } else {
            await AppStorageService.notifyMediaScanner(path);
          }
        }
      }
    }
    await HistoryService.deleteItems(items);
    setState(_selected.clear);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed > 0
              ? 'Removed. $failed files could not be deleted.'
              : choice == _DeleteChoice.files
              ? 'Deleted ${items.length} ${items.length == 1 ? 'item' : 'items'}.'
              : 'Removed ${items.length} from the list.',
        ),
      ),
    );
  }

  void _remove(ConversionResult item) {
    final index = HistoryService.historyNotifier.value.indexOf(item);
    HistoryService.deleteItem(item);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${item.targetName} from the list'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => HistoryService.restoreItem(item, index),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    AppTheme.watch(context);
    return ValueListenableBuilder<List<ConversionResult>>(
      valueListenable: HistoryService.historyNotifier,
      builder: (context, history, _) {
        final visible = _visible(history);
        // Drop selections for items that no longer exist.
        final keys = history.map(_key).toSet();
        _selected.removeWhere((k) => !keys.contains(k));
        final duration = motion(context, 180);

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList.list(
                children: [
                  AnimatedSwitcher(
                    duration: duration,
                    child: _selecting
                        ? _selectionBar(visible)
                        : _header(history),
                  ),
                  const SizedBox(height: 12),
                  if (history.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            style: AppTheme.body,
                            decoration: InputDecoration(
                              hintText: 'Search files',
                              prefixIcon: Icon(
                                Icons.search,
                                color: AppTheme.ink,
                              ),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close),
                                      tooltip: 'Clear search',
                                      onPressed: _search.clear,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FilterButton(
                          selected: _filter,
                          onSelected: (c) => setState(() => _filter = c),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!_selecting)
                      Text(
                        'Long-press to select several.',
                        style: AppTheme.caption,
                      ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            if (history.isNotEmpty && visible.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Text('Nothing matches.', style: AppTheme.body),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = visible[index];
                  final row = _HistoryRow(
                    item: item,
                    selecting: _selecting,
                    selected: _selected.contains(_key(item)),
                    onToggle: () => _toggle(item),
                  );
                  if (_selecting) return row;
                  return Dismissible(
                    key: ValueKey(_key(item)),
                    background: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.ink,
                        borderRadius: AppTheme.radius,
                      ),
                    ),
                    onDismissed: (_) => _remove(item),
                    child: row,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(List<ConversionResult> history) {
    final saved = history.fold<int>(
      0,
      (s, r) =>
          s + (r.originalSizeBytes - r.convertedSizeBytes).clamp(0, 1 << 62),
    );
    return Row(
      key: const ValueKey('header'),
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
              Text('FILES', style: AppTheme.display),
              Text(
                history.isEmpty
                    ? 'Your converted files will show up here.'
                    : '${history.length} conversions, ${FileItem.formatBytes(saved)} saved',
                style: AppTheme.caption,
              ),
            ],
          ),
        ),
        BrutalIconButton(
          icon: Icons.folder_open,
          tooltip: 'Open output folder',
          onPressed: () => openOutputFolder(context),
        ),
        const SizedBox(width: 8),
        BrutalIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onPressed: () => SettingsScreen.open(context),
        ),
      ],
    );
  }

  Widget _selectionBar(List<ConversionResult> visible) {
    final allVisibleSelected =
        visible.isNotEmpty && visible.every((r) => _selected.contains(_key(r)));
    return Row(
      key: const ValueKey('selection'),
      children: [
        BrutalIconButton(
          icon: Icons.close,
          tooltip: 'Cancel selection',
          onPressed: () => setState(_selected.clear),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${_selected.length} SELECTED',
            style: AppTheme.label.copyWith(fontSize: 15),
          ),
        ),
        BrutalIconButton(
          icon: allVisibleSelected ? Icons.deselect : Icons.select_all,
          tooltip: allVisibleSelected ? 'Select none' : 'Select all',
          onPressed: () => setState(() {
            if (allVisibleSelected) {
              _selected.clear();
            } else {
              _selected.addAll(visible.map(_key));
            }
          }),
        ),
        const SizedBox(width: 8),
        BrutalIconButton(
          icon: Icons.ios_share,
          tooltip: 'Share selected',
          onPressed: _shareSelected,
        ),
        const SizedBox(width: 8),
        BrutalIconButton(
          icon: Icons.delete_outline,
          tooltip: 'Delete selected',
          onPressed: _deleteSelected,
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ConversionResult item;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

  const _HistoryRow({
    required this.item,
    required this.selecting,
    required this.selected,
    required this.onToggle,
  });

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    if (d.inDays < 7) return '${d.inDays} d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final category = FileItem.detectCategory(item.targetExtension);
    final multi = item.outputPaths.length > 1;
    final exists = File(item.targetPath).existsSync();
    final VoidCallback? open = exists
        ? () => multi
              ? openOutputFolder(context)
              : openResultFile(context, item.targetPath)
        : null;
    return Pressable(
      onTap: selecting ? onToggle : open,
      onLongPress: selecting ? null : onToggle,
      color: selected ? AppTheme.selection : AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
      semanticLabel: selecting
          ? '${selected ? 'Deselect' : 'Select'} ${item.targetName}'
          : 'Open ${item.targetName}',
      child: Row(
        children: [
          CategoryTile(
            color: selected ? AppTheme.surface : AppTheme.muted,
            icon: selected ? Icons.check : AppTheme.categoryIcon(category),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.targetName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  exists
                      ? '${item.convertedFormattedSize}  /  ${_ago(item.timestamp)}'
                      : 'File was deleted  /  ${_ago(item.timestamp)}',
                  style: AppTheme.caption.copyWith(color: AppTheme.ink),
                ),
              ],
            ),
          ),
          if (exists && item.originalSizeBytes > 0) SizeChangeTag(result: item),
          if (selecting)
            const SizedBox(width: 16)
          else
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share',
              onPressed: exists
                  ? () => shareResultFiles(item.outputPaths)
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Type filter shown beside the search field. The button turns yellow and
/// shows the type's icon while a filter is active.
class _FilterButton extends StatelessWidget {
  final FileCategory? selected;
  final ValueChanged<FileCategory?> onSelected;

  const _FilterButton({required this.selected, required this.onSelected});

  static const _options = <FileCategory?>[
    null,
    FileCategory.image,
    FileCategory.video,
    FileCategory.audio,
    FileCategory.document,
  ];

  @override
  Widget build(BuildContext context) {
    final active = selected;
    return PopupMenuButton<int>(
      tooltip: 'Filter by type',
      position: PopupMenuPosition.under,
      color: AppTheme.paper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radius,
        side: BorderSide(color: AppTheme.ink, width: AppTheme.strokeHeavy),
      ),
      onSelected: (i) => onSelected(_options[i]),
      itemBuilder: (context) => [
        for (var i = 0; i < _options.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 56,
            child: Row(
              children: [
                CategoryTile(
                  color: _options[i] == active
                      ? AppTheme.accent
                      : AppTheme.muted,
                  icon: _options[i] == null
                      ? Icons.select_all
                      : AppTheme.categoryIcon(_options[i]!),
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _options[i]?.label ?? 'ALL FILES',
                    style: AppTheme.label,
                  ),
                ),
                if (_options[i] == active) const Icon(Icons.check),
              ],
            ),
          ),
      ],
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active == null ? AppTheme.surface : AppTheme.accent,
          borderRadius: AppTheme.radius,
          border: Border.all(color: AppTheme.ink, width: AppTheme.stroke),
        ),
        child: Icon(
          active == null ? Icons.tune : AppTheme.categoryIcon(active),
          color: active == null ? AppTheme.ink : AppTheme.onAccent,
          semanticLabel: active == null
              ? 'Filter: all files'
              : 'Filter: ${active.label}',
        ),
      ),
    );
  }
}
