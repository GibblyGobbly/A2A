// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import '../../models/video_info.dart';
import 'video_info_parser.dart';

/// Reads [VideoInfo] for a file on the phone through ffmpeg-kit's FFprobe.
class VideoInfoService {
  /// Throws [FormatException] when the file is not a readable media file.
  static Future<VideoInfo> read(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final properties = session.getMediaInformation()?.getAllProperties();
    if (properties == null) {
      throw const FormatException('This file could not be read as media.');
    }
    return VideoInfoParser.parse(properties);
  }
}
