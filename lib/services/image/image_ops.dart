// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../../models/image_edit.dart';

/// Pure pixel edits. Synchronous and free of Flutter bindings so they can run
/// inside `Isolate.run`.
class ImageOps {
  static img.Image apply(img.Image image, ImageOp op) => switch (op) {
    CropOp() => crop(image, op.rect),
    RotateFlipOp() => rotateFlip(image, op),
    ResizeOp() => resize(image, op),
    RedactOp() => redact(image, op.regions, op.style),
  };

  static img.Image crop(img.Image image, NormRect rect) {
    final r = rect.clamped().toPixels(image.width, image.height);
    return img.copyCrop(
      image,
      x: r.x,
      y: r.y,
      width: r.width,
      height: r.height,
    );
  }

  /// Flips first, then rotates, matching what the preview shows.
  static img.Image rotateFlip(img.Image image, RotateFlipOp op) {
    var out = image;
    if (op.flipHorizontal) out = img.flipHorizontal(img.Image.from(out));
    if (op.flipVertical) out = img.flipVertical(img.Image.from(out));
    final turns = op.quarterTurns % 4;
    if (turns != 0) out = img.copyRotate(out, angle: turns * 90);
    return out;
  }

  /// Target size for [op]. Never returns a side below 1 pixel.
  static ({int width, int height}) resizedSize(int w, int h, ResizeOp op) {
    if (op.mode == ResizeMode.percent) {
      final f = op.percent.clamp(1, 400) / 100;
      return (
        width: math.max(1, (w * f).round()),
        height: math.max(1, (h * f).round()),
      );
    }
    final tw = op.width;
    final th = op.height;
    if (tw != null && th != null) {
      final scale = math.min(tw / w, th / h);
      return (
        width: math.max(1, (w * scale).round()),
        height: math.max(1, (h * scale).round()),
      );
    }
    if (tw != null) {
      return (width: tw, height: math.max(1, (h * tw / w).round()));
    }
    if (th != null) {
      return (width: math.max(1, (w * th / h).round()), height: th);
    }
    return (width: w, height: h);
  }

  static img.Image resize(img.Image image, ResizeOp op) {
    final size = resizedSize(image.width, image.height, op);
    if (size.width == image.width && size.height == image.height) return image;
    final shrinking = size.width < image.width;
    return img.copyResize(
      image,
      width: size.width,
      height: size.height,
      // Averaging is sharp and alias free when shrinking; cubic is smoother
      // when enlarging.
      interpolation: shrinking
          ? img.Interpolation.average
          : img.Interpolation.cubic,
    );
  }

  /// Hides each region. Blur and pixelate shrink the region and scale it back
  /// up, which is far faster than a wide convolution and cannot be reversed.
  static img.Image redact(
    img.Image image,
    List<NormRect> regions,
    RedactStyle style,
  ) {
    final out = image.hasPalette ? image.convert(numChannels: 4) : image;
    final shortEdge = math.min(out.width, out.height);
    for (final region in regions) {
      final r = region.clamped(minSize: 0.005).toPixels(out.width, out.height);
      if (style == RedactStyle.solid) {
        img.fillRect(
          out,
          x1: r.x,
          y1: r.y,
          x2: r.x + r.width - 1,
          y2: r.y + r.height - 1,
          color: img.ColorRgb8(0, 0, 0),
          alphaBlend: false,
        );
        continue;
      }
      final patch = img.copyCrop(
        out,
        x: r.x,
        y: r.y,
        width: r.width,
        height: r.height,
      );
      // Blocks at least half the region's short side wide, so letters and
      // digits inside it cannot be made out.
      final block = math.max(
        8,
        math.max(shortEdge ~/ 30, math.min(r.width, r.height) ~/ 2),
      );
      final small = img.copyResize(
        patch,
        width: math.max(1, r.width ~/ block),
        height: math.max(1, r.height ~/ block),
        interpolation: img.Interpolation.average,
      );
      var hidden = img.copyResize(
        small,
        width: r.width,
        height: r.height,
        interpolation: style == RedactStyle.pixelate
            ? img.Interpolation.nearest
            : img.Interpolation.linear,
      );
      if (style == RedactStyle.blur) {
        hidden = img.gaussianBlur(hidden, radius: math.max(4, block ~/ 2));
      }
      img.compositeImage(
        out,
        hidden,
        dstX: r.x,
        dstY: r.y,
        blend: img.BlendMode.direct,
      );
    }
    return out;
  }
}
