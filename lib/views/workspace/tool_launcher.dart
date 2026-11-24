// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../models/file_item.dart';
import '../../models/tool_info.dart';
import '../../services/video/video_tools_service.dart';
import '../tools/convert_screen.dart';
import '../tools/simple_tool_screen.dart';
import '../tools/video/frames_screen.dart';
import '../tools/video/media_info_screen.dart';
import '../tools/video/trim_screen.dart';
import '../tools/video/video_rotate_screen.dart';
import '../tools/image/compress_size_screen.dart';
import '../tools/image/crop_screen.dart';
import '../tools/image/image_info_screen.dart';
import '../tools/image/redact_screen.dart';
import '../tools/image/resize_screen.dart';
import '../tools/image/rotate_screen.dart';
import '../tools/image/strip_metadata_screen.dart';

/// Maps each tool to its icon and screen.
class ToolLauncher {
  static IconData icon(ToolId id) => switch (id) {
    ToolId.convert => Icons.swap_horiz,
    ToolId.imageCrop => Icons.crop,
    ToolId.imageRotate => Icons.rotate_right,
    ToolId.imageResize => Icons.photo_size_select_large,
    ToolId.imageCompressToSize => Icons.compress,
    ToolId.imageRedact => Icons.blur_on,
    ToolId.imageStripMetadata => Icons.location_off_outlined,
    ToolId.imageInfo => Icons.info_outline,
    ToolId.mediaTrim => Icons.content_cut,
    ToolId.videoRotate => Icons.rotate_right,
    ToolId.videoMute => Icons.volume_off_outlined,
    ToolId.videoExtractAudio => Icons.music_note_outlined,
    ToolId.videoFrames => Icons.photo_library_outlined,
    ToolId.mediaInfo => Icons.info_outline,
  };

  static Widget _screen(ToolId id, List<FileItem> files) => switch (id) {
    ToolId.convert => ConvertScreen(files: files),
    ToolId.imageCrop => CropScreen(file: files.first),
    ToolId.imageRotate => RotateScreen(files: files),
    ToolId.imageResize => ResizeScreen(files: files),
    ToolId.imageCompressToSize => CompressSizeScreen(files: files),
    ToolId.imageRedact => RedactScreen(file: files.first),
    ToolId.imageStripMetadata => StripMetadataScreen(files: files),
    ToolId.imageInfo => ImageInfoScreen(file: files.first),
    ToolId.mediaTrim => TrimScreen(file: files.first),
    ToolId.videoRotate => VideoRotateScreen(files: files),
    ToolId.videoMute => SimpleToolScreen(
      title: 'Remove sound',
      explanation:
          'Saves a copy with no audio. The picture is copied as it is, so '
          'this is instant and the quality does not change.',
      files: files,
      actionLabel: files.length == 1
          ? 'Save silent copy'
          : 'Save silent copies',
      actionIcon: Icons.volume_off_outlined,
      run: (progress) =>
          VideoToolsService.mute(files: files, onProgress: progress),
      onCancel: VideoToolsService.cancel,
    ),
    ToolId.videoExtractAudio => SimpleToolScreen(
      title: 'Save the sound',
      explanation:
          'Saves the soundtrack as an audio file. It is copied out as it is, '
          'so this is instant and keeps the original quality. To change the '
          'format, use Convert or compress.',
      files: files,
      actionLabel: files.length == 1 ? 'Save audio' : 'Save audio from each',
      actionIcon: Icons.music_note_outlined,
      run: (progress) =>
          VideoToolsService.extractAudio(files: files, onProgress: progress),
      onCancel: VideoToolsService.cancel,
    ),
    ToolId.videoFrames => FramesScreen(file: files.first),
    ToolId.mediaInfo => MediaInfoScreen(file: files.first),
  };

  /// Opens [id] on a snapshot of [files], so later changes to the workspace
  /// list do not affect a tool that is already open.
  static Future<void> open(
    BuildContext context,
    ToolId id,
    List<FileItem> files,
  ) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => _screen(id, List.of(files))));
}
