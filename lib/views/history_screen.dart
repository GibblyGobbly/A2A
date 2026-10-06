import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/conversion_result.dart';
import '../models/file_item.dart';
import '../services/app_storage_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    HistoryService.refreshHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversion History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => AppStorageService.openFolder(),
            tooltip: 'Open Storage Folder',
          ),
          ValueListenableBuilder<List<ConversionResult>>(
            valueListenable: HistoryService.historyNotifier,
            builder: (context, history, _) {
              if (history.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => HistoryService.clearHistory(),
                tooltip: 'Clear History',
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<ConversionResult>>(
        valueListenable: HistoryService.historyNotifier,
        builder: (context, history, _) {
          if (history.isEmpty) {
            return _buildEmptyState();
          }
          return _buildHistoryList(history);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppTheme.lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history, color: AppTheme.primaryBlue, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'No conversions yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Saved in Download/OmniConvert',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<ConversionResult> history) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = history[index];
        final cat = FileItem.detectCategory(item.targetExtension);
        final displayPath = AppStorageService.getDisplayPath(item.targetPath);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildThumbnail(item, cat),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.targetName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${item.originalFormattedSize} -> ${item.convertedFormattedSize}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            if (item.reductionPercentage > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '-${item.reductionPercentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.successGreen,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: AppTheme.textMuted),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: item.targetPath));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Path copied: ${item.targetPath}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Copy Path',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textMuted),
                    onPressed: () => HistoryService.deleteItem(item),
                    tooltip: 'Delete',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_outlined, size: 14),
                      label: const Text('Share', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        SharePlus.instance.share(ShareParams(files: [XFile(item.targetPath)]));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.folder_outlined, size: 14),
                      label: const Text('Folder', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => AppStorageService.openFolder(item.targetPath),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open_outlined, size: 14),
                      label: const Text('Open', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => OpenFilex.open(item.targetPath),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(ConversionResult item, FileCategory category) {
    final file = File(item.targetPath);
    final exists = file.existsSync();

    if (category == FileCategory.image && exists) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallbackIcon(category, item.targetExtension),
          ),
        ),
      );
    }

    if (category == FileCategory.video) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.play_circle_fill,
          color: Colors.white,
          size: 24,
        ),
      );
    }

    if (category == FileCategory.audio) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.lightBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.audiotrack,
          color: AppTheme.primaryBlue,
          size: 24,
        ),
      );
    }

    return _buildFallbackIcon(category, item.targetExtension);
  }

  Widget _buildFallbackIcon(FileCategory category, String ext) {
    IconData icon;
    switch (category) {
      case FileCategory.document:
        icon = Icons.description;
        break;
      case FileCategory.archive:
        icon = Icons.folder_zip;
        break;
      default:
        icon = Icons.insert_drive_file;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.lightBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: AppTheme.primaryBlue,
        size: 24,
      ),
    );
  }
}
