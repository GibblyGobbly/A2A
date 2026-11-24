// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum _Grab { start, end, seek }

/// A strip of preview frames with a start and an end handle. Drag a handle to
/// change the range; tap or drag elsewhere to move the play position.
/// Times are in seconds.
class TrimTimeline extends StatefulWidget {
  final List<String> thumbnails;
  final double duration;
  final double start;
  final double end;
  final double position;
  final void Function(double start, double end) onRangeChanged;
  final ValueChanged<double> onSeek;

  const TrimTimeline({
    super.key,
    required this.thumbnails,
    required this.duration,
    required this.start,
    required this.end,
    required this.position,
    required this.onRangeChanged,
    required this.onSeek,
  });

  static const height = 64.0;

  /// Room beside the strip so handles at either end can be grabbed.
  static const _side = 16.0;

  /// Touch distance that picks a handle; covers a 48 dp target.
  static const _grabRadius = 24.0;

  @override
  State<TrimTimeline> createState() => _TrimTimelineState();
}

class _TrimTimelineState extends State<TrimTimeline> {
  _Grab? _grab;

  /// Range during a drag; several events can arrive before the parent
  /// rebuilds, so each builds on this.
  double? _liveStart;
  double? _liveEnd;

  double get _start => _liveStart ?? widget.start;
  double get _end => _liveEnd ?? widget.end;

  /// Shortest range allowed: half a second, or the whole file if shorter.
  double get _minGap => widget.duration < 0.5 ? widget.duration : 0.5;

  double _time(double dx, double width) =>
      ((dx - TrimTimeline._side) / width * widget.duration).clamp(
        0.0,
        widget.duration,
      );

  double _x(double time, double width) =>
      TrimTimeline._side + time / widget.duration * width;

  void _begin(Offset p, double width) {
    final toStart = (p.dx - _x(_start, width)).abs();
    final toEnd = (p.dx - _x(_end, width)).abs();
    if (toStart <= TrimTimeline._grabRadius ||
        toEnd <= TrimTimeline._grabRadius) {
      _grab = toStart <= toEnd ? _Grab.start : _Grab.end;
    } else {
      _grab = _Grab.seek;
      widget.onSeek(_time(p.dx, width));
    }
  }

  void _move(Offset p, double width) {
    final t = _time(p.dx, width);
    switch (_grab) {
      case _Grab.start:
        _liveStart = t.clamp(0.0, _end - _minGap);
        widget.onRangeChanged(_liveStart!, _end);
        widget.onSeek(_liveStart!);
      case _Grab.end:
        _liveEnd = t.clamp(_start + _minGap, widget.duration);
        widget.onRangeChanged(_start, _liveEnd!);
        widget.onSeek(_liveEnd!);
      case _Grab.seek:
        widget.onSeek(t);
      case null:
        break;
    }
  }

  void _finish() {
    _grab = null;
    _liveStart = null;
    _liveEnd = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - TrimTimeline._side * 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTapDown: (d) => widget.onSeek(_time(d.localPosition.dx, width)),
          onHorizontalDragStart: (d) => _begin(d.localPosition, width),
          onHorizontalDragUpdate: (d) => _move(d.localPosition, width),
          onHorizontalDragEnd: (_) => _finish(),
          onHorizontalDragCancel: _finish,
          child: SizedBox(
            height: TrimTimeline.height + 16,
            child: Stack(
              children: [
                Positioned(
                  left: TrimTimeline._side,
                  right: TrimTimeline._side,
                  top: 8,
                  height: TrimTimeline.height,
                  child: _strip(),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RangePainter(
                      start: _x(_start, width),
                      end: _x(_end, width),
                      position: _x(
                        widget.position.clamp(0.0, widget.duration),
                        width,
                      ),
                      left: TrimTimeline._side,
                      right: TrimTimeline._side + width,
                      handle: AppTheme.accent,
                      ink: AppTheme.palette.shadow,
                      playhead: AppTheme.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _strip() {
    if (widget.thumbnails.isEmpty) {
      return Container(color: AppTheme.muted);
    }
    final pixels =
        (TrimTimeline.height * MediaQuery.devicePixelRatioOf(context)).round();
    return Row(
      children: [
        for (final path in widget.thumbnails)
          Expanded(
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              height: TrimTimeline.height,
              cacheHeight: pixels,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Container(color: AppTheme.muted),
            ),
          ),
      ],
    );
  }
}

class _RangePainter extends CustomPainter {
  final double start;
  final double end;
  final double position;
  final double left;
  final double right;
  final Color handle;
  final Color ink;
  final Color playhead;

  _RangePainter({
    required this.start,
    required this.end,
    required this.position,
    required this.left,
    required this.right,
    required this.handle,
    required this.ink,
    required this.playhead,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const top = 8.0;
    const height = TrimTimeline.height;
    final shade = Paint()..color = ink.withAlpha(0xAA);
    // Dim what will be cut away.
    canvas.drawRect(Rect.fromLTRB(left, top, start, top + height), shade);
    canvas.drawRect(Rect.fromLTRB(end, top, right, top + height), shade);
    // Frame around the kept range.
    final keep = Rect.fromLTRB(start, top, end, top + height);
    canvas.drawRect(
      keep,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = handle,
    );
    // Handles: yellow bars with a dark grip line.
    for (final x in [start, end]) {
      final bar = Rect.fromCenter(
        center: Offset(x, top + height / 2),
        width: 14,
        height: height + 12,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(4)),
        Paint()..color = handle,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = ink,
      );
      canvas.drawLine(
        Offset(x, top + height / 2 - 10),
        Offset(x, top + height / 2 + 10),
        Paint()
          ..strokeWidth = 2
          ..color = ink,
      );
    }
    // Play position.
    canvas.drawLine(
      Offset(position, 0),
      Offset(position, size.height),
      Paint()
        ..strokeWidth = 2
        ..color = playhead,
    );
  }

  @override
  bool shouldRepaint(_RangePainter old) =>
      old.start != start ||
      old.end != end ||
      old.position != position ||
      old.right != right ||
      old.handle != handle ||
      old.ink != ink ||
      old.playhead != playhead;
}
