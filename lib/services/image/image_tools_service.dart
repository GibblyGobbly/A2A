// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../models/conversion_result.dart';
import '../../models/file_item.dart';
import '../../models/image_details.dart';
import '../../models/image_edit.dart';
import '../app_storage_service.dart';
import '../batch_runner.dart';
import '../image_codec.dart';
import '../output_writer.dart';
import 'image_details_reader.dart';
import 'image_ops.dart';
import 'image_source.dart';
import 'metadata_stripper.dart';

/// Runs the image tools over picked files. Pixel work happens in background
/// isolates; files are processed one at a time.
class ImageToolsService {
  /// Quality for re-encoding edited photos: visually lossless, still compact.
  static const editQuality = 92;

  static void cancel() => BatchRunner.cancel();

  /// Applies [op] to every file and saves each as a new file ending in [suffix].
  static Future<List<ConversionResult>> applyEdit({
    required List<FileItem> files,
    required ImageOp op,
    required String suffix,
    BatchProgress? onProgress,
  }) => BatchRunner.run(
    files: files,
    onProgress: onProgress,
    job: (file) => _decodeEditSave(file, suffix, (image) {
      return ImageOps.apply(image, op);
    }),
  );

  /// Saves each file as [extension] ('jpg' or 'webp') at or below [targetBytes].
  static Future<List<ConversionResult>> compressToSize({
    required List<FileItem> files,
    required int targetBytes,
    required String extension,
    BatchProgress? onProgress,
  }) => BatchRunner.run(
    files: files,
    onProgress: onProgress,
    job: (file) async {
      final started = DateTime.now();
      final sameFormat =
          ImageCodec.normalizeExtension(file.extension) == extension;
      if (sameFormat && file.sizeInBytes <= targetBytes) {
        return OutputWriter.failure(
          file,
          extension,
          started,
          'Already ${FileItem.formatBytes(file.sizeInBytes)}, under the limit. '
          'Nothing to do.',
        );
      }
      return _withDecodable(file, extension, started, (input) async {
        final bytes = await Isolate.run(() {
          final image = _decode(input);
          return ImageCodec.encodeToTargetSize(image, extension, targetBytes);
        });
        final over = bytes.length > targetBytes;
        return OutputWriter.saveBytes(
          source: file,
          bytes: bytes,
          extension: extension,
          suffix: '_${(targetBytes / 1024).round()}kb',
          startedAt: started,
          note: over
              ? 'Could not reach ${FileItem.formatBytes(targetBytes)} even at the '
                    'lowest quality; this is the smallest version.'
              : null,
        );
      });
    },
  );

  /// Removes location, camera and other metadata. JPEG, PNG and WEBP keep their
  /// exact pixels; other formats, and photos that rely on an EXIF rotation, are
  /// re-encoded at high quality.
  static Future<List<ConversionResult>> stripMetadata({
    required List<FileItem> files,
    BatchProgress? onProgress,
  }) => BatchRunner.run(
    files: files,
    onProgress: onProgress,
    job: (file) async {
      final started = DateTime.now();
      final bytes = await File(file.path).readAsBytes();
      final lossless = await Isolate.run(() {
        if (_needsRotation(bytes)) return null;
        return MetadataStripper.strip(bytes);
      });
      if (lossless != null) {
        return OutputWriter.saveBytes(
          source: file,
          bytes: lossless,
          extension: ImageSource.editedExtension(file.extension),
          suffix: '_clean',
          startedAt: started,
        );
      }
      return _decodeEditSave(file, '_clean', (image) => image);
    },
  );

  static Future<ImageDetails> details(FileItem file) async {
    final bytes = await File(file.path).readAsBytes();
    final ext = file.extension;
    return Isolate.run(() => ImageDetailsReader.read(bytes, extension: ext));
  }

  /// True when the photo is stored sideways and shown upright via EXIF, so
  /// dropping the EXIF block would turn it.
  static bool _needsRotation(Uint8List bytes) {
    if (img.findDecoderForData(bytes) is! img.JpegDecoder) return false;
    final orientation = img.decodeJpgExif(bytes)?.imageIfd.orientation ?? 1;
    return orientation != 1;
  }

  static img.Image _decode(Uint8List input) {
    final image = ImageCodec.decodeAndPrepare(input);
    if (image == null) {
      throw const FormatException('The image data is damaged or unsupported');
    }
    // Edited copies never carry the original metadata.
    image.exif = img.ExifData();
    return image;
  }

  static Future<ConversionResult> _decodeEditSave(
    FileItem file,
    String suffix,
    img.Image Function(img.Image) edit,
  ) {
    final started = DateTime.now();
    final extension = ImageSource.editedExtension(file.extension);
    return _withDecodable(file, extension, started, (input) async {
      final bytes = await Isolate.run(() {
        final image = edit(_decode(input));
        return ImageCodec.encode(image, extension, quality: editQuality);
      });
      return OutputWriter.saveBytes(
        source: file,
        bytes: bytes,
        extension: extension,
        suffix: suffix,
        startedAt: started,
      );
    });
  }

  /// Reads [file] into decodable bytes and runs [body], turning any error into
  /// a failed result and always removing the scratch directory.
  static Future<ConversionResult> _withDecodable(
    FileItem file,
    String extension,
    DateTime started,
    Future<ConversionResult> Function(Uint8List input) body,
  ) async {
    final workDir = await AppStorageService.createWorkDirectory();
    try {
      return await body(await ImageSource.readDecodable(file, workDir));
    } catch (e) {
      return OutputWriter.failure(
        file,
        extension,
        started,
        OutputWriter.describe(e),
      );
    } finally {
      await AppStorageService.deleteQuietly(workDir);
    }
  }
}
