// SPDX-License-Identifier: GPL-3.0-or-later

import '../../../models/video_info.dart';
import 'encode_args.dart';

/// FFmpeg arguments for trim, rotate, flip and mute. Arguments are lists, so
/// file names with spaces or quotes are safe.
class EditCommands {
  static const _head = ['-y', '-hide_banner'];
  static const _streams = [
    '-map',
    '0:v?',
    '-map',
    '0:a?',
    '-map_metadata',
    '0',
  ];

  static String _seconds(double s) => s.toStringAsFixed(3);

  static List<String> _tail(String output) => output.endsWith('.mp4')
      ? EncodeArgs.mp4Tail(output)
      : ['-threads', '8', output];

  /// Cuts without re-encoding. The start snaps to the keyframe at or before
  /// [start], so the clip can begin up to a couple of seconds early.
  static List<String> trimCopy({
    required String input,
    required String output,
    required double start,
    required double end,
  }) => [
    ..._head,
    '-ss',
    _seconds(start),
    '-i',
    input,
    '-t',
    _seconds(end - start),
    ..._streams,
    '-c',
    'copy',
    '-avoid_negative_ts',
    'make_zero',
    ..._tail(output),
  ];

  /// Frame-exact cut; re-encodes the clip. Output is MP4.
  static List<String> trimPrecise({
    required String input,
    required String output,
    required double start,
    required double end,
    required VideoInfo info,
    required VideoEncoderKind encoder,
  }) => [
    ..._head,
    '-ss',
    _seconds(start),
    '-i',
    input,
    '-t',
    _seconds(end - start),
    ..._streams,
    if (info.hasVideo) ...EncodeArgs.video(encoder, info),
    ...EncodeArgs.audioForMp4(info),
    ...EncodeArgs.mp4Tail(output),
  ];

  /// Clockwise display rotation after turning by [quarterTurns]. FFmpeg's
  /// `-display_rotation` takes the angle counter-clockwise.
  static int newRotation(VideoInfo info, int quarterTurns) =>
      (info.rotation + quarterTurns * 90) % 360;

  /// Rotates by rewriting the display rotation only: instant and lossless.
  /// Players apply it when showing the video. Output must be MP4 or MOV.
  static List<String> rotateCopy({
    required String input,
    required String output,
    required VideoInfo info,
    required int quarterTurns,
  }) {
    final clockwise = newRotation(info, quarterTurns);
    return [
      ..._head,
      '-display_rotation:v:0',
      '${(360 - clockwise) % 360}',
      '-i',
      input,
      ..._streams,
      '-c',
      'copy',
      ...EncodeArgs.mp4Tail(output),
    ];
  }

  /// Mirrors the picture as it is shown (after rotation), and optionally turns
  /// it. Needs a re-encode; audio is copied where possible.
  static List<String> transform({
    required String input,
    required String output,
    required VideoInfo info,
    required VideoEncoderKind encoder,
    int quarterTurns = 0,
    bool flipHorizontal = false,
    bool flipVertical = false,
  }) {
    final filters = [
      if (flipHorizontal) 'hflip',
      if (flipVertical) 'vflip',
      ...switch (quarterTurns % 4) {
        1 => ['transpose=1'],
        2 => ['hflip', 'vflip'],
        3 => ['transpose=2'],
        _ => <String>[],
      },
      // 4:2:0 encoders need even dimensions.
      'scale=trunc(iw/2)*2:trunc(ih/2)*2',
    ];
    return [
      ..._head,
      '-i',
      input,
      ..._streams,
      '-vf',
      filters.join(','),
      ...EncodeArgs.video(encoder, info),
      ...EncodeArgs.audioForMp4(info),
      ...EncodeArgs.mp4Tail(output),
    ];
  }

  /// Drops every audio track without touching the video.
  static List<String> mute({required String input, required String output}) => [
    ..._head,
    '-i',
    input,
    '-map',
    '0:v',
    '-map_metadata',
    '0',
    '-c',
    'copy',
    '-an',
    ..._tail(output),
  ];
}
