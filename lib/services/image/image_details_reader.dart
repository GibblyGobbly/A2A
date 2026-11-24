// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../models/image_details.dart';

/// Reads size and EXIF details without decoding the pixels where possible.
/// Pure and synchronous so it can run in a background isolate.
class ImageDetailsReader {
  static ImageDetails read(Uint8List bytes, {required String extension}) {
    int? width;
    int? height;
    final decoder = img.findDecoderForData(bytes);
    if (decoder != null) {
      final info = decoder.startDecode(bytes);
      width = info?.width;
      height = info?.height;
    }

    final exif = _exifOf(bytes, decoder);
    var w = width;
    var h = height;
    // Orientations 5 to 8 are rotated a quarter turn: swap to what is shown.
    final orientation = exif?.imageIfd.orientation ?? 1;
    if (orientation >= 5 && w != null && h != null) {
      (w, h) = (h, w);
    }
    final gps = exif?.gpsIfd;

    return ImageDetails(
      format: extension.toUpperCase(),
      width: w,
      height: h,
      sizeBytes: bytes.length,
      cameraMake: exif?.imageIfd.make,
      cameraModel: exif?.imageIfd.model,
      takenAt: _exifDate(exif?.exifIfd[0x9003]?.toString()),
      latitude: gps == null ? null : _coordinate(gps, 0x0002, 0x0001, 'S'),
      longitude: gps == null ? null : _coordinate(gps, 0x0004, 0x0003, 'W'),
      hasMetadata: exif != null && !exif.isEmpty,
    );
  }

  /// EXIF is read straight from JPEG headers; other formats need a decode.
  static img.ExifData? _exifOf(Uint8List bytes, img.Decoder? decoder) {
    if (decoder is img.JpegDecoder) return img.decodeJpgExif(bytes);
    if (decoder == null) return null;
    final decoded = decoder.decode(bytes, frame: 0);
    return decoded != null && decoded.hasExif ? decoded.exif : null;
  }

  /// "2026:05:01 14:03:22" as "2026-05-01 14:03"; other text is kept as is.
  static String? _exifDate(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final m = RegExp(
      r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2})',
    ).firstMatch(value);
    if (m == null) return value;
    return '${m[1]}-${m[2]}-${m[3]} ${m[4]}:${m[5]}';
  }

  /// Degrees from an EXIF degrees, minutes, seconds triple; negative for
  /// south or west.
  static double? _coordinate(
    img.IfdDirectory gps,
    int valueTag,
    int refTag,
    String negativeRef,
  ) {
    final value = gps[valueTag];
    if (value == null || value.length < 3) return null;
    final degrees =
        value.toDouble(0) + value.toDouble(1) / 60 + value.toDouble(2) / 3600;
    if (degrees == 0) return null;
    final ref = gps[refTag]?.toString().trim().toUpperCase();
    return ref == negativeRef ? -degrees : degrees;
  }
}
