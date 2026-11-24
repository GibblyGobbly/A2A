// SPDX-License-Identifier: GPL-3.0-or-later

/// What the image info tool shows about one file.
class ImageDetails {
  final String format;
  final int? width;
  final int? height;
  final int sizeBytes;
  final String? cameraMake;
  final String? cameraModel;

  /// Capture time from the camera, for example "2026-05-01 14:03".
  final String? takenAt;
  final double? latitude;
  final double? longitude;
  final bool hasMetadata;

  const ImageDetails({
    required this.format,
    required this.sizeBytes,
    this.width,
    this.height,
    this.cameraMake,
    this.cameraModel,
    this.takenAt,
    this.latitude,
    this.longitude,
    this.hasMetadata = false,
  });

  bool get hasLocation => latitude != null && longitude != null;

  double? get megapixels =>
      width == null || height == null ? null : width! * height! / 1000000;

  String? get camera {
    final parts = [
      cameraMake,
      cameraModel,
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);
    if (parts.isEmpty) return null;
    // Many phones repeat the make inside the model ("Google Pixel 8").
    final list = parts.toList();
    if (list.length == 2 &&
        list[1].toLowerCase().startsWith(list[0].toLowerCase())) {
      return list[1];
    }
    return list.join(' ');
  }
}
