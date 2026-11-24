// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/file_item.dart';
import '../models/tool_info.dart';

/// Which tools apply to a set of files. Only tools with a working pipeline are
/// listed; the workspace never shows an action that cannot run.
class ToolCatalog {
  static const imageCrop = ToolInfo(
    id: ToolId.imageCrop,
    label: 'Crop',
    description: 'Free or fixed shape: square, 4:5, 16:9 and more.',
    group: ToolGroup.edit,
    singleFile: true,
  );
  static const imageRotate = ToolInfo(
    id: ToolId.imageRotate,
    label: 'Rotate and flip',
    description: 'Turn sideways photos upright or mirror them.',
    group: ToolGroup.edit,
  );
  static const imageResize = ToolInfo(
    id: ToolId.imageResize,
    label: 'Resize',
    description: 'Exact pixels, like 600 x 600, or a percentage.',
    group: ToolGroup.edit,
  );
  static const imageCompressToSize = ToolInfo(
    id: ToolId.imageCompressToSize,
    label: 'Compress to size',
    description: 'Fit an upload limit, like under 100 KB.',
    group: ToolGroup.convert,
  );
  static const convertImage = ToolInfo(
    id: ToolId.convert,
    label: 'Convert or compress',
    description: 'JPG, WEBP, PNG and more. Make a PDF.',
    group: ToolGroup.convert,
  );
  static const imageRedact = ToolInfo(
    id: ToolId.imageRedact,
    label: 'Blur or hide parts',
    description: 'Cover numbers, faces or addresses before sharing.',
    group: ToolGroup.privacy,
    singleFile: true,
  );
  static const imageStripMetadata = ToolInfo(
    id: ToolId.imageStripMetadata,
    label: 'Remove location and camera data',
    description: 'Strip hidden details. Photo quality stays the same.',
    group: ToolGroup.privacy,
  );
  static const imageInfo = ToolInfo(
    id: ToolId.imageInfo,
    label: 'Photo details',
    description: 'Size, date, camera and whether it holds a location.',
    group: ToolGroup.details,
    singleFile: true,
  );
  static const mediaTrim = ToolInfo(
    id: ToolId.mediaTrim,
    label: 'Trim',
    description: 'Keep only the part you want. Instant, no quality loss.',
    group: ToolGroup.edit,
    singleFile: true,
  );
  static const videoRotate = ToolInfo(
    id: ToolId.videoRotate,
    label: 'Rotate and flip',
    description: 'Fix sideways videos instantly, or mirror them.',
    group: ToolGroup.edit,
  );
  static const videoMute = ToolInfo(
    id: ToolId.videoMute,
    label: 'Remove sound',
    description: 'Silent copy. Instant, the picture is untouched.',
    group: ToolGroup.edit,
  );
  static const videoExtractAudio = ToolInfo(
    id: ToolId.videoExtractAudio,
    label: 'Save the sound',
    description: 'Audio only, in its original quality.',
    group: ToolGroup.extract,
  );
  static const videoFrames = ToolInfo(
    id: ToolId.videoFrames,
    label: 'Save frames as pictures',
    description: 'One frame, every few seconds, scene changes or all.',
    group: ToolGroup.extract,
    singleFile: true,
  );
  static const mediaInfo = ToolInfo(
    id: ToolId.mediaInfo,
    label: 'Details',
    description: 'Length, size, frame rate, codecs and bitrate.',
    group: ToolGroup.details,
    singleFile: true,
  );
  static const convertMedia = ToolInfo(
    id: ToolId.convert,
    label: 'Convert or compress',
    description: 'Change the format or make the file smaller.',
    group: ToolGroup.convert,
  );
  static const convertDocument = ToolInfo(
    id: ToolId.convert,
    label: 'Convert',
    description: 'PDF, Word, text, images. Merge PDFs.',
    group: ToolGroup.convert,
  );

  static const _imageTools = [
    imageCrop,
    imageRotate,
    imageResize,
    imageCompressToSize,
    convertImage,
    imageRedact,
    imageStripMetadata,
    imageInfo,
  ];

  /// Tools for [files], which all share one category. Empty for no files.
  static List<ToolInfo> toolsFor(List<FileItem> files) {
    if (files.isEmpty) return const [];
    switch (files.first.category) {
      case FileCategory.image:
        return _imageTools;
      case FileCategory.video:
        return const [
          mediaTrim,
          videoRotate,
          videoMute,
          convertMedia,
          videoExtractAudio,
          videoFrames,
          mediaInfo,
        ];
      case FileCategory.audio:
        return const [mediaTrim, convertMedia, mediaInfo];
      case FileCategory.document:
        return const [convertDocument];
      case FileCategory.unknown:
        return const [];
    }
  }

  /// Why [tool] cannot run on [files] right now, or null when it can.
  static String? blockedReason(ToolInfo tool, List<FileItem> files) {
    if (tool.singleFile && files.length > 1) {
      return files.first.category == FileCategory.image
          ? 'One photo at a time. Remove the others to use it.'
          : 'One file at a time. Remove the others to use it.';
    }
    return null;
  }
}
