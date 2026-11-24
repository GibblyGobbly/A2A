// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:developer' as developer;
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import '../models/conversion_options.dart';
import '../models/conversion_result.dart';
import '../models/conversion_target.dart';
import '../models/file_item.dart';
import 'app_storage_service.dart';
import 'av1_encoder_service.dart';
import 'ffmpeg_commands.dart';
import 'media/ffmpeg_runner.dart';
import 'video/video_job.dart';

class MediaConverterService {
  static Future<void> cancelActiveConversions() async {
    await Av1EncoderService.cancel();
    await FfmpegRunner.cancel();
  }

  static Future<MediaProbe> probe(FileItem source) async {
    try {
      final session = await FFprobeKit.getMediaInformation(source.path);
      final info = session.getMediaInformation();
      if (info == null) return MediaProbe(fileSizeBytes: source.sizeInBytes);
      int? videoBitrate;
      int? audioBitrate;
      int? width;
      int? height;
      var hasVideo = false;
      var hasAudio = false;
      for (final stream in info.getStreams()) {
        final type = stream.getType();
        // Cover art in audio files is reported as a video stream; ignore attached pictures.
        final disposition = stream.getAllProperties()?['disposition'];
        final isCoverArt =
            disposition is Map && disposition['attached_pic'] == 1;
        if (type == 'video' && !hasVideo && !isCoverArt) {
          hasVideo = true;
          videoBitrate = int.tryParse(stream.getBitrate() ?? '');
          width = stream.getWidth();
          height = stream.getHeight();
        } else if (type == 'audio' && !hasAudio) {
          hasAudio = true;
          audioBitrate = int.tryParse(stream.getBitrate() ?? '');
        }
      }
      return MediaProbe(
        durationSeconds: double.tryParse(info.getDuration() ?? '') ?? 0,
        fileSizeBytes: source.sizeInBytes,
        formatBitrate: int.tryParse(info.getBitrate() ?? ''),
        videoBitrate: videoBitrate,
        audioBitrate: audioBitrate,
        width: width,
        height: height,
        hasVideo: hasVideo,
        hasAudio: hasAudio,
      );
    } on Exception catch (e) {
      developer.log(
        'Probe failed for ${source.path}: $e',
        name: 'MediaConverterService',
      );
      return MediaProbe(fileSizeBytes: source.sizeInBytes);
    }
  }

  /// Runs [args] in the bundled SVT-AV1 executable. Returns null on success.
  static Future<String?> _runSvt(
    List<String> args,
    double totalMs,
    void Function(double)? onProgress,
  ) async {
    final result = await Av1EncoderService.run(
      args,
      onTime: (micros) {
        if (totalMs > 0) {
          onProgress?.call((micros / 1000 / totalMs).clamp(0.0, 1.0));
        }
      },
    );
    if (result.isSuccess) return null;
    return result.errorTail.isEmpty
        ? 'AV1 encoder exited with code ${result.exitCode}'
        : result.errorTail;
  }

  static Future<ConversionResult> convertMedia({
    required FileItem sourceFile,
    required ConversionTarget target,
    required ConversionOptions options,
    void Function(double progress)? onProgress,
  }) async {
    final startTime = DateTime.now();
    FfmpegRunner.reset();
    final extension = FfmpegCommands.outputExtension(target.id);
    final targetPath = await AppStorageService.generateOutputPath(
      baseName: sourceFile.baseName,
      extension: extension,
    );
    final outFile = File(targetPath);

    ConversionResult fail(String message) => ConversionResult.failure(
      sourcePath: sourceFile.path,
      sourceName: sourceFile.name,
      targetExtension: extension,
      originalSizeBytes: sourceFile.sizeInBytes,
      startedAt: startTime,
      errorMessage: message,
    );

    try {
      final info = await probe(sourceFile);
      if (FfmpegCommands.audioTargets.contains(target.id) && !info.hasAudio) {
        return fail('This file has no audio track.');
      }
      final totalMs = info.durationSeconds * 1000;

      // AV1: the phone's hardware encoder when it has one, then SVT-AV1 on all
      // CPU cores, then H.264 as a last resort so the conversion completes.
      // H.264 and H.265: the video chip when chosen, then the CPU encoder.
      final chip = options.fastVideoEncoder && info.hasVideo
          ? FfmpegCommands.hardwareEncoderFor(target.id)
          : null;
      final encoders = target.id == 'av1'
          ? <VideoEncoder?>[
              if (await AppStorageService.hasHardwareAv1Encoder())
                VideoEncoder.av1Hardware,
              if (await Av1EncoderService.isAvailable()) VideoEncoder.av1Svt,
              VideoEncoder.h264,
            ]
          : <VideoEncoder?>[?chip, null];
      String? note;
      String? lastError;
      var succeeded = false;
      for (final encoder in encoders) {
        if (FfmpegRunner.cancelRequested) break;
        await AppStorageService.deleteQuietly(outFile);
        onProgress?.call(0);
        final args = FfmpegCommands.build(
          input: sourceFile.path,
          output: targetPath,
          targetId: target.id,
          options: options,
          probe: info,
          encoderOverride: encoder,
        );
        final error = encoder == VideoEncoder.av1Svt
            ? await _runSvt(args, totalMs, onProgress)
            : await FfmpegRunner.run(
                args,
                totalMs: totalMs,
                onProgress: onProgress,
              );
        if (error == null && await outFile.exists()) {
          succeeded = true;
          if (target.id == 'av1' && encoder == VideoEncoder.h264) {
            note =
                'No AV1 encoder could process this video, so it was saved as H.264.';
          } else if (chip != null && encoder == null) {
            note = VideoJob.softwareFallbackNote;
          }
          break;
        }
        lastError = error;
        developer.log(
          'Encoder ${encoder?.name ?? target.id} failed: $error',
          name: 'MediaConverterService',
        );
      }

      if (FfmpegRunner.cancelRequested) {
        await AppStorageService.deleteQuietly(outFile);
        return fail('Cancelled');
      }
      if (!succeeded) {
        await AppStorageService.deleteQuietly(outFile);
        return fail(lastError ?? 'Conversion failed');
      }

      await AppStorageService.notifyMediaScanner(targetPath);
      final size = await outFile.length();
      if (size >= sourceFile.sizeInBytes &&
          FfmpegCommands.videoTargets.contains(target.id) &&
          target.id != 'gif') {
        note ??=
            'The output is not smaller than the original. The source is already efficiently compressed; '
            'try SMALLEST quality, a lower resolution or H.265.';
      }

      return ConversionResult(
        sourcePath: sourceFile.path,
        sourceName: sourceFile.name,
        targetPath: targetPath,
        targetName: targetPath.split('/').last,
        targetExtension: extension,
        originalSizeBytes: sourceFile.sizeInBytes,
        convertedSizeBytes: size,
        duration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
        note: note,
      );
    } catch (e) {
      await AppStorageService.deleteQuietly(outFile);
      return fail(e.toString());
    }
  }
}
