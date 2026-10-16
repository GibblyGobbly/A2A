import 'dart:io';

enum FileCategory {
  image('IMAGE'),
  video('VIDEO'),
  audio('AUDIO'),
  document('DOCS'),
  unknown('FILE');

  final String label;
  const FileCategory(this.label);
}

class FileItem {
  final String path;
  final String name;
  final String extension;
  final int sizeInBytes;
  final FileCategory category;
  final DateTime modifiedAt;

  FileItem({
    required this.path,
    required this.name,
    required this.extension,
    required this.sizeInBytes,
    required this.category,
    required this.modifiedAt,
  });

  factory FileItem.fromFile(File file) {
    final name = file.uri.pathSegments.lastWhere(
      (s) => s.isNotEmpty,
      orElse: () => 'file',
    );
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final stat = file.statSync();

    return FileItem(
      path: file.path,
      name: name,
      extension: ext,
      sizeInBytes: stat.size,
      category: detectCategory(ext),
      modifiedAt: stat.modified,
    );
  }

  /// File name without its extension.
  String get baseName =>
      name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;

  String get formattedSize => formatBytes(sizeInBytes);

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static const imageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
    'ico',
    'tiff',
    'tif',
    'heic',
    'heif',
    'avif',
  ];
  static const videoExtensions = [
    'mp4',
    'mkv',
    'webm',
    'avi',
    'mov',
    'flv',
    'wmv',
    'm4v',
    '3gp',
    'ts',
    'mts',
  ];
  static const audioExtensions = [
    'mp3',
    'wav',
    'aac',
    'flac',
    'ogg',
    'oga',
    'm4a',
    'wma',
    'opus',
    'aiff',
    'aif',
    'amr',
  ];
  static const documentExtensions = ['pdf', 'docx', 'pptx', 'txt', 'md'];

  static FileCategory detectCategory(String ext) {
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    if (imageExtensions.contains(cleanExt)) return FileCategory.image;
    if (videoExtensions.contains(cleanExt)) return FileCategory.video;
    if (audioExtensions.contains(cleanExt)) return FileCategory.audio;
    if (documentExtensions.contains(cleanExt)) return FileCategory.document;
    return FileCategory.unknown;
  }
}
