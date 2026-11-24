// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/conversion_result.dart';
import '../models/file_item.dart';
import 'history_service.dart';

/// Progress of a batch: overall fraction 0..1, or null while a step cannot
/// report progress, plus a short status line.
typedef BatchProgress = void Function(double? progress, String status);

/// One file's work. Must not throw: failures are returned as results.
typedef FileJob = Future<ConversionResult> Function(FileItem file);

/// Runs a job over files one at a time, so the buffers of one file are freed
/// before the next starts, and records successes in the history.
class BatchRunner {
  static bool _cancelled = false;

  /// Adds a finished result to the history. For jobs that do not go through
  /// [run].
  static Future<void> record(ConversionResult result) =>
      HistoryService.addResult(result);

  /// Stops after the file that is currently being processed.
  static void cancel() => _cancelled = true;

  static Future<List<ConversionResult>> run({
    required List<FileItem> files,
    required FileJob job,
    BatchProgress? onProgress,
  }) async {
    _cancelled = false;
    final results = <ConversionResult>[];
    for (var i = 0; i < files.length; i++) {
      if (_cancelled) break;
      final file = files[i];
      final label = files.length == 1
          ? file.name
          : '${i + 1} of ${files.length}: ${file.name}';
      onProgress?.call(files.length == 1 ? null : i / files.length, label);
      final result = await job(file);
      if (_cancelled) break;
      results.add(result);
      if (result.isSuccess) await record(result);
    }
    onProgress?.call(1, 'Done');
    return results;
  }
}
