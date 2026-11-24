// SPDX-License-Identifier: GPL-3.0-or-later

/// What FFprobe reports about a video or audio file.
class VideoInfo {
  final double durationSeconds;

  /// Stored frame size, before rotation.
  final int? width;
  final int? height;

  /// Clockwise rotation applied when the video is shown: 0, 90, 180 or 270.
  final int rotation;
  final double? fps;
  final String? videoCodec;
  final String? audioCodec;
  final int? audioChannels;
  final int? audioSampleRate;

  /// Whole-file bitrate in bits per second.
  final int? bitrate;
  final int? videoBitrate;
  final bool hasVideo;
  final bool hasAudio;
  final bool isHdr;
  final String? container;

  const VideoInfo({
    required this.durationSeconds,
    this.width,
    this.height,
    this.rotation = 0,
    this.fps,
    this.videoCodec,
    this.audioCodec,
    this.audioChannels,
    this.audioSampleRate,
    this.bitrate,
    this.videoBitrate,
    this.hasVideo = false,
    this.hasAudio = false,
    this.isHdr = false,
    this.container,
  });

  /// Width as shown, after rotation.
  int? get displayWidth => rotation % 180 == 90 ? height : width;
  int? get displayHeight => rotation % 180 == 90 ? width : height;

  double get durationMs => durationSeconds * 1000;

  /// Number of frames in the whole video, or null when unknown.
  int? get frameCount => fps == null || durationSeconds <= 0
      ? null
      : (fps! * durationSeconds).round();
}
