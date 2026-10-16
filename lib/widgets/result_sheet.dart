import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/conversion_result.dart';
import '../models/file_item.dart';
import '../services/app_storage_service.dart';
import '../theme/app_theme.dart';
import 'brutal.dart';

Future<void> openResultFile(BuildContext context, String path) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await OpenFilex.open(path);
  if (result.type != ResultType.done) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.type == ResultType.noAppToOpen
              ? 'No app on this phone can open this file type.'
              : 'Could not open the file: ${result.message}',
        ),
      ),
    );
  }
}

Future<void> shareResultFiles(List<String> paths) async {
  if (paths.isEmpty) return;
  await SharePlus.instance.share(
    ShareParams(files: paths.map(XFile.new).toList()),
  );
}

Future<void> openOutputFolder(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await AppStorageService.openOutputFolder()) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Files are in ${AppStorageService.publicFolderLabel}'),
      ),
    );
  }
}

/// Size change as a tag: green when smaller, black when larger.
class SizeChangeTag extends StatelessWidget {
  final ConversionResult result;

  const SizeChangeTag({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final change = result.reductionPercentage;
    final smaller = change > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: smaller ? AppTheme.accent : AppTheme.surface,
        borderRadius: AppTheme.radiusSmall,
        border: Border.all(color: AppTheme.ink, width: AppTheme.stroke),
      ),
      child: Text(
        smaller
            ? '-${change.toStringAsFixed(0)}%'
            : '+${(-change).toStringAsFixed(0)}%',
        style: AppTheme.label.copyWith(
          color: smaller ? AppTheme.onAccent : AppTheme.ink,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class ResultSheet extends StatelessWidget {
  final List<ConversionResult> results;

  const ResultSheet({super.key, required this.results});

  static Future<void> show(
    BuildContext context,
    List<ConversionResult> results,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ResultSheet(results: results),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = results.where((r) => r.isSuccess).toList();
    final failed = results.where((r) => !r.isSuccess).toList();
    final before = done.fold<int>(0, (s, r) => s + r.originalSizeBytes);
    final after = done.fold<int>(0, (s, r) => s + r.convertedSizeBytes);
    final allPaths = [for (final r in done) ...r.outputPaths];

    final headline = failed.isEmpty
        ? (done.length == 1 ? 'DONE' : '${done.length} DONE')
        : (done.isEmpty
              ? 'FAILED'
              : '${done.length} DONE, ${failed.length} FAILED');

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline, style: AppTheme.display),
            if (done.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${FileItem.formatBytes(before)}  ->  ${FileItem.formatBytes(after)}',
                style: AppTheme.title.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Saved to ${AppStorageService.publicFolderLabel}',
                style: AppTheme.caption,
              ),
            ],
            const SizedBox(height: 16),
            for (final r in done) ...[
              _ResultRow(result: r),
              const SizedBox(height: 8),
            ],
            for (final r in failed) ...[
              BrutalBox(
                shadow: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.errorInk),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.sourceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.errorMessage ?? 'Unknown error',
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(color: AppTheme.errorInk),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (allPaths.isNotEmpty) ...[
                  Expanded(
                    child: BrutalButton(
                      label: 'Share',
                      icon: Icons.ios_share,
                      color: AppTheme.surface,
                      onPressed: () => shareResultFiles(allPaths),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: BrutalButton(
                    label: 'Done',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final ConversionResult result;

  const _ResultRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final multi = result.outputPaths.length > 1;
    return BrutalBox(
      shadow: false,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.targetName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${result.originalFormattedSize} -> ${result.convertedFormattedSize}',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              SizeChangeTag(result: result),
              IconButton(
                tooltip: multi ? 'Open folder' : 'Open',
                icon: Icon(multi ? Icons.folder_open : Icons.open_in_new),
                onPressed: () => multi
                    ? openOutputFolder(context)
                    : openResultFile(context, result.targetPath),
              ),
            ],
          ),
          if (result.note != null) ...[
            const SizedBox(height: 4),
            Text(
              result.note!,
              style: AppTheme.caption.copyWith(color: AppTheme.ink),
            ),
          ],
        ],
      ),
    );
  }
}
