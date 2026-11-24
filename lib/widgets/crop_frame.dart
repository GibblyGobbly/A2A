// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/image_edit.dart';
import '../theme/app_theme.dart';

enum _Drag { move, topLeft, topRight, bottomLeft, bottomRight }

/// Movable, resizable crop rectangle drawn over an image of [size]. Drag inside
/// to move it, drag a corner to resize. [ratio] (width / height in pixels)
/// locks the shape; null is free.
class CropFrame extends StatefulWidget {
  final Size size;

  /// Touch margin around the image; the image starts at (inset, inset).
  final double inset;
  final NormRect rect;
  final double? ratio;
  final ValueChanged<NormRect> onChanged;

  const CropFrame({
    super.key,
    required this.size,
    this.inset = 0,
    required this.rect,
    required this.ratio,
    required this.onChanged,
  });

  /// Corner touch radius in logical pixels; covers a 48 dp target.
  static const _grab = 28.0;

  /// The largest centred rectangle with [ratio] that fits the image.
  static NormRect fitted(double? ratio, double imageAspect) {
    if (ratio == null) return const NormRect(0.05, 0.05, 0.9, 0.9);
    // In image fractions, width / height = ratio / imageAspect.
    final r = ratio / imageAspect;
    var w = 0.9;
    var h = w / r;
    if (h > 0.9) {
      h = 0.9;
      w = h * r;
    }
    return NormRect((1 - w) / 2, (1 - h) / 2, w, h);
  }

  @override
  State<CropFrame> createState() => _CropFrameState();
}

class _CropFrameState extends State<CropFrame> {
  /// What the current drag moves; kept across rebuilds during the drag.
  _Drag? _mode;

  /// The rectangle as of the latest drag event. Several events can arrive
  /// before the parent rebuilds, so each one must build on this, not on
  /// [CropFrame.rect].
  NormRect? _live;

  Size get size => widget.size;
  NormRect get rect => _live ?? widget.rect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Start from the touch point so the frame follows the finger exactly.
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: (d) {
        _live = null;
        _mode = _hit(d.localPosition - Offset(widget.inset, widget.inset));
      },
      onPanUpdate: (d) {
        final m = _mode;
        if (m == null) return;
        final next = _dragged(
          m,
          d.delta.dx / size.width,
          d.delta.dy / size.height,
        );
        _live = next;
        widget.onChanged(next);
      },
      onPanEnd: (_) => _endDrag(),
      onPanCancel: _endDrag,
      child: CustomPaint(
        size: size + Offset(widget.inset * 2, widget.inset * 2),
        painter: _CropPainter(
          inset: widget.inset,
          imageSize: size,
          rect: rect,
          frame: AppTheme.accent,
          outline: AppTheme.palette.shadow,
        ),
      ),
    );
  }

  void _endDrag() {
    _mode = null;
    _live = null;
  }

  _Drag? _hit(Offset p) {
    final l = rect.left * size.width;
    final t = rect.top * size.height;
    final r = rect.right * size.width;
    final b = rect.bottom * size.height;
    final corners = {
      _Drag.topLeft: Offset(l, t),
      _Drag.topRight: Offset(r, t),
      _Drag.bottomLeft: Offset(l, b),
      _Drag.bottomRight: Offset(r, b),
    };
    for (final entry in corners.entries) {
      if ((entry.value - p).distance <= CropFrame._grab) return entry.key;
    }
    if (p.dx >= l && p.dx <= r && p.dy >= t && p.dy <= b) return _Drag.move;
    return null;
  }

  NormRect _dragged(_Drag mode, double dx, double dy) {
    if (mode == _Drag.move) {
      return NormRect(
        (rect.left + dx).clamp(0.0, 1.0 - rect.width),
        (rect.top + dy).clamp(0.0, 1.0 - rect.height),
        rect.width,
        rect.height,
      );
    }
    const minSize = 0.08;
    final left = mode == _Drag.topLeft || mode == _Drag.bottomLeft;
    final top = mode == _Drag.topLeft || mode == _Drag.topRight;
    // The corner opposite the dragged one stays put.
    final anchorX = left ? rect.right : rect.left;
    final anchorY = top ? rect.bottom : rect.top;
    final maxW = left ? anchorX : 1 - anchorX;
    final maxH = top ? anchorY : 1 - anchorY;
    var w = (rect.width + (left ? -dx : dx)).clamp(minSize, maxW);
    var h = (rect.height + (top ? -dy : dy)).clamp(minSize, maxH);

    final lock = widget.ratio;
    if (lock != null) {
      // Ratio in image fractions; follow the larger movement, then fit.
      final r = lock * size.height / size.width;
      if (dx.abs() >= dy.abs()) {
        h = w / r;
      } else {
        w = h * r;
      }
      final scale = math.min(1.0, math.min(maxW / w, maxH / h));
      w *= scale;
      h *= scale;
    }
    return NormRect(
      left ? anchorX - w : anchorX,
      top ? anchorY - h : anchorY,
      w,
      h,
    );
  }
}

class _CropPainter extends CustomPainter {
  final double inset;
  final Size imageSize;
  final NormRect rect;
  final Color frame;
  final Color outline;

  _CropPainter({
    required this.inset,
    required this.imageSize,
    required this.rect,
    required this.frame,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    canvas.translate(inset, inset);
    final size = imageSize;
    final r = Rect.fromLTWH(
      rect.left * size.width,
      rect.top * size.height,
      rect.width * size.width,
      rect.height * size.height,
    );
    // Dim everything outside the crop.
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(r),
      Paint()..color = outline.withAlpha(0x99),
    );
    // Rule-of-thirds guides.
    final guide = Paint()
      ..color = frame.withAlpha(0xAA)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = r.left + r.width * i / 3;
      final y = r.top + r.height * i / 3;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), guide);
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), guide);
    }
    // A dark outline under the yellow frame keeps it visible on any photo.
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = outline,
    );
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = frame,
    );
    final handle = Paint()..color = frame;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = outline;
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final box = Rect.fromCenter(center: c, width: 16, height: 16);
      canvas.drawRect(box, handle);
      canvas.drawRect(box, edge);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.rect != rect ||
      old.imageSize != imageSize ||
      old.inset != inset ||
      old.frame != frame ||
      old.outline != outline;
}
