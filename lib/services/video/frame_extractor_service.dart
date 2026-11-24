// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';
import '../../models/conversion_result.dart';
import '../../models/file_item.dart';
import '../app_storage_service.dart';
import '../batch_runner.dart';
import '../media/ffmpeg_runner.dart';
import '../output_writer.dart';
import 'commands/frame_commands.dart';
import 'video_info_service.dart';

/// Saves frames of a video as pictures: one frame, or many into a folder.
class FrameExtractorService {
  static Future<void> cancel() async {
    BatchRunner.cancel();
    await FfmpegRunner.cancel();
  }

  /// Saves the frame at [seconds] as one picture next to other outputs.
  static Future<List<ConversionResult>> single({
    required FileItem file,
    required double seconds,
    required String extension,
  }) async {
    FfmpegRunner.reset();
    final started = DateTime.now();
    final stamp = seconds.toStringAsFixed(1).replaceAll('.', '_');
    final out = await AppStorageService.generateOutputPath(
      baseName: '${file.baseName}_${stamp}s',
      extension: extension,
    );
    String? error;
    try {
      error = await FfmpegRunner.run(
        FrameCommands.single(input: file.path, output: out, seconds: seconds),
      );
    } on Exception catch (e) {
      error = OutputWriter.describe(e);
    }
    final result = await _collect(file, [out], started, error, out, extension);
    if (result.isSuccess) await BatchRunner.record(result);
    return [result];
  }

  /// Saves many frames into a new folder named after the video.
  static Future<List<ConversionResult>> many({
    required FileItem file,
    required FrameMode mode,
    required String extension,
    double everySeconds = 1,
    BatchProgress? onProgress,
  }) async {
    FfmpegRunner.reset();
    final started = DateTime.now();
    final root = await AppStorageService.getOutputDirectory();
    final folder = Directory(
      AppStorageService.uniqueDirectoryPath(
        root.path,
        AppStorageService.sanitizeBaseName('${file.baseName}_frames'),
      ),
    );
    ConversionResult result;
    try {
      await folder.create(recursive: true);
      final info = await VideoInfoService.read(file.path);
      onProgress?.call(0, file.name);
      final error = await FfmpegRunner.run(
        FrameCommands.many(
          input: file.path,
          outputPattern: FrameCommands.pattern(
            folder.path,
            AppStorageService.sanitizeBaseName(file.baseName),
            extension,
          ),
          mode: mode,
          everySeconds: everySeconds,
        ),
        totalMs: info.durationMs,
        onProgress: (p) => onProgress?.call(p, file.name),
      );
      final frames =
          (await folder.list().toList())
              .whereType<File>()
              .map((f) => f.path)
              .toList()
            ..sort();
      result = await _collect(
        file,
        frames,
        started,
        error,
        folder.path,
        extension,
      );
    } on Exception catch (e) {
      result = OutputWriter.failure(
        file,
        extension,
        started,
        OutputWriter.describe(e),
      );
    }
    if (!result.isSuccess) {
      await AppStorageService.deleteQuietly(folder);
    } else {
      await BatchRunner.record(result);
    }
    return [result];
  }

  static Future<ConversionResult> _collect(
    FileItem file,
    List<String> paths,
    DateTime started,
    String? error,
    String location,
    String extension,
  ) async {
    if (error != null || paths.isEmpty) {
      for (final p in paths) {
        await AppStorageService.deleteQuietly(File(p));
      }
      return OutputWriter.failure(
        file,
        extension,
        started,
        error ?? 'No frames matched. Try a smaller interval or another mode.',
      );
    }
    await AppStorageService.notifyMediaScannerAll(paths);
    var bytes = 0;
    for (final p in paths) {
      bytes += await File(p).length();
    }
    final many = paths.length > 1;
    return ConversionResult(
      sourcePath: file.path,
      sourceName: file.name,
      targetPath: paths.first,
      targetName: many
          ? '${paths.length} frames in ${location.split('/').last}'
          : paths.first.split('/').last,
      targetExtension: paths.first.split('.').last,
      outputPaths: paths,
      originalSizeBytes: file.sizeInBytes,
      convertedSizeBytes: bytes,
      duration: DateTime.now().difference(started),
      timestamp: DateTime.now(),
    );
  }
}
