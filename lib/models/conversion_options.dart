/// Output quality presets for video encodes. Each preset maps to a codec-specific
/// CRF and to a ceiling relative to the source bitrate, so a re-encode never
/// produces a file larger than the source at the same resolution.
enum VideoQuality {
  high('HIGH'),
  balanced('BALANCED'),
  small('SMALLEST');

  final String label;
  const VideoQuality(this.label);
}

/// How lossy image and video output is sized: by a quality level, or by a
/// target size relative to the original file.
enum CompressionMode {
  quality('QUALITY'),
  targetSize('TARGET SIZE');

  final String label;
  const CompressionMode(this.label);
}

/// Page size for PDFs built from images. [fit] sizes every page to its image.
enum PdfPageSize {
  fit('FIT IMAGE'),
  a4('A4'),
  letter('LETTER');

  final String label;
  const PdfPageSize(this.label);
}

enum PdfOrientation {
  auto('AUTO'),
  portrait('PORTRAIT'),
  landscape('LANDSCAPE');

  final String label;
  const PdfOrientation(this.label);
}

enum PdfMargin {
  none('NONE', 0),
  small('SMALL', 18),
  normal('NORMAL', 36);

  final String label;

  /// Margin in PDF points (1/72 inch).
  final double points;
  const PdfMargin(this.label, this.points);
}

class ConversionOptions {
  final CompressionMode compressionMode;

  final PdfPageSize pdfPageSize;
  final PdfOrientation pdfOrientation;
  final PdfMargin pdfMargin;

  /// Target output size as a percentage of the input, used in [CompressionMode.targetSize].
  final int targetSizePercent;

  /// Lossy image quality, 10 to 100. Applies to JPG, WEBP and image-to-PDF.
  final int imageQuality;

  /// Longest edge in pixels for image output. Null keeps the original size.
  final int? maxImageDimension;

  final VideoQuality videoQuality;

  /// Short edge in pixels for video output (1080, 720, 480). Null keeps the original.
  final int? maxVideoShortEdge;

  /// Bitrate for lossy audio output (MP3, M4A, OPUS, OGG).
  final int audioBitrateKbps;

  const ConversionOptions({
    this.compressionMode = CompressionMode.quality,
    this.pdfPageSize = PdfPageSize.fit,
    this.pdfOrientation = PdfOrientation.auto,
    this.pdfMargin = PdfMargin.none,
    this.targetSizePercent = 50,
    this.imageQuality = 75,
    this.maxImageDimension,
    this.videoQuality = VideoQuality.balanced,
    this.maxVideoShortEdge,
    this.audioBitrateKbps = 128,
  });

  bool get usesTargetSize => compressionMode == CompressionMode.targetSize;

  /// Nullable fields take a getter so callers can reset them to null explicitly.
  ConversionOptions copyWith({
    CompressionMode? compressionMode,
    PdfPageSize? pdfPageSize,
    PdfOrientation? pdfOrientation,
    PdfMargin? pdfMargin,
    int? targetSizePercent,
    int? imageQuality,
    int? Function()? maxImageDimension,
    VideoQuality? videoQuality,
    int? Function()? maxVideoShortEdge,
    int? audioBitrateKbps,
  }) {
    return ConversionOptions(
      compressionMode: compressionMode ?? this.compressionMode,
      pdfPageSize: pdfPageSize ?? this.pdfPageSize,
      pdfOrientation: pdfOrientation ?? this.pdfOrientation,
      pdfMargin: pdfMargin ?? this.pdfMargin,
      targetSizePercent: targetSizePercent ?? this.targetSizePercent,
      imageQuality: imageQuality ?? this.imageQuality,
      maxImageDimension: maxImageDimension != null
          ? maxImageDimension()
          : this.maxImageDimension,
      videoQuality: videoQuality ?? this.videoQuality,
      maxVideoShortEdge: maxVideoShortEdge != null
          ? maxVideoShortEdge()
          : this.maxVideoShortEdge,
      audioBitrateKbps: audioBitrateKbps ?? this.audioBitrateKbps,
    );
  }
}
