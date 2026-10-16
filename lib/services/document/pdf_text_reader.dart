import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'doc_model.dart';

/// Rebuilds paragraphs and headings from a PDF's text layer. PDFs only store
/// positioned lines, so paragraph breaks are inferred from vertical gaps and
/// headings from font sizes larger than the body text.
class PdfTextReader {
  static final _bullet = RegExp(r'^\s*([•●▪–\-*]|\d{1,3}[.)])\s+');

  static DocModel read(Uint8List bytes, {required String title}) {
    final sf.PdfDocument document;
    try {
      document = sf.PdfDocument(inputBytes: bytes);
    } on Object {
      throw const FormatException('The PDF is damaged or password protected');
    }
    try {
      final extractor = sf.PdfTextExtractor(document);
      final blocks = <DocBlock>[];
      for (var page = 0; page < document.pages.count; page++) {
        final lines = extractor
            .extractTextLines(startPageIndex: page, endPageIndex: page)
            .where((l) => l.text.trim().isNotEmpty)
            .toList();
        if (page > 0 && lines.isNotEmpty) blocks.add(const DocPageBreak());
        blocks.addAll(_linesToBlocks(lines));
      }
      final model = DocModel(title: title, blocks: blocks);
      if (!model.hasText) {
        throw const FormatException(
          'This PDF has no text layer (it is a scan or a picture). Use PDF to JPG or PNG instead.',
        );
      }
      return model;
    } finally {
      document.dispose();
    }
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  static List<DocBlock> _linesToBlocks(List<sf.TextLine> lines) {
    if (lines.isEmpty) return const [];
    final bodySize = _median(lines.map((l) => l.fontSize).toList());
    final blocks = <DocBlock>[];
    final buffer = StringBuffer();
    var bold = false;
    var listItem = false;
    sf.TextLine? previous;

    void flush() {
      final text = buffer.toString().trim();
      buffer.clear();
      if (text.isEmpty) return;
      blocks.add(
        DocParagraph([DocRun(text, bold: bold)], isListItem: listItem),
      );
    }

    for (final line in lines) {
      final text = line.text.trim();
      final size = line.fontSize;
      final isHeading =
          bodySize > 0 && size >= bodySize * 1.25 && text.length < 160;
      if (isHeading) {
        flush();
        final level = size >= bodySize * 1.7
            ? 1
            : (size >= bodySize * 1.4 ? 2 : 3);
        // Consecutive heading lines of the same size are one wrapped heading.
        final last = blocks.isNotEmpty ? blocks.last : null;
        if (last is DocHeading &&
            last.level == level &&
            previous != null &&
            (previous.fontSize - size).abs() < 0.5) {
          blocks[blocks.length - 1] = DocHeading(level, '${last.text} $text');
        } else {
          blocks.add(DocHeading(level, text));
        }
        previous = line;
        continue;
      }

      final bulletMatch = _bullet.firstMatch(text);
      var startsNew = previous == null || bulletMatch != null;
      if (!startsNew) {
        final prev = previous;
        final lineHeight = prev.bounds.height > 0 ? prev.bounds.height : size;
        final gap = line.bounds.top - prev.bounds.bottom;
        final sizeChanged = (prev.fontSize - size).abs() > 1;
        startsNew = gap > lineHeight * 0.6 || sizeChanged || gap < -lineHeight;
      }
      if (startsNew) {
        flush();
        bold = line.fontStyle.contains(sf.PdfFontStyle.bold);
        listItem = bulletMatch != null;
        buffer.write(
          bulletMatch != null ? text.substring(bulletMatch.end) : text,
        );
      } else {
        final current = buffer.toString();
        // Join words split by a line-end hyphen.
        if (current.endsWith('-') &&
            current.length > 1 &&
            RegExp(
              r'[a-z]$',
            ).hasMatch(current.substring(0, current.length - 1))) {
          buffer
            ..clear()
            ..write(current.substring(0, current.length - 1))
            ..write(text);
        } else {
          buffer
            ..write(' ')
            ..write(text);
        }
      }
      previous = line;
    }
    flush();
    return blocks;
  }
}
