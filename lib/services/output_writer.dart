// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';
import 'dart:typed_data';
import '../models/conversion_result.dart';
import '../models/file_item.dart';
import 'app_storage_service.dart';

/// Saves finished output into the output folder and describes the outcome.
class OutputWriter {
  /// Writes [bytes] as `<source name><suffix>.<extension>`, makes it visible in
  /// gallery apps and returns the result. A partial file is deleted on error.
  static Future<ConversionResult> saveBytes({
    required FileItem source,
    required Uint8List bytes,
    required String extension,
    required String suffix,
    required DateTime startedAt,
    String? note,
  }) async {
    String? path;
    try {
      path = await AppStorageService.generateOutputPath(
        baseName: '${source.baseName}$suffix',
        extension: extension,
      );
      await File(path).writeAsBytes(bytes, flush: true);
      await AppStorageService.notifyMediaScanner(path);
      return ConversionResult(
        sourcePath: source.path,
        sourceName: source.name,
        targetPath: path,
        targetName: path.split('/').last,
        targetExtension: extension,
        originalSizeBytes: source.sizeInBytes,
        convertedSizeBytes: bytes.length,
        duration: DateTime.now().difference(startedAt),
        timestamp: DateTime.now(),
        note: note,
      );
    } on FileSystemException catch (e) {
      if (path != null) await AppStorageService.deleteQuietly(File(path));
      return failure(source, extension, startedAt, describe(e));
    }
  }

  static ConversionResult failure(
    FileItem source,
    String extension,
    DateTime startedAt,
    String message,
  ) => ConversionResult.failure(
    sourcePath: source.path,
    sourceName: source.name,
    targetExtension: extension,
    originalSizeBytes: source.sizeInBytes,
    startedAt: startedAt,
    errorMessage: message,
  );

  /// A message a person can act on, for any error thrown while processing.
  static String describe(Object e) {
    if (e is FormatException) return e.message;
    if (e is FileSystemException) {
      return 'File error: ${e.message} ${e.path ?? ''}'.trim();
    }
    if (e is UnsupportedError) return e.message ?? 'Unsupported format';
    if (e is OutOfMemoryError) {
      return 'The image is too large for this phone to edit.';
    }
    return e.toString();
  }
}
