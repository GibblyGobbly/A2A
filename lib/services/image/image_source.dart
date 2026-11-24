// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import '../../models/file_item.dart';
import '../app_storage_service.dart';

/// Reading images in a form the pure-Dart decoder understands, and choosing
/// the format edited images are saved in.
class ImageSource {
  /// Formats the pure-Dart encoder can write back unchanged.
  static const _writable = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
    'gif',
    'tiff',
    'tif',
  };

  /// Reads [source]. Formats the decoder cannot read (HEIC, AVIF) are first
  /// transcoded to PNG with FFmpeg inside [workDir].
  static Future<Uint8List> readDecodable(
    FileItem source,
    Directory workDir,
  ) async {
    final bytes = await File(source.path).readAsBytes();
    if (img.findDecoderForData(bytes) != null) return bytes;

    final pngPath =
        '${workDir.path}/decoded_${DateTime.now().microsecondsSinceEpoch}.png';
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-i',
      source.path,
      '-frames:v',
      '1',
      '-threads',
      '8',
      pngPath,
    ]);
    final code = await session.getReturnCode();
    final pngFile = File(pngPath);
    if (!ReturnCode.isSuccess(code) || !await pngFile.exists()) {
      throw const FormatException('This image format could not be read');
    }
    final pngBytes = await pngFile.readAsBytes();
    await AppStorageService.deleteQuietly(pngFile);
    return pngBytes;
  }

  /// Extension an edited copy of a `.sourceExtension` file is saved with: the
  /// same format where it can be written, otherwise JPG.
  static String editedExtension(String sourceExtension) {
    final ext = sourceExtension.toLowerCase();
    if (!_writable.contains(ext)) return 'jpg';
    if (ext == 'jpeg') return 'jpg';
    if (ext == 'tif') return 'tiff';
    return ext;
  }
}
