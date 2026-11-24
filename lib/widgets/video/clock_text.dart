// SPDX-License-Identifier: GPL-3.0-or-later

/// "1:05" or "1:02:09"; with [tenths] "1:05.3".
String formatClock(double seconds, {bool tenths = false}) {
  final s = seconds < 0 ? 0.0 : seconds;
  final whole = s.floor();
  final h = whole ~/ 3600;
  final m = (whole % 3600) ~/ 60;
  final sec = whole % 60;
  final base = h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
      : '$m:${sec.toString().padLeft(2, '0')}';
  if (!tenths) return base;
  return '$base.${((s - whole) * 10).floor()}';
}
