// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'preview_image.dart';

/// Shows the image at [path] as large as fits, with [overlay] stacked on top.
///
/// The overlay covers the image plus [overlayBleed] on every side, so handles
/// drawn on the image edge can still be grabbed from outside it. The overlay
/// builder receives the image size; the image starts at
/// (overlayBleed, overlayBleed) inside the overlay.
class FittedPreview extends StatelessWidget {
  final String path;
  final double aspectRatio;
  final Widget Function(Size imageSize)? overlay;
  final double overlayBleed;

  /// Bleed for overlays with drag handles: half a 48 dp touch target.
  static const handleBleed = 24.0;

  /// Rotation in quarter turns and mirroring, applied to the preview only.
  final int quarterTurns;
  final bool flipHorizontal;
  final bool flipVertical;

  const FittedPreview({
    super.key,
    required this.path,
    required this.aspectRatio,
    this.overlay,
    this.overlayBleed = 0,
    this.quarterTurns = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final turned = quarterTurns.isOdd;
    final shownRatio = turned ? 1 / aspectRatio : aspectRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bleed = overlay == null ? 0.0 : overlayBleed;
        var width = constraints.maxWidth - bleed * 2;
        var height = width / shownRatio;
        final maxHeight = constraints.maxHeight - bleed * 2;
        if (constraints.hasBoundedHeight && height > maxHeight) {
          height = maxHeight;
          width = height * shownRatio;
        }
        final size = Size(width, height);
        Widget picture = Image(
          image: PreviewImage.provider(path),
          fit: BoxFit.fill,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const PreviewUnavailable(),
        );
        if (flipHorizontal || flipVertical) {
          picture = Transform.flip(
            flipX: flipHorizontal,
            flipY: flipVertical,
            child: picture,
          );
        }
        if (quarterTurns % 4 != 0) {
          picture = RotatedBox(quarterTurns: quarterTurns, child: picture);
        }
        return Center(
          child: SizedBox(
            width: width + bleed * 2,
            height: height + bleed * 2,
            child: Stack(
              children: [
                Positioned(
                  left: bleed,
                  top: bleed,
                  width: width,
                  height: height,
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.ink,
                        width: AppTheme.stroke,
                      ),
                    ),
                    child: picture,
                  ),
                ),
                if (overlay != null) Positioned.fill(child: overlay!(size)),
              ],
            ),
          ),
        );
      },
    );
  }
}
