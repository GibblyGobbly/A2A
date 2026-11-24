// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:universal_converter/services/image/image_details_reader.dart';
import 'package:universal_converter/services/image/metadata_stripper.dart';

/// A degrees, minutes, seconds triple. The Rational type is not exported, so
/// the values are taken from single-value instances.
img.IfdValueRational _dms(int d, int m, int s) => img.IfdValueRational(d, 1)
  ..value.addAll([
    ...img.IfdValueRational(m, 1).value,
    ...img.IfdValueRational(s, 1).value,
  ]);

img.Image _photo() {
  final image = img.Image(width: 64, height: 48);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  image.exif.imageIfd.make = 'Google';
  image.exif.imageIfd.model = 'Pixel 8';
  image.exif.gpsIfd[0x0001] = img.IfdValueAscii('N');
  image.exif.gpsIfd[0x0002] = _dms(12, 30, 0);
  image.exif.gpsIfd[0x0003] = img.IfdValueAscii('W');
  image.exif.gpsIfd[0x0004] = _dms(77, 15, 0);
  return image;
}

void main() {
  test('the reader finds camera and location in a JPEG', () {
    final jpg = img.encodeJpg(_photo());
    final details = ImageDetailsReader.read(jpg, extension: 'jpg');
    expect(details.width, 64);
    expect(details.height, 48);
    expect(details.camera, 'Google Pixel 8');
    expect(details.latitude, closeTo(12.5, 0.001));
    expect(details.longitude, closeTo(-77.25, 0.001));
    expect(details.hasMetadata, isTrue);
  });

  test('JPEG metadata is removed and the pixels are untouched', () {
    final jpg = img.encodeJpg(_photo());
    final clean = MetadataStripper.strip(jpg)!;
    expect(clean.length, lessThan(jpg.length));

    final details = ImageDetailsReader.read(clean, extension: 'jpg');
    expect(details.hasLocation, isFalse);
    expect(details.camera, isNull);

    final before = img.decodeJpg(jpg)!;
    final after = img.decodeJpg(clean)!;
    expect(after.getPixel(5, 5), before.getPixel(5, 5));
  });

  test('PNG text chunks are removed', () {
    final image = img.Image(width: 8, height: 8);
    image.textData = {'Author': 'Someone'};
    final png = img.encodePng(image);
    final clean = MetadataStripper.strip(png)!;
    expect(String.fromCharCodes(png).contains('tEXt'), isTrue);
    expect(String.fromCharCodes(clean).contains('tEXt'), isFalse);
    expect(img.decodePng(clean)!.width, 8);
  });

  test('unknown data is left alone', () {
    expect(MetadataStripper.strip(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
