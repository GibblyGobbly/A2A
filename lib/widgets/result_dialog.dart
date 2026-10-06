import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/conversion_result.dart';
import '../services/app_storage_service.dart';
import '../theme/app_theme.dart';

class ResultDialog extends StatelessWidget {
  final List<ConversionResult> results;

  const ResultDialog({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    final successful = results.where((r) => r.isSuccess).toList();
    final totalOriginal = successful.fold<int>(0, (sum, r) => sum + r.originalSizeBytes);
    final totalConverted = successful.fold<int>(0, (sum, r) => sum + r.convertedSizeBytes);
    final totalReduction = totalOriginal > 0 ? ((totalOriginal - totalConverted) / totalOriginal) * 100.0 : 0.0;

    return Dialog(
      backgroundColor: AppTheme.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppTheme.lightBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppTheme.primaryBlue,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              successful.length == 1 ? 'Conversion Complete' : 'Batch Conversion Complete',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${successful.length} of ${results.length} files converted successfully',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Original Size', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text(_formatBytes(totalOriginal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Converted Size', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text(_formatBytes(totalConverted), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                    ],
                  ),
                  if (totalReduction > 0) ...[
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Space Saved', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.lightBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${totalReduction.toStringAsFixed(1)}% saved',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 18, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      successful.isNotEmpty
                          ? AppStorageService.getDisplayPath(successful.first.targetPath.split('/').sublist(0, successful.first.targetPath.split('/').length - 1).join('/'))
                          : 'Download/OmniConvert',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      if (successful.isNotEmpty) {
                        await AppStorageService.openFolder(successful.first.targetPath);
                      } else {
                        await AppStorageService.openFolder();
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Open Folder',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: successful.length,
                separatorBuilder: (_, _) => const Divider(height: 8),
                itemBuilder: (context, index) {
                  final item = successful[index];
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.targetName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textDark),
                            ),
                            Text(
                              AppStorageService.getDisplayPath(item.targetPath),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 15, color: AppTheme.textMuted),
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
                        icon: const Icon(Icons.folder_open_outlined, size: 16, color: AppTheme.primaryBlue),
                        onPressed: () => OpenFilex.open(item.targetPath),
                        tooltip: 'Open File',
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share All'),
                    onPressed: () {
                      final files = successful.map((r) => XFile(r.targetPath)).toList();
                      if (files.isNotEmpty) {
                        SharePlus.instance.share(ShareParams(files: files));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
