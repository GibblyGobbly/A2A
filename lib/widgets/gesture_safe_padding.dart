// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Keeps [child] out of the system back-gesture strips at the screen edges, so
/// drag handles near the side of an image are never taken by the system.
///
/// [pagePadding] is the horizontal padding the page already applies.
class GestureSafePadding extends StatelessWidget {
  final Widget child;
  final double pagePadding;

  const GestureSafePadding({
    super.key,
    required this.child,
    this.pagePadding = 16,
  });

  /// Room left between the gesture strip and a handle.
  static const _margin = 8.0;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.systemGestureInsetsOf(context);
    double extra(double inset) =>
        math.max(0, inset + _margin - pagePadding).toDouble();
    return Padding(
      padding: EdgeInsets.only(
        left: extra(insets.left),
        right: extra(insets.right),
      ),
      child: child,
    );
  }
}
