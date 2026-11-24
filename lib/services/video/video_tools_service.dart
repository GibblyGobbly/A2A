// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/conversion_result.dart';
import '../../models/file_item.dart';
import '../../models/video_info.dart';
import '../app_storage_service.dart';
import '../batch_runner.dart';
import '../media/ffmpeg_runner.dart';
import '../output_writer.dart';
import 'commands/audio_extract_commands.dart';
import 'commands/edit_commands.dart';
import 'video_info_service.dart';
import 'video_job.dart';

/// Trim, rotate, flip, mute and audio extraction. Each picks the fastest
/// path: copying the data where possible, the phone's video chip otherwise.
class VideoToolsService {
  static Future<void> cancel() async {
    BatchRunner.cancel();
    await FfmpegRunner.cancel();
  }

  /// Video formats that can carry a rotation flag without re-encoding.
  static bool _supportsRotationFlag(VideoInfo info) =>
      info.container?.contains('mp4') ?? false;

  static Future<String> _output(FileItem file, String suffix, String ext) =>
      AppStorageService.generateOutputPath(
        baseName: '${file.baseName}$suffix',
        extension: ext,
      );

  /// Runs [job] for every file with its [VideoInfo], turning unreadable files
  /// into failed results.
  static Future<List<ConversionResult>> _each(
    List<FileItem> files,
    BatchProgress? onProgress,
    Future<ConversionResult> Function(
      FileItem file,
      VideoInfo info,
      void Function(double) progress,
    )
    job,
  ) {
    FfmpegRunner.reset();
    var index = 0;
    return BatchRunner.run(
      files: files,
      onProgress: onProgress,
      job: (file) async {
        final i = index++;
        void progress(double p) => onProgress?.call(
          (i + p.clamp(0.0, 1.0)) / files.length,
          files.length == 1
              ? file.name
              : '${i + 1} of ${files.length}: ${file.name}',
        );
        try {
          return await job(
            file,
            await VideoInfoService.read(file.path),
            progress,
          );
        } on Exception catch (e) {
          return OutputWriter.failure(
            file,
            file.extension,
            DateTime.now(),
            OutputWriter.describe(e),
          );
        }
      },
    );
  }

  static Future<List<ConversionResult>> trim({
    required FileItem file,
    required double start,
    required double end,
    required bool precise,
    BatchProgress? onProgress,
  }) => _each([file], onProgress, (file, info, progress) async {
    final totalMs = (end - start) * 1000;
    if (!precise) {
      final out = await _output(file, '_trim', file.extension);
      return VideoJob.run(
        source: file,
        outputPath: out,
        args: EditCommands.trimCopy(
          input: file.path,
          output: out,
          start: start,
          end: end,
        ),
        totalMs: totalMs,
        onProgress: progress,
      );
    }
    final out = await _output(file, '_trim', info.hasVideo ? 'mp4' : 'm4a');
    return VideoJob.encode(
      source: file,
      outputPath: out,
      build: (encoder) => EditCommands.trimPrecise(
        input: file.path,
        output: out,
        start: start,
        end: end,
        info: info,
        encoder: encoder,
      ),
      totalMs: totalMs,
      onProgress: progress,
    );
  });

  /// Turns and mirrors. A pure quarter turn of an MP4 or MOV only rewrites the
  /// rotation flag, which is instant and lossless.
  static Future<List<ConversionResult>> rotateFlip({
    required List<FileItem> files,
    required int quarterTurns,
    required bool flipHorizontal,
    required bool flipVertical,
    BatchProgress? onProgress,
  }) => _each(files, onProgress, (file, info, progress) async {
    final flips = flipHorizontal || flipVertical;
    final out = await _output(file, flips ? '_flipped' : '_rotated', 'mp4');
    if (!flips && _supportsRotationFlag(info)) {
      return VideoJob.run(
        source: file,
        outputPath: out,
        args: EditCommands.rotateCopy(
          input: file.path,
          output: out,
          info: info,
          quarterTurns: quarterTurns,
        ),
      );
    }
    return VideoJob.encode(
      source: file,
      outputPath: out,
      build: (encoder) => EditCommands.transform(
        input: file.path,
        output: out,
        info: info,
        encoder: encoder,
        quarterTurns: quarterTurns,
        flipHorizontal: flipHorizontal,
        flipVertical: flipVertical,
      ),
      totalMs: info.durationMs,
      onProgress: progress,
    );
  });

  static Future<List<ConversionResult>> mute({
    required List<FileItem> files,
    BatchProgress? onProgress,
  }) => _each(files, onProgress, (file, info, progress) async {
    if (!info.hasAudio) {
      return OutputWriter.failure(
        file,
        file.extension,
        DateTime.now(),
        'This video has no sound to remove.',
      );
    }
    final out = await _output(file, '_muted', file.extension);
    return VideoJob.run(
      source: file,
      outputPath: out,
      args: EditCommands.mute(input: file.path, output: out),
      totalMs: info.durationMs,
      onProgress: progress,
    );
  });

  /// Saves the soundtrack in its own format where possible (instant).
  static Future<List<ConversionResult>> extractAudio({
    required List<FileItem> files,
    BatchProgress? onProgress,
  }) => _each(files, onProgress, (file, info, progress) async {
    if (!info.hasAudio) {
      return OutputWriter.failure(
        file,
        'm4a',
        DateTime.now(),
        'This video has no sound.',
      );
    }
    final ext = AudioExtractCommands.extensionFor(info.audioCodec);
    final out = await _output(file, '', ext);
    return VideoJob.run(
      source: file,
      outputPath: out,
      args: AudioExtractCommands.build(
        input: file.path,
        output: out,
        audioCodec: info.audioCodec,
      ),
      totalMs: info.durationMs,
      onProgress: progress,
    );
  });
}
