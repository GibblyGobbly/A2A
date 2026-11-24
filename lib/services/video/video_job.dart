// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';
import '../../models/conversion_result.dart';
import '../../models/file_item.dart';
import '../app_storage_service.dart';
import '../media/ffmpeg_runner.dart';
import '../output_writer.dart';
import 'commands/encode_args.dart';

/// Runs one FFmpeg job that writes one file, and turns the outcome into a
/// [ConversionResult]. Partial files are always deleted on failure.
class VideoJob {
  /// Note shown when the phone's video chip failed and the CPU took over.
  static const softwareFallbackNote =
      "The phone's video chip could not process this file, so the slower "
      'CPU encoder was used.';

  /// Runs [args] writing [outputPath]. [totalMs] drives progress.
  static Future<ConversionResult> run({
    required FileItem source,
    required String outputPath,
    required List<String> args,
    double totalMs = 0,
    void Function(double)? onProgress,
  }) => _attempts(
    source: source,
    outputPath: outputPath,
    attempts: [args],
    totalMs: totalMs,
    onProgress: onProgress,
  );

  /// Encodes with the hardware encoder, then retries with libx264 if the
  /// hardware path fails. [build] returns the arguments for an encoder.
  static Future<ConversionResult> encode({
    required FileItem source,
    required String outputPath,
    required List<String> Function(VideoEncoderKind encoder) build,
    double totalMs = 0,
    void Function(double)? onProgress,
  }) => _attempts(
    source: source,
    outputPath: outputPath,
    attempts: [
      build(VideoEncoderKind.hardware),
      build(VideoEncoderKind.software),
    ],
    totalMs: totalMs,
    onProgress: onProgress,
  );

  static Future<ConversionResult> _attempts({
    required FileItem source,
    required String outputPath,
    required List<List<String>> attempts,
    required double totalMs,
    void Function(double)? onProgress,
  }) async {
    final started = DateTime.now();
    final out = File(outputPath);
    final extension = outputPath.split('.').last;
    String? error;
    for (final (i, args) in attempts.indexed) {
      await AppStorageService.deleteQuietly(out);
      onProgress?.call(0);
      try {
        error = await FfmpegRunner.run(
          args,
          totalMs: totalMs,
          onProgress: onProgress,
        );
      } on Exception catch (e) {
        error = OutputWriter.describe(e);
      }
      if (error == null && await out.exists() && await out.length() > 0) {
        await AppStorageService.notifyMediaScanner(outputPath);
        return ConversionResult(
          sourcePath: source.path,
          sourceName: source.name,
          targetPath: outputPath,
          targetName: outputPath.split('/').last,
          targetExtension: extension,
          originalSizeBytes: source.sizeInBytes,
          convertedSizeBytes: await out.length(),
          duration: DateTime.now().difference(started),
          timestamp: DateTime.now(),
          note: i > 0 ? softwareFallbackNote : null,
        );
      }
      if (error == 'Cancelled') break;
    }
    await AppStorageService.deleteQuietly(out);
    return OutputWriter.failure(
      source,
      extension,
      started,
      error ?? 'The output file was not written.',
    );
  }
}
