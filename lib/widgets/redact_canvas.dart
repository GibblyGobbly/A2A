// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/image_edit.dart';
import '../theme/app_theme.dart';

/// Drag over the image to mark a region to hide; tap a marked region to remove
/// it. Regions are reported in image fractions.
class RedactCanvas extends StatefulWidget {
  final Size size;

  /// Touch margin around the image; the image starts at (inset, inset).
  final double inset;
  final List<NormRect> regions;
  final ValueChanged<List<NormRect>> onChanged;

  const RedactCanvas({
    super.key,
    required this.size,
    this.inset = 0,
    required this.regions,
    required this.onChanged,
  });

  @override
  State<RedactCanvas> createState() => _RedactCanvasState();
}

class _RedactCanvasState extends State<RedactCanvas> {
  Offset? _start;
  Offset? _end;

  Offset _fraction(Offset p) => Offset(
    ((p.dx - widget.inset) / widget.size.width).clamp(0.0, 1.0),
    ((p.dy - widget.inset) / widget.size.height).clamp(0.0, 1.0),
  );

  NormRect? get _drawing {
    final a = _start;
    final b = _end;
    if (a == null || b == null) return null;
    return NormRect(
      a.dx < b.dx ? a.dx : b.dx,
      a.dy < b.dy ? a.dy : b.dy,
      (a.dx - b.dx).abs(),
      (a.dy - b.dy).abs(),
    );
  }

  void _tap(Offset p) {
    final f = _fraction(p);
    // The most recent region on top wins.
    for (var i = widget.regions.length - 1; i >= 0; i--) {
      final r = widget.regions[i];
      if (f.dx >= r.left &&
          f.dx <= r.right &&
          f.dy >= r.top &&
          f.dy <= r.bottom) {
        widget.onChanged([...widget.regions]..removeAt(i));
        return;
      }
    }
  }

  void _finish() {
    final r = _drawing;
    setState(() {
      _start = null;
      _end = null;
    });
    // Ignore accidental tiny drags.
    if (r != null && r.width > 0.01 && r.height > 0.01) {
      widget.onChanged([...widget.regions, r]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Start from the touch point so the frame follows the finger exactly.
      dragStartBehavior: DragStartBehavior.down,
      onTapUp: (d) => _tap(d.localPosition),
      onPanStart: (d) => setState(() {
        _start = _fraction(d.localPosition);
        _end = _start;
      }),
      onPanUpdate: (d) => setState(() => _end = _fraction(d.localPosition)),
      onPanEnd: (_) => _finish(),
      onPanCancel: _finish,
      child: CustomPaint(
        size: widget.size + Offset(widget.inset * 2, widget.inset * 2),
        painter: _RegionPainter(
          inset: widget.inset,
          imageSize: widget.size,
          regions: [...widget.regions, ?_drawing],
          fill: AppTheme.palette.shadow,
          frame: AppTheme.accent,
        ),
      ),
    );
  }
}

class _RegionPainter extends CustomPainter {
  final double inset;
  final Size imageSize;
  final List<NormRect> regions;
  final Color fill;
  final Color frame;

  _RegionPainter({
    required this.inset,
    required this.imageSize,
    required this.regions,
    required this.fill,
    required this.frame,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    canvas.translate(inset, inset);
    final size = imageSize;
    final shade = Paint()..color = fill.withAlpha(0x88);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = fill;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = frame;
    for (final region in regions) {
      final r = Rect.fromLTWH(
        region.left * size.width,
        region.top * size.height,
        region.width * size.width,
        region.height * size.height,
      );
      canvas.drawRect(r, shade);
      canvas.drawRect(r, outline);
      canvas.drawRect(r, border);
    }
  }

  @override
  bool shouldRepaint(_RegionPainter old) =>
      old.regions.length != regions.length ||
      !Iterable.generate(
        regions.length,
      ).every((i) => old.regions[i] == regions[i]) ||
      old.imageSize != imageSize ||
      old.inset != inset ||
      old.fill != fill ||
      old.frame != frame;
}
