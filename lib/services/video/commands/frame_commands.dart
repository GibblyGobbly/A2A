// SPDX-License-Identifier: GPL-3.0-or-later

/// Which frames to save as pictures.
enum FrameMode {
  single('ONE FRAME'),
  interval('EVERY FEW SECONDS'),
  scenes('SCENE CHANGES'),
  all('EVERY FRAME');

  final String label;
  const FrameMode(this.label);
}

/// Saves video frames as JPG or PNG files.
class FrameCommands {
  /// Scene change score above which a frame starts a new scene (0 to 1).
  static const sceneThreshold = 0.3;

  /// File name pattern for numbered frames inside [directory].
  static String pattern(String directory, String baseName, String extension) =>
      '$directory/${baseName}_%05d.$extension';

  static List<String> _quality(String extension) =>
      extension == 'jpg' ? const ['-q:v', '2'] : const [];

  /// One frame at [seconds], at full resolution.
  static List<String> single({
    required String input,
    required String output,
    required double seconds,
  }) => [
    '-y',
    '-hide_banner',
    '-ss',
    seconds.toStringAsFixed(3),
    '-i',
    input,
    '-map',
    '0:v:0',
    '-frames:v',
    '1',
    ..._quality(output.split('.').last),
    '-threads',
    '8',
    output,
  ];

  /// Numbered frames into [outputPattern] (see [pattern]).
  static List<String> many({
    required String input,
    required String outputPattern,
    required FrameMode mode,
    double everySeconds = 1,
  }) {
    final extension = outputPattern.split('.').last;
    final timing = switch (mode) {
      FrameMode.interval => ['-vf', 'fps=1/${everySeconds.toStringAsFixed(3)}'],
      FrameMode.scenes => [
        '-vf',
        "select='gt(scene,$sceneThreshold)'",
        '-fps_mode',
        'vfr',
      ],
      FrameMode.all || FrameMode.single => ['-fps_mode', 'passthrough'],
    };
    return [
      '-y',
      '-hide_banner',
      '-i',
      input,
      '-map',
      '0:v:0',
      ...timing,
      ..._quality(extension),
      '-threads',
      '8',
      outputPattern,
    ];
  }

  /// Roughly how many pictures [mode] produces, for the warning shown before
  /// starting. Null when it cannot be known (scene changes).
  static int? estimateCount(
    FrameMode mode, {
    required double durationSeconds,
    required double? fps,
    double everySeconds = 1,
  }) => switch (mode) {
    FrameMode.single => 1,
    FrameMode.interval => (durationSeconds / everySeconds).ceil(),
    FrameMode.all => fps == null ? null : (durationSeconds * fps).round(),
    FrameMode.scenes => null,
  };
}
