import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../models/conversion_options.dart';
import '../models/conversion_result.dart';
import '../models/file_item.dart';
import 'app_storage_service.dart';

class MediaConverterService {
  static Future<void> cancelActiveConversions() async {
    try {
      await FFmpegKit.cancel();
    } catch (_) {}
  }

  static Future<ConversionResult> convertMedia({
    required FileItem sourceFile,
    required String targetFormat,
    required ConversionOptions options,
    Function(double progress, String status)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final cleanTarget = targetFormat.toLowerCase().replaceAll('.', '').trim();
    final baseName = sourceFile.name.contains('.')
        ? sourceFile.name.substring(0, sourceFile.name.lastIndexOf('.'))
        : sourceFile.name;

    final actualExtension = _resolveActualExtension(cleanTarget);
    final targetPath = await AppStorageService.generateOutputPath(
      baseName: baseName,
      extension: actualExtension,
    );

    if (File(targetPath).existsSync()) {
      File(targetPath).deleteSync();
    }

    double totalDurationMs = 0;
    int sourceBitrate = 0;
    try {
      final probeSession = await FFprobeKit.getMediaInformation(sourceFile.path);
      final mediaInfo = probeSession.getMediaInformation();
      if (mediaInfo != null) {
        final durationStr = mediaInfo.getDuration();
        if (durationStr != null) {
          final seconds = double.tryParse(durationStr) ?? 0;
          totalDurationMs = seconds * 1000;
        }
        final bitrateStr = mediaInfo.getBitrate();
        if (bitrateStr != null) {
          sourceBitrate = int.tryParse(bitrateStr) ?? 0;
        }
      }
    } catch (_) {}

    FFmpegKitConfig.enableStatisticsCallback((statistics) {
      if (totalDurationMs > 0 && onProgress != null) {
        final currentMs = statistics.getTime().toDouble();
        final fraction = (currentMs / totalDurationMs).clamp(0.0, 1.0);
        final label = cleanTarget == 'mp3' || cleanTarget == 'aac' || cleanTarget == 'wav'
            ? 'Extracting audio...'
            : 'Converting video...';
        onProgress(fraction, label);
      }
    });

    final command = _buildFFmpegCommand(
      inputPath: sourceFile.path,
      outputPath: targetPath,
      targetFormat: cleanTarget,
      options: options,
      sourceBitrate: sourceBitrate,
    );

    try {
      var session = await FFmpegKit.execute(command);
      var returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode) && cleanTarget == 'av1') {
        final crf = options.videoCrf.clamp(26, 48);
        final scaleFilter = _resolveScaleFilter(options.videoResolution);
        final fallbackCommand = '-y -threads 8 -i "${sourceFile.path}" $scaleFilter -c:v libx264 -preset veryfast -crf ${crf - 4} -c:a aac -b:a ${options.audioBitrate} -movflags +faststart "$targetPath"';
        session = await FFmpegKit.execute(fallbackCommand);
        returnCode = await session.getReturnCode();
      }

      FFmpegKitConfig.enableStatisticsCallback(null);

      if (ReturnCode.isSuccess(returnCode)) {
        final targetFile = File(targetPath);
        await AppStorageService.notifyMediaScanner(targetPath);
        final targetSize = targetFile.existsSync() ? (await targetFile.stat()).size : 0;

        return ConversionResult(
          sourcePath: sourceFile.path,
          sourceName: sourceFile.name,
          targetPath: targetPath,
          targetName: targetPath.split('/').last,
          targetExtension: actualExtension,
          originalSizeBytes: sourceFile.sizeInBytes,
          convertedSizeBytes: targetSize,
          duration: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
          isSuccess: true,
        );
      } else {
        final logs = await session.getAllLogsAsString();
        return ConversionResult(
          sourcePath: sourceFile.path,
          sourceName: sourceFile.name,
          targetPath: targetPath,
          targetName: targetPath.split('/').last,
          targetExtension: actualExtension,
          originalSizeBytes: sourceFile.sizeInBytes,
          convertedSizeBytes: 0,
          duration: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
          isSuccess: false,
          errorMessage: logs ?? 'Conversion failed with code ${returnCode?.getValue()}',
        );
      }
    } catch (e) {
      FFmpegKitConfig.enableStatisticsCallback(null);
      return ConversionResult(
        sourcePath: sourceFile.path,
        sourceName: sourceFile.name,
        targetPath: targetPath,
        targetName: targetPath.split('/').last,
        targetExtension: actualExtension,
        originalSizeBytes: sourceFile.sizeInBytes,
        convertedSizeBytes: 0,
        duration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
        isSuccess: false,
        errorMessage: e.toString(),
      );
    }
  }

  static String _resolveActualExtension(String targetFormat) {
    switch (targetFormat) {
      case 'av1':
        return 'mp4';
      case 'mp4':
        return 'mp4';
      case 'mp3':
        return 'mp3';
      case 'aac':
        return 'm4a';
      case 'wav':
        return 'wav';
      case 'webm':
        return 'webm';
      case 'mkv':
        return 'mkv';
      case 'gif':
        return 'gif';
      case 'flac':
        return 'flac';
      case 'ogg':
        return 'ogg';
      default:
        return targetFormat;
    }
  }

  static String _resolveScaleFilter(String resolution) {
    switch (resolution.toLowerCase()) {
      case '1080p':
        return '-vf "scale=\'min(1920,iw)\':-2"';
      case '720p':
        return '-vf "scale=\'min(1280,iw)\':-2"';
      case '480p':
        return '-vf "scale=\'min(854,iw)\':-2"';
      case '360p':
        return '-vf "scale=\'min(640,iw)\':-2"';
      default:
        return '';
    }
  }

  static String _buildFFmpegCommand({
    required String inputPath,
    required String outputPath,
    required String targetFormat,
    required ConversionOptions options,
    int sourceBitrate = 0,
  }) {
    final globalFastFlags = '-y -threads 8';
    final scaleFilter = _resolveScaleFilter(options.videoResolution);

    switch (targetFormat) {
      case 'av1':
        final crf = options.videoCrf.clamp(26, 48);
        String bitrateConstraint = '';
        if (sourceBitrate > 0) {
          final factor = ((50 - crf) / 20.0).clamp(0.35, 0.70);
          final maxRateKbps = ((sourceBitrate / 1000) * factor).round().clamp(250, 3500);
          bitrateConstraint = '-maxrate ${maxRateKbps}k -bufsize ${maxRateKbps * 2}k';
        }
        return '$globalFastFlags -i "$inputPath" $scaleFilter -c:v libaom-av1 -crf $crf -b:v 0 $bitrateConstraint -cpu-used 8 -row-mt 1 -tiles 2x2 -strict experimental -c:a aac -b:a ${options.audioBitrate} -movflags +faststart "$outputPath"';

      case 'mp4':
        final crf = options.videoCrf.clamp(22, 36);
        return '$globalFastFlags -i "$inputPath" $scaleFilter -c:v libx264 -preset veryfast -crf $crf -c:a aac -b:a ${options.audioBitrate} -movflags +faststart "$outputPath"';

      case 'mp3':
        return '$globalFastFlags -i "$inputPath" -vn -c:a libmp3lame -b:a ${options.audioBitrate} -ar ${options.audioSampleRate} "$outputPath"';

      case 'webm':
        return '$globalFastFlags -i "$inputPath" $scaleFilter -c:v libvpx-vp9 -crf 36 -b:v 0 -cpu-used 5 -deadline realtime -row-mt 1 -c:a libopus -b:a ${options.audioBitrate} "$outputPath"';

      case 'gif':
        return '$globalFastFlags -i "$inputPath" -vf "fps=10,scale=\'min(360,iw)\':-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "$outputPath"';

      case 'mkv':
        return '$globalFastFlags -i "$inputPath" $scaleFilter -c:v libx264 -preset veryfast -crf 28 -c:a aac "$outputPath"';

      case 'wav':
        return '$globalFastFlags -i "$inputPath" -vn -c:a pcm_s16le -ar ${options.audioSampleRate} "$outputPath"';

      case 'aac':
        return '$globalFastFlags -i "$inputPath" -vn -c:a aac -b:a ${options.audioBitrate} "$outputPath"';

      case 'flac':
        return '$globalFastFlags -i "$inputPath" -vn -c:a flac "$outputPath"';

      case 'ogg':
        return '$globalFastFlags -i "$inputPath" -vn -c:a libvorbis -q:a 5 "$outputPath"';

      default:
        return '$globalFastFlags -i "$inputPath" "$outputPath"';
    }
  }

  static Future<FileItem> generateSampleVideo() async {
    final outputDir = await AppStorageService.getOutputDirectory();
    final samplePath = '${outputDir.path}/sample_test.mp4';

    if (File(samplePath).existsSync()) {
      return FileItem.fromFile(File(samplePath));
    }

    final cmd = '-y -threads 8 -f lavfi -i testsrc=duration=3:size=360x240:rate=20 -f lavfi -i sine=frequency=1000:duration=3 -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac "$samplePath"';
    await FFmpegKit.execute(cmd);
    return FileItem.fromFile(File(samplePath));
  }
}
