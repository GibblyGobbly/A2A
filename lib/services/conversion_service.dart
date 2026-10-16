import '../models/conversion_options.dart';
import '../models/conversion_result.dart';
import '../models/conversion_target.dart';
import '../models/file_item.dart';
import 'document_converter_service.dart';
import 'history_service.dart';
import 'image_converter_service.dart';
import 'media_converter_service.dart';

/// Progress of a batch: overall fraction 0..1, or null while a step cannot
/// report progress, plus a short status line.
typedef BatchProgress = void Function(double? progress, String status);

/// Routes each file to the right converter. Files are processed one at a time so
/// image and document buffers from one file are released before the next starts.
class ConversionService {
  static bool _cancelled = false;

  static Future<void> cancel() async {
    _cancelled = true;
    await MediaConverterService.cancelActiveConversions();
  }

  static Future<List<ConversionResult>> run({
    required List<FileItem> files,
    required ConversionTarget target,
    required ConversionOptions options,
    BatchProgress? onProgress,
  }) async {
    _cancelled = false;
    final results = <ConversionResult>[];
    if (files.isEmpty) return results;

    if (target.combinesInputs) {
      onProgress?.call(0, 'Combining ${files.length} files');
      void progress(double p) =>
          onProgress?.call(p, 'Combining ${files.length} files');
      final result = files.first.category == FileCategory.image
          ? await ImageConverterService.combineToPdf(
              sources: files,
              options: options,
              onProgress: progress,
            )
          : await DocumentConverterService.mergePdfs(
              sources: files,
              onProgress: progress,
            );
      if (!_cancelled) {
        results.add(result);
        if (result.isSuccess) await HistoryService.addResult(result);
      }
      return results;
    }

    for (var i = 0; i < files.length; i++) {
      if (_cancelled) break;
      final file = files[i];
      final label = files.length == 1
          ? file.name
          : '${i + 1} of ${files.length}: ${file.name}';
      // Image and document steps do not report progress, so a single file
      // shows an indeterminate bar instead of sitting at 0%.
      onProgress?.call(files.length == 1 ? null : i / files.length, label);
      void fileProgress(double p) =>
          onProgress?.call((i + p.clamp(0.0, 1.0)) / files.length, label);

      final ConversionResult result;
      final isMedia =
          file.category == FileCategory.video ||
          file.category == FileCategory.audio ||
          (file.category == FileCategory.image && target.id == 'mp4');
      if (isMedia) {
        result = await MediaConverterService.convertMedia(
          sourceFile: file,
          target: target,
          options: options,
          onProgress: fileProgress,
        );
      } else if (file.category == FileCategory.image) {
        result = await ImageConverterService.convertImage(
          sourceFile: file,
          target: target,
          options: options,
        );
      } else {
        result = await DocumentConverterService.convertDocument(
          sourceFile: file,
          target: target,
          onProgress: fileProgress,
        );
      }

      if (_cancelled) break;
      results.add(result);
      if (result.isSuccess) await HistoryService.addResult(result);
    }
    onProgress?.call(1, 'Done');
    return results;
  }
}
