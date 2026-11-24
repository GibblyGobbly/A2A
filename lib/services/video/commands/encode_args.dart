// SPDX-License-Identifier: GPL-3.0-or-later

import '../../../models/video_info.dart';

/// Which encoder writes re-encoded video.
enum VideoEncoderKind {
  /// The phone's video chip through MediaCodec: fast, light on battery.
  hardware,

  /// libx264 on the CPU: slower, used when the hardware encoder fails.
  software,
}

/// Encoder arguments shared by every tool that has to re-encode video.
class EncodeArgs {
  /// Bitrate for hardware encodes when the source does not report one.
  static const fallbackBitrate = 8000000;

  /// Hardware encoders are bitrate driven. Edits keep the source bitrate so
  /// quality stays the same, within sane limits.
  static int hardwareBitrate(VideoInfo info) {
    final source = info.videoBitrate ?? info.bitrate;
    if (source == null || source <= 0) return fallbackBitrate;
    return source.clamp(1000000, 50000000);
  }

  static List<String> video(VideoEncoderKind kind, VideoInfo info) {
    switch (kind) {
      case VideoEncoderKind.hardware:
        return [
          '-c:v',
          'h264_mediacodec',
          '-b:v',
          '${hardwareBitrate(info)}',
          '-pix_fmt',
          'nv12',
        ];
      case VideoEncoderKind.software:
        return [
          '-c:v',
          'libx264',
          '-preset',
          'veryfast',
          '-crf',
          '20',
          '-pix_fmt',
          'yuv420p',
        ];
    }
  }

  /// Audio codecs an MP4 file can hold as they are.
  static const _mp4Audio = {'aac', 'mp3', 'alac', 'ac3', 'eac3', 'opus'};

  /// Copies the audio when MP4 can hold it, otherwise converts it to AAC.
  static List<String> audioForMp4(VideoInfo info) {
    if (!info.hasAudio) return const ['-an'];
    if (_mp4Audio.contains(info.audioCodec)) return const ['-c:a', 'copy'];
    return const ['-c:a', 'aac', '-b:a', '192k'];
  }

  /// Ends every MP4 command: index at the front for streaming, all cores.
  static List<String> mp4Tail(String output) => [
    '-movflags',
    '+faststart',
    '-threads',
    '8',
    output,
  ];
}
