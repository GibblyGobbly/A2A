import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../theme/app_theme.dart';

class FilePickerBox extends StatelessWidget {
  final List<FileItem> selectedFiles;
  final VoidCallback onTap;
  final VoidCallback onClearAll;
  final ValueChanged<int>? onRemoveIndex;
  final String title;
  final String subtitle;

  const FilePickerBox({
    super.key,
    required this.selectedFiles,
    required this.onTap,
    required this.onClearAll,
    this.onRemoveIndex,
    this.title = 'Select Files to Convert',
    this.subtitle = 'Tap to select one or multiple files from device',
  });

  @override
  Widget build(BuildContext context) {
    if (selectedFiles.isEmpty) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderBlue, width: 1.5),
          ),
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
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: AppTheme.primaryBlue,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalBytes = selectedFiles.fold<int>(0, (sum, f) => sum + f.sizeInBytes);
    final formattedTotalSize = _formatBytes(totalBytes);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentBlue, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${selectedFiles.length} ${selectedFiles.length == 1 ? 'file' : 'files'} selected',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '($formattedTotalSize)',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryBlue, size: 20),
                    onPressed: onTap,
                    tooltip: 'Add more files',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.textMuted, size: 20),
                    onPressed: onClearAll,
                    tooltip: 'Clear all',
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: selectedFiles.length,
              separatorBuilder: (_, _) => const Divider(height: 8),
              itemBuilder: (context, index) {
                final file = selectedFiles[index];
                return Row(
                  children: [
                    Icon(
                      _getCategoryIcon(file.category),
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(
                            '${file.extension.toUpperCase()} • ${file.formattedSize}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (onRemoveIndex != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                        onPressed: () => onRemoveIndex!(index),
                        tooltip: 'Remove',
                      ),
                  ],
                );
              },
            ),
          ),
        ],
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

  IconData _getCategoryIcon(FileCategory category) {
    switch (category) {
      case FileCategory.image:
        return Icons.image_outlined;
      case FileCategory.video:
        return Icons.videocam_outlined;
      case FileCategory.audio:
        return Icons.audiotrack_outlined;
      case FileCategory.document:
        return Icons.description_outlined;
      case FileCategory.archive:
        return Icons.folder_zip_outlined;
      case FileCategory.unknown:
        return Icons.insert_drive_file_outlined;
    }
  }
}
