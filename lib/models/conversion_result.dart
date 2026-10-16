import 'file_item.dart';

class ConversionResult {
  final String sourcePath;
  final String sourceName;

  /// Primary output. For multi-file outputs (PDF pages as images) this is the first file.
  final String targetPath;
  final String targetName;
  final String targetExtension;

  /// Every file written by this conversion, including [targetPath].
  final List<String> outputPaths;
  final int originalSizeBytes;
  final int convertedSizeBytes;
  final Duration duration;
  final DateTime timestamp;
  final bool isSuccess;
  final String? errorMessage;

  /// Information the user should know about a successful conversion, such as an encoder fallback.
  final String? note;

  ConversionResult({
    required this.sourcePath,
    required this.sourceName,
    required this.targetPath,
    required this.targetName,
    required this.targetExtension,
    List<String>? outputPaths,
    required this.originalSizeBytes,
    required this.convertedSizeBytes,
    required this.duration,
    required this.timestamp,
    this.isSuccess = true,
    this.errorMessage,
    this.note,
  }) : outputPaths =
           outputPaths ?? (targetPath.isEmpty ? const [] : [targetPath]);

  factory ConversionResult.failure({
    required String sourcePath,
    required String sourceName,
    required String targetExtension,
    required int originalSizeBytes,
    required DateTime startedAt,
    required String errorMessage,
  }) {
    return ConversionResult(
      sourcePath: sourcePath,
      sourceName: sourceName,
      targetPath: '',
      targetName: '',
      targetExtension: targetExtension,
      outputPaths: const [],
      originalSizeBytes: originalSizeBytes,
      convertedSizeBytes: 0,
      duration: DateTime.now().difference(startedAt),
      timestamp: DateTime.now(),
      isSuccess: false,
      errorMessage: errorMessage,
    );
  }

  /// Positive when the output is smaller than the input, negative when larger.
  double get reductionPercentage {
    if (originalSizeBytes <= 0 || convertedSizeBytes <= 0) return 0.0;
    return (originalSizeBytes - convertedSizeBytes) / originalSizeBytes * 100.0;
  }

  String get originalFormattedSize => FileItem.formatBytes(originalSizeBytes);
  String get convertedFormattedSize => FileItem.formatBytes(convertedSizeBytes);

  Map<String, dynamic> toJson() {
    return {
      'sourcePath': sourcePath,
      'sourceName': sourceName,
      'targetPath': targetPath,
      'targetName': targetName,
      'targetExtension': targetExtension,
      'outputPaths': outputPaths,
      'originalSizeBytes': originalSizeBytes,
      'convertedSizeBytes': convertedSizeBytes,
      'durationMs': duration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'isSuccess': isSuccess,
      'errorMessage': errorMessage,
      'note': note,
    };
  }

  factory ConversionResult.fromJson(Map<String, dynamic> json) {
    final targetPath = json['targetPath'] as String? ?? '';
    final rawOutputs = json['outputPaths'];
    return ConversionResult(
      sourcePath: json['sourcePath'] ?? '',
      sourceName: json['sourceName'] ?? '',
      targetPath: targetPath,
      targetName: json['targetName'] ?? '',
      targetExtension: json['targetExtension'] ?? '',
      outputPaths: rawOutputs is List
          ? rawOutputs.whereType<String>().toList()
          : null,
      originalSizeBytes: json['originalSizeBytes'] ?? 0,
      convertedSizeBytes: json['convertedSizeBytes'] ?? 0,
      duration: Duration(milliseconds: json['durationMs'] ?? 0),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isSuccess: json['isSuccess'] ?? true,
      errorMessage: json['errorMessage'],
      note: json['note'],
    );
  }
}
