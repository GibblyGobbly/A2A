import 'dart:io';

enum FileCategory {
  image,
  video,
  audio,
  document,
  archive,
  unknown;

  String get label {
    switch (this) {
      case FileCategory.image:
        return 'Image';
      case FileCategory.video:
        return 'Video';
      case FileCategory.audio:
        return 'Audio';
      case FileCategory.document:
        return 'Document';
      case FileCategory.archive:
        return 'Archive';
      case FileCategory.unknown:
        return 'Generic File';
    }
  }

  String get iconName {
    switch (this) {
      case FileCategory.image:
        return 'image';
      case FileCategory.video:
        return 'videocam';
      case FileCategory.audio:
        return 'audiotrack';
      case FileCategory.document:
        return 'description';
      case FileCategory.archive:
        return 'folder_zip';
      case FileCategory.unknown:
        return 'insert_drive_file';
    }
  }
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
    final name = file.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'file');
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

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static FileCategory detectCategory(String ext) {
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    if (['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'ico', 'tiff', 'tif', 'svg', 'heic', 'avif'].contains(cleanExt)) {
      return FileCategory.image;
    }
    if (['mp4', 'mkv', 'webm', 'avi', 'mov', 'flv', 'wmv', 'm4v', '3gp', 'ts'].contains(cleanExt)) {
      return FileCategory.video;
    }
    if (['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma', 'opus', 'aiff'].contains(cleanExt)) {
      return FileCategory.audio;
    }
    if (['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'md', 'rtf', 'csv', 'html', 'epub'].contains(cleanExt)) {
      return FileCategory.document;
    }
    if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2'].contains(cleanExt)) {
      return FileCategory.archive;
    }
    return FileCategory.unknown;
  }
}
