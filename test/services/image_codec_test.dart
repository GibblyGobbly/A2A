import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:universal_converter/models/file_item.dart';
import 'package:universal_converter/services/format_catalog.dart';
import 'package:universal_converter/services/image_codec.dart';

/// A noisy gradient behaves like a photo: lossy encoders cannot shrink it to nothing.
img.Image _photo(int width, int height) {
  final image = img.Image(width: width, height: height);
  var seed = 7;
  for (final p in image) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    final noise = seed % 40;
    p
      ..r = (p.x * 255 ~/ width + noise).clamp(0, 255)
      ..g = (p.y * 255 ~/ height + noise).clamp(0, 255)
      ..b = (128 + noise).clamp(0, 255);
  }
  return image;
}

FileItem _file(String name) => FileItem(
  path: '/x/$name',
  name: name,
  extension: name.split('.').last,
  sizeInBytes: 1,
  category: FileItem.detectCategory(name.split('.').last),
  modifiedAt: DateTime(2026),
);

void main() {
  group('ImageCodec', () {
    final photo = _photo(1200, 900);
    final original = Uint8List.fromList(img.encodeJpg(photo, quality: 95));

    test('re-encoding a JPG at quality 75 makes it smaller', () {
      final decoded = ImageCodec.decodeAndPrepare(original)!;
      expect(
        ImageCodec.encode(decoded, 'jpg', quality: 75).length,
        lessThan(original.length),
      );
    });

    test('lossy WEBP is smaller than lossless PNG', () {
      final webp = ImageCodec.encode(photo, 'webp', quality: 75);
      final png = ImageCodec.encode(photo, 'png', quality: 75);
      expect(webp.length, lessThan(png.length ~/ 3));
    });

    test('shrinkToFit limits the longest edge and never upscales', () {
      final resized = ImageCodec.shrinkToFit(photo, 600);
      expect([resized.width, resized.height], [600, 450]);
      final portrait = ImageCodec.shrinkToFit(_photo(300, 1000), 500);
      expect([portrait.width, portrait.height], [150, 500]);
      expect(identical(ImageCodec.shrinkToFit(photo, 4000), photo), isTrue);
    });

    test('target size lands at or under the requested bytes', () {
      for (final percent in [60, 30, 10]) {
        final target = original.length * percent ~/ 100;
        final out = ImageCodec.encodeToTargetSize(photo, 'jpg', target);
        expect(out.length, lessThanOrEqualTo(target), reason: '$percent%');
        expect(
          out.length,
          greaterThan(target * 0.5),
          reason: '$percent% should use the budget',
        );
      }
    });

    test('JPG output flattens transparency onto white', () {
      final rgba = img.Image(width: 4, height: 4, numChannels: 4);
      final jpg = img.decodeJpg(ImageCodec.encode(rgba, 'jpg', quality: 90))!;
      expect(jpg.getPixel(0, 0).r, greaterThan(240));
    });
  });

  group('FormatCatalog', () {
    test('defaults to same-format compression for photos', () {
      final files = [_file('a.jpeg')];
      final targets = FormatCatalog.targetsFor(files);
      expect(FormatCatalog.defaultTarget(files, targets)!.id, 'jpg');
    });

    test(
      'offers combining for several images and merging for several PDFs',
      () {
        expect(
          FormatCatalog.targetsFor([
            _file('a.jpg'),
            _file('b.png'),
          ]).map((t) => t.id),
          contains('pdf-merge'),
        );
        expect(
          FormatCatalog.targetsFor([_file('a.pdf'), _file('b.pdf')]).first.id,
          'pdf-merge',
        );
        expect(
          FormatCatalog.targetsFor([_file('a.pdf')]).map((t) => t.id),
          isNot(contains('pdf-merge')),
        );
      },
    );

    test('only shows AV1 when an AV1 encoder is available', () {
      expect(
        FormatCatalog.targetsFor([_file('a.mp4')]).map((t) => t.id),
        isNot(contains('av1')),
      );
      expect(
        FormatCatalog.targetsFor([
          _file('a.mp4'),
        ], av1Available: true).map((t) => t.id),
        contains('av1'),
      );
    });

    test('mixed documents only offer targets valid for all of them', () {
      final ids = FormatCatalog.targetsFor([
        _file('a.docx'),
        _file('b.md'),
      ]).map((t) => t.id).toSet();
      expect(ids, {'pdf', 'txt'});
    });

    test('legacy binary Office formats are not offered', () {
      expect(FormatCatalog.targetsForExtension('doc'), isEmpty);
      expect(FormatCatalog.targetsForExtension('ppt'), isEmpty);
    });
  });
}
