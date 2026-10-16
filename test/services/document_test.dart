import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_converter/services/document/doc_model.dart';
import 'package:universal_converter/services/document/doc_writers.dart';
import 'package:universal_converter/services/document/ooxml_readers.dart';
import 'package:universal_converter/services/document/pdf_merger.dart';
import 'package:universal_converter/services/document/pdf_text_reader.dart';
import 'package:universal_converter/services/document/text_reader.dart';
import 'package:universal_converter/services/document/xml_scanner.dart';
import 'package:universal_converter/services/document_converter_service.dart';

/// Builds a DOCX the way Word does: custom style ids resolved through styles.xml,
/// runs split mid-word, tracked deletions, tables, page breaks and an embedded image.
Uint8List _wordStyleDocx() {
  const w =
      'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
  final doc =
      '<?xml version="1.0"?><w:document $w><w:body>'
      '<w:p><w:pPr><w:pStyle w:val="berschrift1"/></w:pPr><w:r><w:t>Projekt &amp; Plan</w:t></w:r></w:p>'
      '<w:p><w:r><w:t xml:space="preserve">Hello </w:t></w:r><w:r><w:rPr><w:b/></w:rPr><w:t>bold</w:t></w:r>'
      '<w:del><w:r><w:delText>gone</w:delText></w:r></w:del><w:r><w:rPr><w:b w:val="0"/></w:rPr><w:t xml:space="preserve"> world café</w:t></w:r></w:p>'
      '<w:p><w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>item one</w:t></w:r></w:p>'
      '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>A1</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>B1</w:t></w:r></w:p></w:tc></w:tr>'
      '<w:tr><w:tc><w:p><w:r><w:t>A2</w:t></w:r></w:p><w:p><w:r><w:t>more</w:t></w:r></w:p></w:tc><w:tc><w:p/></w:tc></w:tr></w:tbl>'
      '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'
      '<w:p><w:r><w:drawing><a:graphic><a:graphicData><a:blip r:embed="rId9"/></a:graphicData></a:graphic></w:drawing></w:r></w:p>'
      '<w:p><w:r><w:t>Last</w:t></w:r></w:p>'
      '</w:body></w:document>';
  final styles =
      '<?xml version="1.0"?><w:styles $w><w:style w:type="paragraph" w:styleId="berschrift1">'
      '<w:name w:val="heading 1"/></w:style></w:styles>';
  final rels =
      '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId9" Type="image" Target="media/image1.png"/></Relationships>';
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
  );
  final archive = Archive()
    ..addFile(ArchiveFile.string('word/document.xml', doc))
    ..addFile(ArchiveFile.string('word/styles.xml', styles))
    ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', rels))
    ..addFile(ArchiveFile.bytes('word/media/image1.png', png));
  return ZipEncoder().encodeBytes(archive);
}

Uint8List _samplePptx() {
  const ns =
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"';
  String slide(String title, String body) =>
      '<?xml version="1.0"?><p:sld $ns><p:cSld><p:spTree>'
      '<p:sp><p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr><p:txBody><a:p><a:r><a:t>$title</a:t></a:r></a:p></p:txBody></p:sp>'
      '<p:sp><p:nvSpPr><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr><p:txBody><a:p><a:pPr lvl="1"/><a:r><a:rPr b="1"/><a:t>$body</a:t></a:r></a:p></p:txBody></p:sp>'
      '</p:spTree></p:cSld></p:sld>';
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        'ppt/presentation.xml',
        '<?xml version="1.0"?><p:presentation $ns><p:sldIdLst><p:sldId id="257" r:id="rId3"/><p:sldId id="256" r:id="rId2"/></p:sldIdLst></p:presentation>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'ppt/_rels/presentation.xml.rels',
        '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId2" Type="slide" Target="slides/slide1.xml"/><Relationship Id="rId3" Type="slide" Target="/ppt/slides/slide2.xml"/></Relationships>',
      ),
    )
    ..addFile(
      ArchiveFile.string('ppt/slides/slide1.xml', slide('Second', 'Body two')),
    )
    ..addFile(
      ArchiveFile.string('ppt/slides/slide2.xml', slide('First', 'Body one')),
    );
  return ZipEncoder().encodeBytes(archive);
}

Future<Uint8List> _textPdf() async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Text('Quarterly Report', style: const pw.TextStyle(fontSize: 26)),
        pw.Text(
          'This first paragraph wraps across several lines because it is deliberately long enough to need wrapping on an A4 page with default margins.',
        ),
        pw.SizedBox(height: 24),
        pw.Text('Second paragraph after a gap.'),
      ],
    ),
  );
  doc.addPage(pw.Page(build: (_) => pw.Text('Page two text')));
  return doc.save();
}

void main() {
  group('XmlScanner', () {
    test('decodes entities and resolves relationship paths', () {
      expect(
        XmlScanner.decodeEntities('a &amp; b &lt;c&gt; &#233; &#x41;'),
        'a & b <c> é A',
      );
      expect(
        XmlScanner.resolvePath('ppt/slides', '../media/img.png'),
        'ppt/media/img.png',
      );
      expect(
        XmlScanner.resolvePath('word', '/word/media/x.png'),
        'word/media/x.png',
      );
      expect(XmlScanner.escape('a<b>&"\u0001'), 'a&lt;b&gt;&amp;&quot;');
    });
  });

  group('DocxReader', () {
    test(
      'keeps paragraphs, headings by style name, runs, lists, tables, breaks and images',
      () {
        final model = DocxReader.read(_wordStyleDocx(), title: 't');
        final blocks = model.blocks;
        expect(
          blocks[0],
          isA<DocHeading>().having((h) => h.text, 'text', 'Projekt & Plan'),
        );
        final para = blocks[1] as DocParagraph;
        expect(para.text, 'Hello bold world café');
        expect(para.runs[1].bold, isTrue);
        expect(para.runs[2].bold, isFalse);
        expect(
          blocks[2],
          isA<DocParagraph>()
              .having((p) => p.isListItem, 'list', true)
              .having((p) => p.listLevel, 'level', 1),
        );
        expect((blocks[3] as DocTable).rows, [
          ['A1', 'B1'],
          ['A2\nmore', ''],
        ]);
        expect(blocks[4], isA<DocPageBreak>());
        expect(blocks[5], isA<DocImage>());
        expect((blocks[6] as DocParagraph).text, 'Last');
      },
    );

    test('rejects files that are not Word documents', () {
      expect(
        () => DocxReader.read(
          Uint8List.fromList(utf8.encode('plain text')),
          title: 't',
        ),
        throwsFormatException,
      );
    });
  });

  group('PptxReader', () {
    test('follows presentation order and reads titles and bullets', () {
      final model = PptxReader.read(_samplePptx(), title: 'deck');
      expect(model.landscape, isTrue);
      final headings = model.blocks
          .whereType<DocHeading>()
          .map((h) => h.text)
          .toList();
      expect(headings, ['First', 'Second']);
      final first = model.blocks[1] as DocParagraph;
      expect(first.text, 'Body one');
      expect(first.isListItem, isTrue);
      expect(first.runs.first.bold, isTrue);
      expect(model.blocks.whereType<DocPageBreak>().length, 1);
    });
  });

  group('TextReader', () {
    test('markdown headings, lists, emphasis and tables', () {
      final md =
          '# Title\n\nSome **bold** and *italic* with `code` and [link](http://x).\n\n- one\n  - nested\n\n| a | b |\n|---|---|\n| 1 | 2 |\n';
      final model = TextReader.readMarkdown(
        Uint8List.fromList(utf8.encode(md)),
        title: 'm',
      );
      expect(
        model.blocks[0],
        isA<DocHeading>().having((h) => h.text, 'text', 'Title'),
      );
      final para = model.blocks[1] as DocParagraph;
      expect(para.text, 'Some bold and italic with code and link.');
      expect(para.runs.firstWhere((r) => r.text == 'bold').bold, isTrue);
      expect((model.blocks[3] as DocParagraph).listLevel, 1);
      expect((model.blocks[4] as DocTable).rows, [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('decodes UTF-16 text with a byte order mark', () {
      final bytes = Uint8List.fromList([0xFF, 0xFE, 0x48, 0x00, 0xE9, 0x00]);
      expect(TextReader.decode(bytes), 'Hé');
    });
  });

  group('PdfTextReader', () {
    test('rebuilds headings and paragraphs from a text PDF', () async {
      final model = PdfTextReader.read(await _textPdf(), title: 'p');
      final heading = model.blocks.first as DocHeading;
      expect(heading.text, 'Quarterly Report');
      final paragraphs = model.blocks
          .whereType<DocParagraph>()
          .map((p) => p.text)
          .toList();
      expect(
        paragraphs[0],
        startsWith('This first paragraph wraps across several lines'),
      );
      expect(paragraphs[0], endsWith('default margins.'));
      expect(paragraphs[1], 'Second paragraph after a gap.');
      expect(model.blocks, contains(isA<DocPageBreak>()));
      expect(paragraphs.last, 'Page two text');
    });

    test('reports scanned PDFs instead of writing an empty document', () async {
      final doc = pw.Document()..addPage(pw.Page(build: (_) => pw.Container()));
      final bytes = await doc.save();
      expect(
        () => PdfTextReader.read(bytes, title: 'p'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Writers', () {
    final model = DocModel(
      title: 'T',
      blocks: [
        const DocHeading(1, 'Heading'),
        const DocParagraph([
          DocRun('Plain '),
          DocRun('bold', bold: true),
          DocRun(' and café 中文 <tag> & more'),
        ]),
        const DocParagraph([DocRun('bullet')], isListItem: true),
        const DocTable([
          ['a', 'b'],
          ['c'],
        ]),
        const DocPageBreak(),
        DocParagraph.plain(
          List.filled(400, 'Long text to force many pages.').join(' '),
        ),
      ],
    );

    test(
      'PDF writer handles long documents and non-Latin text without a font',
      () async {
        final bytes = await PdfDocWriter.write(
          DocModel(
            title: 'T',
            blocks: [
              ...model.blocks,
              for (var i = 0; i < 400; i++) DocParagraph.plain('Paragraph $i'),
            ],
          ),
        );
        expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
        final readBack = PdfTextReader.read(bytes, title: 'r');
        expect(readBack.toPlainText(), contains('Paragraph 399'));
      },
    );

    test('PDF writer embeds a TrueType font when provided', () async {
      final font = File(
        'assets/fonts/SpaceGrotesk-Regular.ttf',
      ).readAsBytesSync();
      final bytes = await PdfDocWriter.write(
        model,
        fonts: DocFonts(regular: font),
      );
      expect(
        PdfTextReader.read(bytes, title: 'r').toPlainText(),
        contains('café'),
      );
    });

    test('DOCX writer output reads back through the DOCX reader', () {
      final bytes = DocxWriter.write(model);
      final readBack = DocxReader.read(bytes, title: 'r');
      expect(
        readBack.blocks.first,
        isA<DocHeading>().having((h) => h.text, 'text', 'Heading'),
      );
      expect(readBack.toPlainText(), contains('café 中文 <tag> & more'));
      expect(readBack.blocks.whereType<DocTable>().single.rows.first, [
        'a',
        'b',
      ]);
      // Zip entry sizes must be byte counts, not character counts, for non-ASCII text.
      final entry = ZipDecoder()
          .decodeBytes(bytes)
          .findFile('word/document.xml')!;
      expect(entry.size, entry.content.length);
    });

    test('PPTX writer produces one slide per picture', () {
      final jpeg = base64Decode(
        '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
      );
      final bytes = PptxWriter.writePictureSlides([
        PictureSlide(jpeg, 800, 600),
        PictureSlide(jpeg, 600, 800),
      ]);
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile('ppt/slides/slide2.xml'), isNotNull);
      expect(archive.findFile('ppt/media/image2.jpg'), isNotNull);
      final presentation = utf8.decode(
        archive.findFile('ppt/presentation.xml')!.content,
      );
      expect(presentation, contains('cy="9144000"'));
    });

    test('plain text keeps ASCII and marks UTF-8 with a BOM', () {
      expect(DocumentConverterService.encodeText('abc'), utf8.encode('abc'));
      expect(DocumentConverterService.encodeText('é').sublist(0, 3), [
        0xEF,
        0xBB,
        0xBF,
      ]);
    });
  });

  group('PdfMerger', () {
    test('keeps every page in order', () async {
      final a = await _textPdf();
      final b =
          await (pw.Document()
                ..addPage(pw.Page(build: (_) => pw.Text('Third page'))))
              .save();
      final merged = PdfMerger.merge([a, b]);
      final text = PdfTextReader.read(merged, title: 'm').toPlainText();
      expect(
        text.indexOf('Quarterly Report'),
        lessThan(text.indexOf('Page two text')),
      );
      expect(
        text.indexOf('Page two text'),
        lessThan(text.indexOf('Third page')),
      );
    });
  });
}
