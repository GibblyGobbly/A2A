import 'dart:io';

class ConversionResult {
  final String sourcePath;
  final String sourceName;
  final String targetPath;
  final String targetName;
  final String targetExtension;
  final int originalSizeBytes;
  final int convertedSizeBytes;
  final Duration duration;
  final DateTime timestamp;
  final bool isSuccess;
  final String? errorMessage;

  ConversionResult({
    required this.sourcePath,
    required this.sourceName,
    required this.targetPath,
    required this.targetName,
    required this.targetExtension,
    required this.originalSizeBytes,
    required this.convertedSizeBytes,
    required this.duration,
    required this.timestamp,
    this.isSuccess = true,
    this.errorMessage,
  });

  double get reductionPercentage {
    if (originalSizeBytes <= 0 || convertedSizeBytes <= 0) return 0.0;
    final diff = originalSizeBytes - convertedSizeBytes;
    return (diff / originalSizeBytes) * 100.0;
  }

  String get originalFormattedSize => _formatBytes(originalSizeBytes);
  String get convertedFormattedSize => _formatBytes(convertedSizeBytes);

  File get file => File(targetPath);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toJson() {
    return {
      'sourcePath': sourcePath,
      'sourceName': sourceName,
      'targetPath': targetPath,
      'targetName': targetName,
      'targetExtension': targetExtension,
      'originalSizeBytes': originalSizeBytes,
      'convertedSizeBytes': convertedSizeBytes,
      'durationMs': duration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'isSuccess': isSuccess,
      'errorMessage': errorMessage,
    };
  }

  factory ConversionResult.fromJson(Map<String, dynamic> json) {
    return ConversionResult(
      sourcePath: json['sourcePath'] ?? '',
      sourceName: json['sourceName'] ?? '',
      targetPath: json['targetPath'] ?? '',
      targetName: json['targetName'] ?? '',
      targetExtension: json['targetExtension'] ?? '',
      originalSizeBytes: json['originalSizeBytes'] ?? 0,
      convertedSizeBytes: json['convertedSizeBytes'] ?? 0,
      duration: Duration(milliseconds: json['durationMs'] ?? 0),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isSuccess: json['isSuccess'] ?? true,
      errorMessage: json['errorMessage'],
    );
  }
}
