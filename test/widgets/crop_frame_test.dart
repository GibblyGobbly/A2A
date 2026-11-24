// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_converter/models/image_edit.dart';
import 'package:universal_converter/widgets/crop_frame.dart';

/// Hosts a [CropFrame] and keeps its rectangle in state, as the crop screen does.
class _Host extends StatefulWidget {
  final double? ratio;
  final ValueChanged<NormRect> onRect;
  final NormRect initial;
  final double inset;

  const _Host({
    required this.ratio,
    required this.onRect,
    this.initial = const NormRect(0.25, 0.25, 0.5, 0.5),
    this.inset = 0,
  });

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late NormRect _rect = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: CropFrame(
          size: const Size(400, 200),
          inset: widget.inset,
          rect: _rect,
          ratio: widget.ratio,
          onChanged: (r) {
            setState(() => _rect = r);
            widget.onRect(r);
          },
        ),
      ),
    );
  }
}

void main() {
  late NormRect last;

  testWidgets('dragging inside moves the frame without resizing it', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(ratio: null, onRect: (r) => last = r));
    await tester.dragFrom(const Offset(200, 100), const Offset(40, 20));
    expect(last.width, closeTo(0.5, 1e-9));
    expect(last.left, closeTo(0.35, 0.01));
    expect(last.top, closeTo(0.35, 0.01));
  });

  testWidgets('a free corner drag resizes from the opposite corner', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(ratio: null, onRect: (r) => last = r));
    // Bottom-right corner sits at (300, 150).
    await tester.dragFrom(const Offset(300, 150), const Offset(40, 20));
    expect(last.left, closeTo(0.25, 1e-9));
    expect(last.top, closeTo(0.25, 1e-9));
    expect(last.right, greaterThan(0.75));
    expect(last.bottom, greaterThan(0.75));
  });

  testWidgets('a locked square stays square in pixels', (tester) async {
    await tester.pumpWidget(_Host(ratio: 1, onRect: (r) => last = r));
    await tester.dragFrom(const Offset(300, 150), const Offset(-60, 0));
    final widthPx = last.width * 400;
    final heightPx = last.height * 200;
    expect(widthPx, closeTo(heightPx, 0.5));
  });

  testWidgets('a corner on the image edge can be grabbed from outside it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Host(
        ratio: null,
        inset: 24,
        initial: const NormRect(0, 0, 0.5, 0.5),
        onRect: (r) => last = r,
      ),
    );
    // The image starts at (24, 24); touch 12 px outside its top-left corner.
    await tester.dragFrom(const Offset(12, 12), const Offset(40, 20));
    expect(last.left, greaterThan(0.05));
    expect(last.top, greaterThan(0.05));
    expect(last.right, closeTo(0.5, 1e-9));
  });

  test('fitted frame matches the requested shape', () {
    // A 16:9 crop on a 4:3 photo.
    final r = CropFrame.fitted(16 / 9, 4 / 3);
    expect(r.width * 4 / (r.height * 3), closeTo(16 / 9, 1e-9));
    expect(r.right, lessThanOrEqualTo(1));
    expect(r.bottom, lessThanOrEqualTo(1));
  });
}
