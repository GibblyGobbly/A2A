class ConversionOptions {
  // Image options
  int imageQuality; // 1 - 100
  bool progressiveJpeg;
  int? targetWidth;
  int? targetHeight;
  bool keepAspectRatio;

  // Audio / Video options
  String audioBitrate; // '64k', '128k', '192k', '256k', '320k'
  String audioSampleRate; // '44100', '48000'
  int audioChannels; // 1 (mono), 2 (stereo)

  // Video AV1 / Transcoding options
  String videoCodec; // 'libsvtav1', 'libaom-av1', 'libx264', 'libx265', 'libvpx-vp9'
  int videoCrf; // 0 - 63 (e.g. 28-35 for AV1, 18-23 for x264)
  int videoPreset; // 0 - 12 for SVT-AV1, or ultrafast - placebo
  String videoResolution; // 'Original', '1080p', '720p', '480p', '360p'
  int videoFps; // 0 = original, 24, 30, 60

  // Document options
  String docPageRange; // 'all', '1-5', etc.
  bool extractImagesFromPdf;

  ConversionOptions({
    this.imageQuality = 70,
    this.progressiveJpeg = true,
    this.targetWidth,
    this.targetHeight,
    this.keepAspectRatio = true,
    this.audioBitrate = '192k',
    this.audioSampleRate = '44100',
    this.audioChannels = 2,
    this.videoCodec = 'libsvtav1',
    this.videoCrf = 30,
    this.videoPreset = 6,
    this.videoResolution = 'Original',
    this.videoFps = 0,
    this.docPageRange = 'all',
    this.extractImagesFromPdf = false,
  });

  ConversionOptions copyWith({
    int? imageQuality,
    bool? progressiveJpeg,
    int? targetWidth,
    int? targetHeight,
    bool? keepAspectRatio,
    String? audioBitrate,
    String? audioSampleRate,
    int? audioChannels,
    String? videoCodec,
    int? videoCrf,
    int? videoPreset,
    String? videoResolution,
    int? videoFps,
    String? docPageRange,
    bool? extractImagesFromPdf,
  }) {
    return ConversionOptions(
      imageQuality: imageQuality ?? this.imageQuality,
      progressiveJpeg: progressiveJpeg ?? this.progressiveJpeg,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      keepAspectRatio: keepAspectRatio ?? this.keepAspectRatio,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      audioSampleRate: audioSampleRate ?? this.audioSampleRate,
      audioChannels: audioChannels ?? this.audioChannels,
      videoCodec: videoCodec ?? this.videoCodec,
      videoCrf: videoCrf ?? this.videoCrf,
      videoPreset: videoPreset ?? this.videoPreset,
      videoResolution: videoResolution ?? this.videoResolution,
      videoFps: videoFps ?? this.videoFps,
      docPageRange: docPageRange ?? this.docPageRange,
      extractImagesFromPdf: extractImagesFromPdf ?? this.extractImagesFromPdf,
    );
  }
}
