// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

/// Removes location, camera and editing metadata from JPEG, PNG and WEBP files
/// without touching the pixel data, so there is no quality loss.
///
/// Colour profiles are kept so colours look the same afterwards.
class MetadataStripper {
  /// Stripped bytes, or null when [bytes] is not a JPEG, PNG or WEBP file or
  /// its structure is damaged.
  static Uint8List? strip(Uint8List bytes) {
    if (_isJpeg(bytes)) return _stripJpeg(bytes);
    if (_isPng(bytes)) return _stripPng(bytes);
    if (_isWebp(bytes)) return _stripWebp(bytes);
    return null;
  }

  static bool _isJpeg(Uint8List b) =>
      b.length > 4 && b[0] == 0xFF && b[1] == 0xD8;

  static const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

  static bool _isPng(Uint8List b) {
    if (b.length < 8) return false;
    for (var i = 0; i < 8; i++) {
      if (b[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  static bool _isWebp(Uint8List b) =>
      b.length > 12 && _ascii(b, 0, 4) == 'RIFF' && _ascii(b, 8, 4) == 'WEBP';

  static String _ascii(Uint8List b, int offset, int length) =>
      String.fromCharCodes(b.sublist(offset, offset + length));

  /// JPEG segments that carry metadata: APP1 (EXIF, XMP), APP12 (Ducky),
  /// APP13 (IPTC, Photoshop) and comments. APP2 holds the ICC profile; kept.
  static const _jpegDropped = {0xE1, 0xEC, 0xED, 0xFE};

  static Uint8List? _stripJpeg(Uint8List b) {
    final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
    var i = 2;
    while (i + 4 <= b.length) {
      if (b[i] != 0xFF) return null;
      final marker = b[i + 1];
      // Fill bytes before a marker.
      if (marker == 0xFF) {
        i++;
        continue;
      }
      // Start of scan: the rest is image data and the end marker.
      if (marker == 0xDA) {
        out.add(Uint8List.sublistView(b, i));
        return out.toBytes();
      }
      // Markers without a length field.
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        out.add(Uint8List.sublistView(b, i, i + 2));
        i += 2;
        continue;
      }
      final length = (b[i + 2] << 8) | b[i + 3];
      final end = i + 2 + length;
      if (length < 2 || end > b.length) return null;
      if (!_jpegDropped.contains(marker)) {
        out.add(Uint8List.sublistView(b, i, end));
      }
      i = end;
    }
    return null;
  }

  /// Text, timestamp and EXIF chunks. Colour chunks (iCCP, sRGB, gAMA) stay.
  static const _pngDropped = {'tEXt', 'zTXt', 'iTXt', 'eXIf', 'tIME'};

  static Uint8List? _stripPng(Uint8List b) {
    final out = BytesBuilder(copy: false)..add(Uint8List.sublistView(b, 0, 8));
    var i = 8;
    while (i + 12 <= b.length) {
      final length =
          (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
      final type = _ascii(b, i + 4, 4);
      final end = i + 12 + length;
      if (length < 0 || end > b.length) return null;
      if (!_pngDropped.contains(type)) {
        out.add(Uint8List.sublistView(b, i, end));
      }
      i = end;
      if (type == 'IEND') return out.toBytes();
    }
    return null;
  }

  static Uint8List? _stripWebp(Uint8List b) {
    final chunks = BytesBuilder(copy: false);
    var i = 12;
    while (i + 8 <= b.length) {
      final type = _ascii(b, i, 4);
      final size =
          b[i + 4] | (b[i + 5] << 8) | (b[i + 6] << 16) | (b[i + 7] << 24);
      final end = i + 8 + size + (size.isOdd ? 1 : 0);
      if (end > b.length) return null;
      if (type == 'VP8X') {
        final chunk = Uint8List.fromList(b.sublist(i, end));
        // Clear the EXIF (bit 3) and XMP (bit 2) presence flags.
        chunk[8] &= ~0x0C;
        chunks.add(chunk);
      } else if (type != 'EXIF' && type != 'XMP ') {
        chunks.add(Uint8List.sublistView(b, i, end));
      }
      i = end;
    }
    final body = chunks.toBytes();
    final riffSize = body.length + 4;
    return (BytesBuilder(copy: false)
          ..add('RIFF'.codeUnits)
          ..add([
            riffSize & 0xFF,
            (riffSize >> 8) & 0xFF,
            (riffSize >> 16) & 0xFF,
            (riffSize >> 24) & 0xFF,
          ])
          ..add('WEBP'.codeUnits)
          ..add(body))
        .toBytes();
  }
}
