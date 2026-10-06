import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/conversion_options.dart';
import '../models/conversion_result.dart';
import '../models/file_item.dart';
import 'app_storage_service.dart';

class ImageConverterService {
  static Future<ConversionResult> convertImage({
    required FileItem sourceFile,
    required String targetFormat,
    required ConversionOptions options,
  }) async {
    final startTime = DateTime.now();
    final cleanTargetExt = targetFormat.toLowerCase().replaceAll('.', '').trim();
    final baseName = sourceFile.name.contains('.')
        ? sourceFile.name.substring(0, sourceFile.name.lastIndexOf('.'))
        : sourceFile.name;

    final targetPath = await AppStorageService.generateOutputPath(
      baseName: baseName,
      extension: cleanTargetExt,
    );

    try {
      final inputBytes = await File(sourceFile.path).readAsBytes();

      img.Image? decoded = img.decodeImage(inputBytes);

      // Fallback decoding for native camera formats
      if (decoded == null) {
        final tempDir = await AppStorageService.getOutputDirectory();
        final tempPngPath = '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.png';
        final session = await FFmpegKit.execute('-y -i "${sourceFile.path}" "$tempPngPath"');
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode) && File(tempPngPath).existsSync()) {
          final tempBytes = await File(tempPngPath).readAsBytes();
          decoded = img.decodeImage(tempBytes);
          try {
            File(tempPngPath).deleteSync();
          } catch (_) {}
        }
      }

      if (decoded == null) {
        throw Exception('Unable to read image file');
      }

      decoded = img.bakeOrientation(decoded);

      if (options.targetWidth != null || options.targetHeight != null) {
        decoded = img.copyResize(
          decoded,
          width: options.targetWidth,
          height: options.targetHeight,
          maintainAspect: options.keepAspectRatio,
        );
      }

      if (cleanTargetExt == 'pdf') {
        final pngBytes = Uint8List.fromList(img.encodePng(decoded, level: 6));
        final pdf = pw.Document();
        final pdfImage = pw.MemoryImage(pngBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              );
            },
          ),
        );

        final pdfBytes = await pdf.save();
        await File(targetPath).writeAsBytes(pdfBytes);
        await AppStorageService.notifyMediaScanner(targetPath);

        final targetFile = File(targetPath);
        final targetStat = await targetFile.stat();

        return ConversionResult(
          sourcePath: sourceFile.path,
          sourceName: sourceFile.name,
          targetPath: targetPath,
          targetName: targetPath.split('/').last,
          targetExtension: 'pdf',
          originalSizeBytes: sourceFile.sizeInBytes,
          convertedSizeBytes: targetStat.size,
          duration: DateTime.now().difference(startTime),
          timestamp: DateTime.now(),
          isSuccess: true,
        );
      }

      Uint8List encodedBytes;
      switch (cleanTargetExt) {
        case 'jpg':
        case 'jpeg':
          if (decoded.hasAlpha) {
            final opaque = img.Image(width: decoded.width, height: decoded.height, numChannels: 3);
            img.fill(opaque, color: img.ColorRgb8(255, 255, 255));
            img.compositeImage(opaque, decoded);
            decoded = opaque;
          }
          encodedBytes = Uint8List.fromList(
            img.encodeJpg(
              decoded,
              quality: options.imageQuality.clamp(1, 100),
              chroma: img.JpegChroma.yuv420,
            ),
          );
          break;

        case 'png':
          encodedBytes = Uint8List.fromList(
            img.encodePng(decoded, level: 9, filter: img.PngFilter.paeth),
          );
          break;

        case 'webp':
          encodedBytes = Uint8List.fromList(
            img.encodeWebP(decoded, quality: options.imageQuality.clamp(1, 100), lossless: false),
          );
          break;

        case 'bmp':
          encodedBytes = Uint8List.fromList(
            img.encodeBmp(decoded),
          );
          break;

        case 'gif':
          encodedBytes = Uint8List.fromList(
            img.encodeGif(decoded),
          );
          break;

        case 'ico':
          final iconImage = img.copyResize(decoded, width: 64, height: 64);
          encodedBytes = Uint8List.fromList(
            img.encodeIco(iconImage),
          );
          break;

        default:
          encodedBytes = Uint8List.fromList(
            img.encodePng(decoded),
          );
      }

      await File(targetPath).writeAsBytes(encodedBytes);
      await AppStorageService.notifyMediaScanner(targetPath);
      final targetFile = File(targetPath);
      final targetStat = await targetFile.stat();

      return ConversionResult(
        sourcePath: sourceFile.path,
        sourceName: sourceFile.name,
        targetPath: targetPath,
        targetName: targetPath.split('/').last,
        targetExtension: cleanTargetExt,
        originalSizeBytes: sourceFile.sizeInBytes,
        convertedSizeBytes: targetStat.size,
        duration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
        isSuccess: true,
      );
    } catch (e) {
      return ConversionResult(
        sourcePath: sourceFile.path,
        sourceName: sourceFile.name,
        targetPath: targetPath,
        targetName: targetPath.split('/').last,
        targetExtension: cleanTargetExt,
        originalSizeBytes: sourceFile.sizeInBytes,
        convertedSizeBytes: 0,
        duration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
        isSuccess: false,
        errorMessage: e.toString(),
      );
    }
  }
}
