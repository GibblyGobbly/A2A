import 'dart:io';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../theme/app_theme.dart';
import 'brutal.dart';

/// Selected inputs. Drag the handle to reorder (this is the page order when
/// combining into one PDF); swipe a row sideways to remove it. [onReorder]
/// receives the final index of the moved item.
class FileList extends StatelessWidget {
  final List<FileItem> files;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onRemove;

  const FileList({
    super.key,
    required this.files,
    required this.onReorder,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return BrutalBox(
      padding: EdgeInsets.zero,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: files.length,
        onReorderItem: onReorder,
        proxyDecorator: (child, _, _) =>
            Material(color: AppTheme.selection, child: child),
        itemBuilder: (context, index) {
          final file = files[index];
          return Dismissible(
            key: ValueKey(file.path),
            onDismissed: (_) => onRemove(index),
            background: Container(color: AppTheme.ink),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: index == files.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: AppTheme.ink,
                          width: AppTheme.stroke,
                        ),
                      ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
              child: Row(
                children: [
                  _Thumb(file: file),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${file.extension.toUpperCase()}  ${file.formattedSize}',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                  if (files.length > 1)
                    ReorderableDragStartListener(
                      index: index,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.drag_handle,
                          semanticLabel: 'Drag to reorder',
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove ${file.name}',
                    onPressed: () => onRemove(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final FileItem file;

  const _Thumb({required this.file});

  @override
  Widget build(BuildContext context) {
    final fallback = CategoryTile(
      color: AppTheme.muted,
      icon: AppTheme.categoryIcon(file.category),
    );
    if (file.category != FileCategory.image) return fallback;
    final pixels = (48 * MediaQuery.of(context).devicePixelRatio).round();
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.ink, width: AppTheme.stroke),
      ),
      child: Image.file(
        File(file.path),
        fit: BoxFit.cover,
        // Decode at thumbnail size; a 12 MP photo would otherwise take ~48 MB per row.
        cacheWidth: pixels,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
