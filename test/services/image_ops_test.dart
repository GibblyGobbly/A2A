// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:universal_converter/models/image_edit.dart';
import 'package:universal_converter/services/image/image_ops.dart';

img.Image _solid(int w, int h, int r, int g, int b) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return image;
}

void main() {
  group('crop', () {
    test('cuts the requested fraction of the image', () {
      final out = ImageOps.crop(
        _solid(200, 100, 0, 0, 0),
        const NormRect(0.25, 0.5, 0.5, 0.5),
      );
      expect(out.width, 100);
      expect(out.height, 50);
    });

    test('keeps the rectangle inside the image', () {
      final out = ImageOps.crop(
        _solid(100, 100, 0, 0, 0),
        const NormRect(0.9, 0.9, 0.5, 0.5),
      );
      expect(out.width, 50);
      expect(out.height, 50);
    });
  });

  group('rotate and flip', () {
    test('a quarter turn swaps width and height', () {
      final out = ImageOps.rotateFlip(
        _solid(30, 10, 0, 0, 0),
        const RotateFlipOp(quarterTurns: 1),
      );
      expect((out.width, out.height), (10, 30));
    });

    test('flipping mirrors pixels left to right', () {
      final image = _solid(2, 1, 0, 0, 0);
      image.setPixelRgb(0, 0, 255, 0, 0);
      final out = ImageOps.rotateFlip(
        image,
        const RotateFlipOp(flipHorizontal: true),
      );
      expect(out.getPixel(1, 0).r, 255);
      expect(out.getPixel(0, 0).r, 0);
    });
  });

  group('resize', () {
    test('percent scales both sides', () {
      final size = ImageOps.resizedSize(400, 300, const ResizeOp.percent(50));
      expect((size.width, size.height), (200, 150));
    });

    test('one side keeps the aspect ratio', () {
      final size = ImageOps.resizedSize(
        4000,
        3000,
        const ResizeOp.pixels(width: 1000),
      );
      expect((size.width, size.height), (1000, 750));
    });

    test('both sides fit the image inside the box', () {
      final size = ImageOps.resizedSize(
        4000,
        2000,
        const ResizeOp.pixels(width: 600, height: 600),
      );
      expect((size.width, size.height), (600, 300));
    });
  });

  group('redact', () {
    test('black box fills only the region', () {
      final out = ImageOps.redact(_solid(100, 100, 255, 255, 255), [
        const NormRect(0, 0, 0.5, 0.5),
      ], RedactStyle.solid);
      expect(out.getPixel(10, 10).r, 0);
      expect(out.getPixel(90, 90).r, 255);
    });

    test('pixelate removes detail inside the region', () {
      final image = _solid(120, 120, 255, 255, 255);
      // A one pixel line that must not survive.
      for (var x = 0; x < 60; x++) {
        image.setPixelRgb(x, 30, 0, 0, 0);
      }
      final out = ImageOps.redact(image, [
        const NormRect(0, 0, 0.5, 0.5),
      ], RedactStyle.pixelate);
      expect(out.getPixel(10, 30).r, greaterThan(100));
      expect(out.getPixel(100, 100).r, 255);
    });
  });
}
