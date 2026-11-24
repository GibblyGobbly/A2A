// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/video_info.dart';

/// Turns FFprobe's JSON (`-show_format -show_streams`) into [VideoInfo]. Pure,
/// so it is tested against the desktop ffprobe.
class VideoInfoParser {
  static VideoInfo parse(Map<dynamic, dynamic> json) {
    final format = json['format'] is Map ? json['format'] as Map : const {};
    final streams = json['streams'] is List
        ? (json['streams'] as List).whereType<Map>().toList()
        : const <Map>[];

    Map? video;
    Map? audio;
    for (final s in streams) {
      final type = s['codec_type'];
      final disposition = s['disposition'];
      // Cover art in music files is a video stream; it is not a video.
      final coverArt = disposition is Map && disposition['attached_pic'] == 1;
      if (type == 'video' && video == null && !coverArt) video = s;
      if (type == 'audio' && audio == null) audio = s;
    }

    return VideoInfo(
      durationSeconds:
          _double(format['duration']) ?? _double(video?['duration']) ?? 0,
      width: _int(video?['width']),
      height: _int(video?['height']),
      rotation: video == null ? 0 : _rotation(video),
      fps: video == null ? null : _fps(video),
      videoCodec: video?['codec_name']?.toString(),
      audioCodec: audio?['codec_name']?.toString(),
      audioChannels: _int(audio?['channels']),
      audioSampleRate: _int(audio?['sample_rate']),
      bitrate: _int(format['bit_rate']),
      videoBitrate: _int(video?['bit_rate']),
      hasVideo: video != null,
      hasAudio: audio != null,
      isHdr: const {
        'smpte2084',
        'arib-std-b67',
      }.contains(video?['color_transfer']),
      container: format['format_name']?.toString(),
    );
  }

  /// Clockwise display rotation. FFprobe reports the display matrix angle
  /// counter-clockwise (a phone portrait video shows -90), and older files
  /// carry a clockwise "rotate" tag.
  static int _rotation(Map stream) {
    final sideData = stream['side_data_list'];
    if (sideData is List) {
      for (final entry in sideData.whereType<Map>()) {
        final r = _double(entry['rotation']);
        if (r != null) return _normalize(-r.round());
      }
    }
    final tags = stream['tags'];
    if (tags is Map) {
      final r = _double(tags['rotate']);
      if (r != null) return _normalize(r.round());
    }
    return 0;
  }

  static int _normalize(int degrees) => ((degrees % 360) + 360) % 360;

  static double? _fps(Map stream) {
    for (final key in ['avg_frame_rate', 'r_frame_rate']) {
      final value = stream[key]?.toString();
      if (value == null) continue;
      final parts = value.split('/');
      final num = double.tryParse(parts.first);
      final den = parts.length > 1 ? double.tryParse(parts[1]) : 1;
      if (num != null && den != null && num > 0 && den > 0) return num / den;
    }
    return null;
  }

  static double? _double(Object? v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  static int? _int(Object? v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
}
