import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/conversion_options.dart';

/// Pure image transforms. Everything here is synchronous and free of Flutter
/// bindings so it can run inside `Isolate.run`.
class ImageCodec {
  static const lossyTargets = {'jpg', 'webp'};

  static String normalizeExtension(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    if (e == 'jpeg') return 'jpg';
    if (e == 'tif') return 'tiff';
    return e;
  }

  /// Decodes, applies EXIF rotation and optionally shrinks so the longest edge
  /// is at most [maxDimension]. Never upscales. Returns null when undecodable.
  static img.Image? decodeAndPrepare(Uint8List bytes, {int? maxDimension}) {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    decoded = img.bakeOrientation(decoded);
    if (maxDimension != null) {
      decoded = shrinkToFit(decoded, maxDimension);
    }
    return decoded;
  }

  static img.Image shrinkToFit(img.Image image, int maxDimension) {
    final longest = image.width > image.height ? image.width : image.height;
    if (longest <= maxDimension) return image;
    final landscape = image.width >= image.height;
    return img.copyResize(
      image,
      width: landscape ? maxDimension : null,
      height: landscape ? null : maxDimension,
      interpolation: img.Interpolation.average,
    );
  }

  static img.Image flattenOnWhite(img.Image image) {
    if (!image.hasAlpha) return image;
    final opaque = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 3,
    );
    img.fill(opaque, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(opaque, image);
    return opaque;
  }

  /// Encodes [image] to the raster format [targetExt].
  static Uint8List encode(
    img.Image image,
    String targetExt, {
    required int quality,
  }) {
    final q = quality.clamp(10, 100);
    switch (normalizeExtension(targetExt)) {
      case 'jpg':
        return img.encodeJpg(
          flattenOnWhite(image),
          quality: q,
          chroma: img.JpegChroma.yuv420,
        );
      case 'webp':
        return img.encodeWebP(image, lossless: false, quality: q, method: 4);
      case 'png':
        return img.encodePng(image, level: 9);
      case 'bmp':
        return img.encodeBmp(image);
      case 'gif':
        return img.encodeGif(image);
      case 'ico':
        return img.encodeIco(shrinkToFit(image, 256));
      default:
        throw UnsupportedError('Image format .$targetExt is not supported');
    }
  }

  /// JPEG-encodes a page for PDF embedding. JPEG keeps photo PDFs a fraction of the PNG size.
  static JpegPage toJpegPage(img.Image image, {required int quality}) {
    final flat = flattenOnWhite(image);
    final bytes = img.encodeJpg(
      flat,
      quality: quality.clamp(10, 100),
      chroma: img.JpegChroma.yuv420,
    );
    return JpegPage(bytes, flat.width, flat.height);
  }

  /// Builds a PDF with one page per image, laid out according to [layout].
  static Future<Uint8List> buildPdf(
    List<JpegPage> pages, {
    PdfLayout layout = const PdfLayout(),
  }) async {
    final doc = pw.Document(compress: true);
    for (final page in pages) {
      final image = pw.MemoryImage(page.bytes);
      final margin = layout.margin.points;
      final PdfPageFormat format;
      if (layout.pageSize == PdfPageSize.fit) {
        final contentWidth = PdfPageFormat.a4.width - margin * 2;
        format = PdfPageFormat(
          PdfPageFormat.a4.width,
          contentWidth * page.height / page.width + margin * 2,
          marginAll: margin,
        );
      } else {
        final base = layout.pageSize == PdfPageSize.letter
            ? PdfPageFormat.letter
            : PdfPageFormat.a4;
        final landscape = switch (layout.orientation) {
          PdfOrientation.auto => page.width > page.height,
          PdfOrientation.portrait => false,
          PdfOrientation.landscape => true,
        };
        format = (landscape ? base.landscape : base.portrait).copyWith(
          marginLeft: margin,
          marginRight: margin,
          marginTop: margin,
          marginBottom: margin,
        );
      }
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
    return doc.save();
  }

  /// Encodes a lossy image as close to [targetBytes] as possible without going over:
  /// the highest quality that fits, then smaller dimensions if even quality 10 is too big.
  static Uint8List encodeToTargetSize(
    img.Image image,
    String targetExt,
    int targetBytes,
  ) {
    var current = image;
    Uint8List? smallest;
    for (var shrink = 0; shrink < 6; shrink++) {
      var low = 10;
      var high = 95;
      Uint8List? best;
      while (low <= high) {
        final mid = (low + high) ~/ 2;
        final bytes = encode(current, targetExt, quality: mid);
        if (smallest == null || bytes.length < smallest.length) {
          smallest = bytes;
        }
        if (bytes.length <= targetBytes) {
          best = bytes;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }
      if (best != null) return best;
      current = img.copyResize(
        current,
        width: (current.width * 0.8).round(),
        interpolation: img.Interpolation.average,
      );
    }
    return smallest!;
  }
}

/// Page layout for PDFs built from images. Plain values so it can cross isolates.
class PdfLayout {
  final PdfPageSize pageSize;
  final PdfOrientation orientation;
  final PdfMargin margin;

  const PdfLayout({
    this.pageSize = PdfPageSize.fit,
    this.orientation = PdfOrientation.auto,
    this.margin = PdfMargin.none,
  });

  factory PdfLayout.fromOptions(ConversionOptions o) => PdfLayout(
    pageSize: o.pdfPageSize,
    orientation: o.pdfOrientation,
    margin: o.pdfMargin,
  );
}

class JpegPage {
  final Uint8List bytes;
  final int width;
  final int height;

  const JpegPage(this.bytes, this.width, this.height);
}
