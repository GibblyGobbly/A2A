import '../models/conversion_target.dart';
import '../models/file_item.dart';

/// Single source of truth for which conversions exist. Every target listed here
/// is routed by [ConversionService]; nothing is offered that is not implemented.
class FormatCatalog {
  // Images
  static const jpg = ConversionTarget(
    id: 'jpg',
    label: 'JPG',
    extension: 'jpg',
    hint: 'Small photos. Lower quality means a smaller file.',
    settings: TargetSettings.imageLossy,
  );
  static const webp = ConversionTarget(
    id: 'webp',
    label: 'WEBP',
    extension: 'webp',
    hint: 'Usually 25-35% smaller than JPG at the same quality.',
    settings: TargetSettings.imageLossy,
  );
  static const png = ConversionTarget(
    id: 'png',
    label: 'PNG',
    extension: 'png',
    hint:
        'Lossless. Photos become much larger; use for graphics and screenshots.',
    settings: TargetSettings.imageLossless,
  );
  static const bmp = ConversionTarget(
    id: 'bmp',
    label: 'BMP',
    extension: 'bmp',
    hint: 'Uncompressed bitmap. Very large files.',
    settings: TargetSettings.imageLossless,
  );
  static const gifImage = ConversionTarget(
    id: 'gif',
    label: 'GIF',
    extension: 'gif',
    hint: 'Limited to 256 colours.',
    settings: TargetSettings.imageLossless,
  );
  static const ico = ConversionTarget(
    id: 'ico',
    label: 'ICO',
    extension: 'ico',
    hint: 'Icon file, resized to fit 256 x 256.',
  );
  static const imagePdf = ConversionTarget(
    id: 'pdf',
    label: 'PDF',
    extension: 'pdf',
    hint: 'One PDF per image, embedded as JPG.',
    settings: TargetSettings.imagePdf,
    group: 'Make PDF',
  );
  static const imagesToOnePdf = ConversionTarget(
    id: 'pdf-merge',
    label: 'ONE PDF',
    extension: 'pdf',
    hint: 'All images as pages of a single PDF, in list order.',
    settings: TargetSettings.imagePdf,
    combinesInputs: true,
    group: 'Make PDF',
  );
  static const gifToMp4 = ConversionTarget(
    id: 'mp4',
    label: 'MP4',
    extension: 'mp4',
    hint: 'Animated GIF to H.264 video. Usually far smaller.',
    settings: TargetSettings.video,
  );

  // Video
  static const mp4 = ConversionTarget(
    id: 'mp4',
    label: 'MP4 H.264',
    extension: 'mp4',
    hint: 'Plays everywhere. Fast to encode.',
    settings: TargetSettings.video,
  );
  static const hevc = ConversionTarget(
    id: 'hevc',
    label: 'MP4 H.265',
    extension: 'mp4',
    hint: 'About 40% smaller than H.264 at the same quality. Slower to encode.',
    settings: TargetSettings.video,
  );
  static const av1 = ConversionTarget(
    id: 'av1',
    label: 'MP4 AV1',
    extension: 'mp4',
    hint:
        'Smallest files. Encoded with SVT-AV1 on all CPU cores; slower than H.264.',
    settings: TargetSettings.video,
  );
  static const webm = ConversionTarget(
    id: 'webm',
    label: 'WEBM',
    extension: 'webm',
    hint: 'VP9 video with Opus audio.',
    settings: TargetSettings.video,
  );
  static const mkv = ConversionTarget(
    id: 'mkv',
    label: 'MKV',
    extension: 'mkv',
    hint: 'H.264 video with AAC audio in a Matroska file.',
    settings: TargetSettings.video,
  );
  static const gifVideo = ConversionTarget(
    id: 'gif',
    label: 'GIF',
    extension: 'gif',
    hint: 'Animated GIF at 12 fps. Keep clips short; GIFs grow fast.',
    settings: TargetSettings.gif,
  );

  // Audio
  static const mp3 = ConversionTarget(
    id: 'mp3',
    label: 'MP3',
    extension: 'mp3',
    hint: 'Plays everywhere.',
    settings: TargetSettings.audioLossy,
  );
  static const m4a = ConversionTarget(
    id: 'm4a',
    label: 'M4A AAC',
    extension: 'm4a',
    hint: 'Better than MP3 at the same bitrate.',
    settings: TargetSettings.audioLossy,
  );
  static const opus = ConversionTarget(
    id: 'opus',
    label: 'OPUS',
    extension: 'opus',
    hint: 'Best quality at low bitrates. 64-96 kbps is enough for most music.',
    settings: TargetSettings.audioLossy,
  );
  static const ogg = ConversionTarget(
    id: 'ogg',
    label: 'OGG',
    extension: 'ogg',
    hint: 'Vorbis audio.',
    settings: TargetSettings.audioLossy,
  );
  static const flac = ConversionTarget(
    id: 'flac',
    label: 'FLAC',
    extension: 'flac',
    hint: 'Lossless. Smaller than WAV, larger than MP3.',
  );
  static const wav = ConversionTarget(
    id: 'wav',
    label: 'WAV',
    extension: 'wav',
    hint: 'Uncompressed. Very large files.',
  );

  // Documents
  static const docPdf = ConversionTarget(
    id: 'pdf',
    label: 'PDF',
    extension: 'pdf',
    hint:
        'Text, headings, lists, tables and images. Original fonts and exact layout are not kept.',
  );
  static const docx = ConversionTarget(
    id: 'docx',
    label: 'DOCX',
    extension: 'docx',
    hint: 'Editable Word document with paragraphs and headings.',
  );
  static const txt = ConversionTarget(
    id: 'txt',
    label: 'TXT',
    extension: 'txt',
    hint: 'Plain text only.',
  );
  static const pdfToJpg = ConversionTarget(
    id: 'jpg',
    label: 'JPG',
    extension: 'jpg',
    hint: 'Every page as a JPG image at 150 dpi.',
  );
  static const pdfToPng = ConversionTarget(
    id: 'png',
    label: 'PNG',
    extension: 'png',
    hint: 'Every page as a PNG image at 150 dpi.',
  );
  static const pdfToPptx = ConversionTarget(
    id: 'pptx',
    label: 'PPTX',
    extension: 'pptx',
    hint:
        'One slide per page, as an image. Looks identical but text is not editable.',
  );
  static const mergePdfs = ConversionTarget(
    id: 'pdf-merge',
    label: 'MERGE PDF',
    extension: 'pdf',
    hint: 'Join all PDFs into one, in list order.',
    combinesInputs: true,
  );

  static const imageInputExtensions = FileItem.imageExtensions;
  static const videoInputExtensions = FileItem.videoExtensions;
  static const audioInputExtensions = FileItem.audioExtensions;
  static const documentInputExtensions = FileItem.documentExtensions;

  static List<String> inputExtensionsFor(FileCategory category) {
    switch (category) {
      case FileCategory.image:
        return imageInputExtensions;
      case FileCategory.video:
        return videoInputExtensions;
      case FileCategory.audio:
        return audioInputExtensions;
      case FileCategory.document:
        return documentInputExtensions;
      case FileCategory.unknown:
        return const [];
    }
  }

  /// Targets for one source file.
  static List<ConversionTarget> targetsForExtension(
    String extension, {
    bool av1Available = false,
  }) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    switch (FileItem.detectCategory(ext)) {
      case FileCategory.image:
        return [
          jpg,
          webp,
          png,
          if (ext == 'gif') gifToMp4,
          bmp,
          gifImage,
          ico,
          imagePdf,
        ];
      case FileCategory.video:
        return [
          mp4,
          hevc,
          if (av1Available) av1,
          webm,
          mkv,
          gifVideo,
          for (final t in [mp3, m4a, flac, wav]) t.inGroup('Extract audio'),
        ];
      case FileCategory.audio:
        return [mp3, m4a, opus, ogg, flac, wav];
      case FileCategory.document:
        switch (ext) {
          case 'pdf':
            return [
              docx,
              txt,
              for (final t in [pdfToJpg, pdfToPng, pdfToPptx])
                t.inGroup('Export pages'),
            ];
          case 'docx':
          case 'pptx':
            return [docPdf, txt];
          case 'txt':
            return [docPdf, docx];
          case 'md':
            return [docPdf, docx, txt];
        }
        return const [];
      case FileCategory.unknown:
        return const [];
    }
  }

  /// Targets valid for every selected file, plus combine targets when several
  /// inputs can be merged into one output.
  static List<ConversionTarget> targetsFor(
    List<FileItem> files, {
    bool av1Available = false,
  }) {
    if (files.isEmpty) return const [];
    var common = targetsForExtension(
      files.first.extension,
      av1Available: av1Available,
    );
    for (final file in files.skip(1)) {
      final ids = targetsForExtension(
        file.extension,
        av1Available: av1Available,
      ).map((t) => t.id).toSet();
      common = common.where((t) => ids.contains(t.id)).toList();
    }
    if (files.length > 1) {
      if (files.every((f) => f.category == FileCategory.image)) {
        common = [...common, imagesToOnePdf];
      } else if (files.every((f) => f.extension == 'pdf')) {
        common = [mergePdfs.inGroup('Merge'), ...common];
      }
    }
    return common;
  }

  /// The most useful default: compress to the same format where possible.
  static ConversionTarget? defaultTarget(
    List<FileItem> files,
    List<ConversionTarget> targets,
  ) {
    if (targets.isEmpty) return null;
    final ext = files.first.extension == 'jpeg' ? 'jpg' : files.first.extension;
    if (files.first.category == FileCategory.image) {
      return targets.firstWhere(
        (t) => t.id == ext && t.settings == TargetSettings.imageLossy,
        orElse: () => targets.first,
      );
    }
    if (files.first.category == FileCategory.audio) {
      return targets.firstWhere(
        (t) => t.id == ext,
        orElse: () => targets.first,
      );
    }
    return targets.first;
  }
}
