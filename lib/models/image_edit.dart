// SPDX-License-Identifier: GPL-3.0-or-later

/// A rectangle in fractions of the image size (0 to 1), so it is independent
/// of the preview size and of the decoded resolution.
class NormRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const NormRect(this.left, this.top, this.width, this.height);

  static const full = NormRect(0, 0, 1, 1);

  double get right => left + width;
  double get bottom => top + height;

  /// Clamped to the image and to a minimum size of [minSize].
  NormRect clamped({double minSize = 0.02}) {
    final w = width.clamp(minSize, 1.0);
    final h = height.clamp(minSize, 1.0);
    return NormRect(left.clamp(0.0, 1.0 - w), top.clamp(0.0, 1.0 - h), w, h);
  }

  /// Pixel rectangle inside an image of [imageWidth] x [imageHeight].
  ({int x, int y, int width, int height}) toPixels(
    int imageWidth,
    int imageHeight,
  ) {
    final x = (left * imageWidth).round().clamp(0, imageWidth - 1);
    final y = (top * imageHeight).round().clamp(0, imageHeight - 1);
    final w = (width * imageWidth).round().clamp(1, imageWidth - x);
    final h = (height * imageHeight).round().clamp(1, imageHeight - y);
    return (x: x, y: y, width: w, height: h);
  }

  @override
  bool operator ==(Object other) =>
      other is NormRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// Crop shapes offered in the crop tool. [ratio] is width / height.
enum CropAspect {
  free('FREE', null),
  square('1:1', 1),
  fourFive('4:5', 4 / 5),
  threeFour('3:4', 3 / 4),
  sixteenNine('16:9', 16 / 9),
  nineSixteen('9:16', 9 / 16);

  final String label;
  final double? ratio;
  const CropAspect(this.label, this.ratio);
}

/// How a hidden region is drawn.
enum RedactStyle {
  blur('BLUR'),
  pixelate('PIXELATE'),
  solid('BLACK BOX');

  final String label;
  const RedactStyle(this.label);
}

/// How the resize tool measures the new size.
enum ResizeMode {
  percent('PERCENT'),
  pixels('PIXELS');

  final String label;
  const ResizeMode(this.label);
}

/// One edit, applied after EXIF orientation is baked in. Plain values only so
/// it can be sent to a background isolate.
sealed class ImageOp {
  const ImageOp();
}

class CropOp extends ImageOp {
  final NormRect rect;
  const CropOp(this.rect);
}

class RotateFlipOp extends ImageOp {
  /// Clockwise quarter turns, 0 to 3.
  final int quarterTurns;
  final bool flipHorizontal;
  final bool flipVertical;

  const RotateFlipOp({
    this.quarterTurns = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  bool get isIdentity =>
      quarterTurns % 4 == 0 && !flipHorizontal && !flipVertical;
}

class ResizeOp extends ImageOp {
  final ResizeMode mode;

  /// Used in [ResizeMode.percent], 1 to 400.
  final int percent;

  /// Used in [ResizeMode.pixels]. When only one side is set the other keeps
  /// the aspect ratio; when both are set the image is fitted inside the box.
  final int? width;
  final int? height;

  const ResizeOp.percent(this.percent)
    : mode = ResizeMode.percent,
      width = null,
      height = null;

  const ResizeOp.pixels({this.width, this.height})
    : mode = ResizeMode.pixels,
      percent = 100;
}

class RedactOp extends ImageOp {
  final List<NormRect> regions;
  final RedactStyle style;
  const RedactOp(this.regions, this.style);
}
