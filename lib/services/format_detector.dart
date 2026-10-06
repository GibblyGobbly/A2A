import '../models/file_item.dart';

class FormatOption {
  final String extension;
  final String label;
  final String description;
  final FileCategory category;

  const FormatOption({
    required this.extension,
    required this.label,
    required this.description,
    required this.category,
  });
}

class FormatDetector {
  static final Map<String, List<FormatOption>> _conversionMap = {
    // Images
    'png': [
      const FormatOption(extension: 'jpg', label: 'JPG / JPEG', description: 'Lossy with quality slider', category: FileCategory.image),
      const FormatOption(extension: 'webp', label: 'WEBP', description: 'Modern web image format', category: FileCategory.image),
      const FormatOption(extension: 'bmp', label: 'BMP', description: 'Uncompressed bitmap image', category: FileCategory.image),
      const FormatOption(extension: 'gif', label: 'GIF', description: 'Graphics interchange format', category: FileCategory.image),
      const FormatOption(extension: 'ico', label: 'ICO', description: 'Application icon file', category: FileCategory.image),
      const FormatOption(extension: 'pdf', label: 'PDF', description: 'Single/Multi page PDF document', category: FileCategory.document),
    ],
    'jpg': [
      const FormatOption(extension: 'png', label: 'PNG', description: 'Lossless with transparency', category: FileCategory.image),
      const FormatOption(extension: 'webp', label: 'WEBP', description: 'Modern web image format', category: FileCategory.image),
      const FormatOption(extension: 'bmp', label: 'BMP', description: 'Uncompressed bitmap image', category: FileCategory.image),
      const FormatOption(extension: 'gif', label: 'GIF', description: 'Graphics interchange format', category: FileCategory.image),
      const FormatOption(extension: 'ico', label: 'ICO', description: 'Application icon file', category: FileCategory.image),
      const FormatOption(extension: 'pdf', label: 'PDF', description: 'PDF document', category: FileCategory.document),
    ],
    'jpeg': [
      const FormatOption(extension: 'png', label: 'PNG', description: 'Lossless with transparency', category: FileCategory.image),
      const FormatOption(extension: 'webp', label: 'WEBP', description: 'Modern web image format', category: FileCategory.image),
      const FormatOption(extension: 'bmp', label: 'BMP', description: 'Uncompressed bitmap image', category: FileCategory.image),
      const FormatOption(extension: 'gif', label: 'GIF', description: 'Graphics interchange format', category: FileCategory.image),
      const FormatOption(extension: 'pdf', label: 'PDF', description: 'PDF document', category: FileCategory.document),
    ],
    'webp': [
      const FormatOption(extension: 'png', label: 'PNG', description: 'Lossless format', category: FileCategory.image),
      const FormatOption(extension: 'jpg', label: 'JPG', description: 'Standard JPEG', category: FileCategory.image),
      const FormatOption(extension: 'bmp', label: 'BMP', description: 'Uncompressed bitmap', category: FileCategory.image),
      const FormatOption(extension: 'pdf', label: 'PDF', description: 'PDF document', category: FileCategory.document),
    ],
    'gif': [
      const FormatOption(extension: 'png', label: 'PNG', description: 'Extract first frame as PNG', category: FileCategory.image),
      const FormatOption(extension: 'jpg', label: 'JPG', description: 'Extract first frame as JPG', category: FileCategory.image),
      const FormatOption(extension: 'mp4', label: 'MP4', description: 'Convert animation to MP4 video', category: FileCategory.video),
      const FormatOption(extension: 'webm', label: 'WEBM', description: 'Convert animation to WebM video', category: FileCategory.video),
    ],

    // Video
    'mp4': [
      const FormatOption(extension: 'mp3', label: 'MP3', description: 'Extract audio stream (Fast)', category: FileCategory.audio),
      const FormatOption(extension: 'av1', label: 'AV1 (MP4)', description: 'Next-gen video compression (Ultra-fast multicore)', category: FileCategory.video),
      const FormatOption(extension: 'webm', label: 'WEBM', description: 'WebM video container (VP9 Realtime)', category: FileCategory.video),
      const FormatOption(extension: 'mkv', label: 'MKV', description: 'Matroska multimedia container', category: FileCategory.video),
      const FormatOption(extension: 'gif', label: 'GIF', description: 'Animated GIF clip', category: FileCategory.image),
      const FormatOption(extension: 'aac', label: 'AAC', description: 'Extract audio stream (AAC)', category: FileCategory.audio),
      const FormatOption(extension: 'wav', label: 'WAV', description: 'Extract uncompressed audio', category: FileCategory.audio),
      const FormatOption(extension: 'flac', label: 'FLAC', description: 'Extract lossless audio', category: FileCategory.audio),
    ],
    'mkv': [
      const FormatOption(extension: 'mp4', label: 'MP4', description: 'Standard MP4 (Fast H.264)', category: FileCategory.video),
      const FormatOption(extension: 'av1', label: 'AV1 (MP4)', description: 'AV1 compressed MP4', category: FileCategory.video),
      const FormatOption(extension: 'mp3', label: 'MP3', description: 'Extract audio to MP3', category: FileCategory.audio),
      const FormatOption(extension: 'webm', label: 'WEBM', description: 'WebM video container', category: FileCategory.video),
      const FormatOption(extension: 'wav', label: 'WAV', description: 'Extract audio to WAV', category: FileCategory.audio),
    ],
    'mov': [
      const FormatOption(extension: 'mp4', label: 'MP4', description: 'Convert to standard MP4', category: FileCategory.video),
      const FormatOption(extension: 'av1', label: 'AV1 (MP4)', description: 'AV1 compressed MP4', category: FileCategory.video),
      const FormatOption(extension: 'mp3', label: 'MP3', description: 'Extract audio to MP3', category: FileCategory.audio),
      const FormatOption(extension: 'gif', label: 'GIF', description: 'Convert to animated GIF', category: FileCategory.image),
    ],
    'webm': [
      const FormatOption(extension: 'mp4', label: 'MP4', description: 'Convert to MP4', category: FileCategory.video),
      const FormatOption(extension: 'av1', label: 'AV1 (MP4)', description: 'AV1 compressed MP4', category: FileCategory.video),
      const FormatOption(extension: 'mp3', label: 'MP3', description: 'Extract audio to MP3', category: FileCategory.audio),
      const FormatOption(extension: 'wav', label: 'WAV', description: 'Extract audio to WAV', category: FileCategory.audio),
    ],

    // Audio
    'mp3': [
      const FormatOption(extension: 'wav', label: 'WAV', description: 'Uncompressed waveform audio', category: FileCategory.audio),
      const FormatOption(extension: 'aac', label: 'AAC', description: 'Advanced Audio Coding', category: FileCategory.audio),
      const FormatOption(extension: 'flac', label: 'FLAC', description: 'Free Lossless Audio Codec', category: FileCategory.audio),
      const FormatOption(extension: 'ogg', label: 'OGG', description: 'Ogg Vorbis audio', category: FileCategory.audio),
    ],
    'wav': [
      const FormatOption(extension: 'mp3', label: 'MP3', description: 'Compress audio to MP3', category: FileCategory.audio),
      const FormatOption(extension: 'aac', label: 'AAC', description: 'Compress audio to AAC', category: FileCategory.audio),
      const FormatOption(extension: 'flac', label: 'FLAC', description: 'Convert to FLAC', category: FileCategory.audio),
    ],
    'aac': [
      const FormatOption(extension: 'mp3', label: 'MP3', description: 'Convert to MP3', category: FileCategory.audio),
      const FormatOption(extension: 'wav', label: 'WAV', description: 'Convert to WAV', category: FileCategory.audio),
    ],
    'flac': [
      const FormatOption(extension: 'mp3', label: 'MP3', description: 'Compress to MP3', category: FileCategory.audio),
      const FormatOption(extension: 'wav', label: 'WAV', description: 'Decompress to WAV', category: FileCategory.audio),
      const FormatOption(extension: 'aac', label: 'AAC', description: 'Convert to AAC', category: FileCategory.audio),
    ],

    // Documents
    'pdf': [
      const FormatOption(extension: 'docx', label: 'DOCX', description: 'Extract text & layout into Word document', category: FileCategory.document),
      const FormatOption(extension: 'pptx', label: 'PPTX', description: 'Convert pages into PowerPoint slides', category: FileCategory.document),
      const FormatOption(extension: 'txt', label: 'TXT', description: 'Extract plain text content', category: FileCategory.document),
      const FormatOption(extension: 'png', label: 'PNG', description: 'Render pages as PNG images', category: FileCategory.image),
      const FormatOption(extension: 'jpg', label: 'JPG', description: 'Render pages as JPG images', category: FileCategory.image),
    ],
    'docx': [
      const FormatOption(extension: 'pdf', label: 'PDF', description: 'Standard formatted PDF document', category: FileCategory.document),
      const FormatOption(extension: 'pptx', label: 'PPTX', description: 'Generate presentation slides from document', category: FileCategory.document),
      const FormatOption(extension: 'txt', label: 'TXT', description: 'Extract plain text', category: FileCategory.document),
    ],
    'doc': [
      const FormatOption(extension: 'pdf', label: 'PDF', description: 'Standard PDF document', category: FileCategory.document),
      const FormatOption(extension: 'docx', label: 'DOCX', description: 'Convert legacy DOC to DOCX', category: FileCategory.document),
      const FormatOption(extension: 'txt', label: 'TXT', description: 'Extract plain text', category: FileCategory.document),
    ],
    'pptx': [
      const FormatOption(extension: 'pdf', label: 'PDF', description: 'Convert presentation slides to PDF', category: FileCategory.document),
      const FormatOption(extension: 'png', label: 'PNG', description: 'Export slide images', category: FileCategory.image),
      const FormatOption(extension: 'txt', label: 'TXT', description: 'Extract presentation text', category: FileCategory.document),
    ],
    'ppt': [
      const FormatOption(extension: 'pdf', label: 'PDF', description: 'Convert presentation to PDF', category: FileCategory.document),
      const FormatOption(extension: 'pptx', label: 'PPTX', description: 'Convert legacy PPT to modern PPTX', category: FileCategory.document),
    ],
    'txt': [
      const FormatOption(extension: 'pdf', label: 'PDF', description: 'Compile text into styled PDF document', category: FileCategory.document),
      const FormatOption(extension: 'docx', label: 'DOCX', description: 'Generate formatted Word document', category: FileCategory.document),
      const FormatOption(extension: 'pptx', label: 'PPTX', description: 'Generate slide presentation', category: FileCategory.document),
    ],
    'md': [
      const FormatOption(extension: 'pdf', label: 'PDF', description: 'Render Markdown into PDF document', category: FileCategory.document),
      const FormatOption(extension: 'docx', label: 'DOCX', description: 'Render Markdown into Word document', category: FileCategory.document),
      const FormatOption(extension: 'txt', label: 'TXT', description: 'Strip Markdown formatting to text', category: FileCategory.document),
    ],
  };

  static List<FormatOption> getAvailableTargets(String sourceExtension) {
    final cleanExt = sourceExtension.toLowerCase().replaceAll('.', '');
    return _conversionMap[cleanExt] ?? _getFallbackTargets(cleanExt);
  }

  static List<FormatOption> _getFallbackTargets(String cleanExt) {
    final cat = FileItem.detectCategory(cleanExt);
    switch (cat) {
      case FileCategory.image:
        return [
          const FormatOption(extension: 'png', label: 'PNG', description: 'Lossless image', category: FileCategory.image),
          const FormatOption(extension: 'jpg', label: 'JPG', description: 'Compressed JPEG', category: FileCategory.image),
          const FormatOption(extension: 'pdf', label: 'PDF', description: 'PDF document', category: FileCategory.document),
        ];
      case FileCategory.video:
        return [
          const FormatOption(extension: 'mp4', label: 'MP4', description: 'Standard MP4', category: FileCategory.video),
          const FormatOption(extension: 'av1', label: 'AV1 (MP4)', description: 'Fast AV1 MP4', category: FileCategory.video),
          const FormatOption(extension: 'mp3', label: 'MP3', description: 'Audio extraction', category: FileCategory.audio),
        ];
      case FileCategory.audio:
        return [
          const FormatOption(extension: 'mp3', label: 'MP3', description: 'Standard MP3', category: FileCategory.audio),
          const FormatOption(extension: 'wav', label: 'WAV', description: 'Lossless WAV', category: FileCategory.audio),
        ];
      case FileCategory.document:
        return [
          const FormatOption(extension: 'pdf', label: 'PDF', description: 'PDF document', category: FileCategory.document),
          const FormatOption(extension: 'txt', label: 'TXT', description: 'Plain text', category: FileCategory.document),
        ];
      default:
        return [];
    }
  }
}
