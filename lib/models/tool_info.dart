// SPDX-License-Identifier: GPL-3.0-or-later

/// Sections the workspace lists tools under, in display order.
enum ToolGroup {
  edit('EDIT'),
  convert('CONVERT AND SHRINK'),
  extract('SAVE PARTS'),
  privacy('PRIVACY'),
  details('DETAILS');

  final String label;
  const ToolGroup(this.label);
}

/// Every tool the workspace can open. Each one has a screen and a service.
enum ToolId {
  convert,
  imageCrop,
  imageRotate,
  imageResize,
  imageCompressToSize,
  imageRedact,
  imageStripMetadata,
  imageInfo,
  mediaTrim,
  videoRotate,
  videoMute,
  videoExtractAudio,
  videoFrames,
  mediaInfo,
}

/// A tool as shown in the workspace.
class ToolInfo {
  final ToolId id;
  final String label;
  final String description;
  final ToolGroup group;

  /// True when the tool works on one file at a time.
  final bool singleFile;

  const ToolInfo({
    required this.id,
    required this.label,
    required this.description,
    required this.group,
    this.singleFile = false,
  });

  @override
  bool operator ==(Object other) => other is ToolInfo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
