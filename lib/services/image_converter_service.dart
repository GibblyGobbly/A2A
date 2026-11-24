// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import '../models/conversion_options.dart';
import '../models/conversion_result.dart';
import '../models/conversion_target.dart';
import '../models/file_item.dart';
import 'app_storage_service.dart';
import 'image/image_source.dart';
import 'image_codec.dart';
import 'output_writer.dart';

class ImageConverterService {
  static Future<ConversionResult> convertImage({
    required FileItem sourceFile,
    required ConversionTarget target,
    required ConversionOptions options,
  }) async {
    final startTime = DateTime.now();
    final targetExt = target.extension;
    String? targetPath;
    final workDir = await AppStorageService.createWorkDirectory();

    try {
      final input = await ImageSource.readDecodable(sourceFile, workDir);
      final maxDim = target.id == 'ico' ? null : options.maxImageDimension;
      final quality = options.imageQuality;
      final layout = PdfLayout.fromOptions(options);
      final targetBytes =
          options.usesTargetSize && ImageCodec.lossyTargets.contains(targetExt)
          ? sourceFile.sizeInBytes * options.targetSizePercent ~/ 100
          : null;

      final Uint8List output = await Isolate.run(() async {
        final decoded = ImageCodec.decodeAndPrepare(
          input,
          maxDimension: maxDim,
        );
        if (decoded == null) {
          throw const FormatException(
            'The image data is damaged or unsupported',
          );
        }
        if (targetExt == 'pdf') {
          return ImageCodec.buildPdf([
            ImageCodec.toJpegPage(decoded, quality: quality),
          ], layout: layout);
        }
        if (targetBytes != null) {
          return ImageCodec.encodeToTargetSize(decoded, targetExt, targetBytes);
        }
        return ImageCodec.encode(decoded, targetExt, quality: quality);
      });

      final sameFormat =
          ImageCodec.normalizeExtension(sourceFile.extension) ==
          ImageCodec.normalizeExtension(targetExt);
      if (sameFormat && output.length >= sourceFile.sizeInBytes) {
        return ConversionResult.failure(
          sourcePath: sourceFile.path,
          sourceName: sourceFile.name,
          targetExtension: targetExt,
          originalSizeBytes: sourceFile.sizeInBytes,
          startedAt: startTime,
          errorMessage:
              'Not saved: the result (${FileItem.formatBytes(output.length)}) is not smaller '
              'than the original. Lower the quality or the size.',
        );
      }

      targetPath = await AppStorageService.generateOutputPath(
        baseName: sourceFile.baseName,
        extension: targetExt,
      );
      await File(targetPath).writeAsBytes(output, flush: true);
      await AppStorageService.notifyMediaScanner(targetPath);

      return ConversionResult(
        sourcePath: sourceFile.path,
        sourceName: sourceFile.name,
        targetPath: targetPath,
        targetName: targetPath.split('/').last,
        targetExtension: targetExt,
        originalSizeBytes: sourceFile.sizeInBytes,
        convertedSizeBytes: output.length,
        duration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (targetPath != null) {
        await AppStorageService.deleteQuietly(File(targetPath));
      }
      return ConversionResult.failure(
        sourcePath: sourceFile.path,
        sourceName: sourceFile.name,
        targetExtension: targetExt,
        originalSizeBytes: sourceFile.sizeInBytes,
        startedAt: startTime,
        errorMessage: OutputWriter.describe(e),
      );
    } finally {
      await AppStorageService.deleteQuietly(workDir);
    }
  }

  /// Combines all images into one PDF, one page per image, in the given order.
  /// Images are decoded one at a time so only one full-size bitmap is alive at once.
  static Future<ConversionResult> combineToPdf({
    required List<FileItem> sources,
    required ConversionOptions options,
    void Function(double progress)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final totalInput = sources.fold<int>(0, (sum, f) => sum + f.sizeInBytes);
    String? targetPath;
    final workDir = await AppStorageService.createWorkDirectory();

    try {
      final maxDim = options.maxImageDimension ?? 2480;
      final quality = options.imageQuality;
      final layout = PdfLayout.fromOptions(options);
      final jpegPages = <JpegPage>[];
      for (var i = 0; i < sources.length; i++) {
        final input = await ImageSource.readDecodable(sources[i], workDir);
        final name = sources[i].name;
        final page = await Isolate.run(() {
          final decoded = ImageCodec.decodeAndPrepare(
            input,
            maxDimension: maxDim,
          );
          if (decoded == null) {
            throw FormatException('$name could not be read');
          }
          return ImageCodec.toJpegPage(decoded, quality: quality);
        });
        jpegPages.add(page);
        onProgress?.call((i + 1) / (sources.length + 1));
      }

      final pdfBytes = await Isolate.run(
        () => ImageCodec.buildPdf(jpegPages, layout: layout),
      );

      targetPath = await AppStorageService.generateOutputPath(
        baseName: '${sources.first.baseName} and ${sources.length - 1} more',
        extension: 'pdf',
      );
      await File(targetPath).writeAsBytes(pdfBytes, flush: true);
      await AppStorageService.notifyMediaScanner(targetPath);
      onProgress?.call(1);

      return ConversionResult(
        sourcePath: sources.first.path,
        sourceName: '${sources.length} images',
        targetPath: targetPath,
        targetName: targetPath.split('/').last,
        targetExtension: 'pdf',
        originalSizeBytes: totalInput,
        convertedSizeBytes: pdfBytes.length,
        duration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (targetPath != null) {
        await AppStorageService.deleteQuietly(File(targetPath));
      }
      return ConversionResult.failure(
        sourcePath: sources.first.path,
        sourceName: '${sources.length} images',
        targetExtension: 'pdf',
        originalSizeBytes: totalInput,
        startedAt: startTime,
        errorMessage: OutputWriter.describe(e),
      );
    } finally {
      await AppStorageService.deleteQuietly(workDir);
    }
  }
}
