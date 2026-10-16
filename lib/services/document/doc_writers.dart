import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'doc_model.dart';
import 'xml_scanner.dart';

/// TrueType font bytes for PDF output. On Android these come from /system/fonts so
/// non-Latin text renders; when absent the PDF falls back to Helvetica (Latin-1 only).
class DocFonts {
  final Uint8List? regular;
  final Uint8List? bold;
  final Uint8List? italic;
  final Uint8List? boldItalic;

  const DocFonts({this.regular, this.bold, this.italic, this.boldItalic});
}

class PdfDocWriter {
  static pw.Font? _ttf(Uint8List? bytes) {
    if (bytes == null) return null;
    try {
      return pw.Font.ttf(ByteData.sublistView(bytes));
    } on Object {
      return null;
    }
  }

  /// Helvetica only covers Latin-1; replace anything else so text never disappears silently.
  static String _latin1(String s) =>
      s.replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E\xA0-\xFF]'), '?');

  static Future<Uint8List> write(
    DocModel model, {
    DocFonts fonts = const DocFonts(),
  }) async {
    final regular = _ttf(fonts.regular);
    final bold = _ttf(fonts.bold) ?? regular;
    final italic = _ttf(fonts.italic) ?? regular;
    final boldItalic = _ttf(fonts.boldItalic) ?? bold;
    final hasUnicodeFont = regular != null;
    String clean(String s) => hasUnicodeFont ? s : _latin1(s);

    final theme = hasUnicodeFont
        ? pw.ThemeData.withFont(
            base: regular,
            bold: bold,
            italic: italic,
            boldItalic: boldItalic,
          )
        : pw.ThemeData.base();
    final format = model.landscape
        ? PdfPageFormat.a4.landscape
        : PdfPageFormat.a4;
    final contentWidth = format.width - 2 * 48;
    final contentHeight = format.height - 2 * 48 - 24;

    final widgets = <pw.Widget>[];
    for (final block in model.blocks) {
      switch (block) {
        case DocHeading(:final level, :final text):
          final size = switch (level) {
            1 => 20.0,
            2 => 16.0,
            _ => 13.0,
          };
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8, bottom: 8),
              child: pw.Text(
                clean(text),
                style: pw.TextStyle(
                  fontSize: size,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
        case DocParagraph():
          final spans = block.runs
              .map(
                (r) => pw.TextSpan(
                  text: clean(r.text),
                  style: pw.TextStyle(
                    fontWeight: r.bold
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    fontStyle: r.italic
                        ? pw.FontStyle.italic
                        : pw.FontStyle.normal,
                  ),
                ),
              )
              .toList();
          // A bare RichText can split across pages; wrapping it (Padding, Row) would not.
          final prefix = block.isListItem
              ? [
                  pw.TextSpan(
                    text:
                        '${'    ' * block.listLevel}${hasUnicodeFont ? '\u2022' : '-'}  ',
                  ),
                ]
              : const <pw.TextSpan>[];
          widgets.add(
            pw.RichText(
              overflow: pw.TextOverflow.span,
              text: pw.TextSpan(
                children: [...prefix, ...spans],
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: block.isListItem ? 4 : 8));
        case DocTable(:final rows):
          final columns = rows.fold<int>(
            0,
            (m, r) => r.length > m ? r.length : m,
          );
          final padded = rows
              .map(
                (r) => [
                  ...r.map(clean),
                  for (var i = r.length; i < columns; i++) '',
                ],
              )
              .toList();
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.TableHelper.fromTextArray(
                data: padded,
                headerCount: 0,
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.topLeft,
                border: pw.TableBorder.all(width: 0.5),
              ),
            ),
          );
        case DocImage(:final bytes):
          final image = _pdfImage(bytes);
          if (image != null) {
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.ConstrainedBox(
                  constraints: pw.BoxConstraints(
                    maxWidth: contentWidth,
                    maxHeight: contentHeight * 0.9,
                  ),
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
            );
          }
        case DocPageBreak():
          widgets.add(pw.NewPage());
      }
    }
    if (widgets.isEmpty) widgets.add(pw.Text(''));

    final doc = pw.Document(title: model.title, compress: true);
    doc.addPage(
      pw.MultiPage(
        pageFormat: format.copyWith(
          marginLeft: 48,
          marginRight: 48,
          marginTop: 48,
          marginBottom: 48,
        ),
        theme: theme,
        maxPages: 100000,
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (_) => widgets,
      ),
    );
    return doc.save();
  }

  /// JPEG and PNG embed directly; other raster formats are converted. Vector
  /// formats Office uses (EMF, WMF, SVG) are skipped because they cannot be drawn.
  static pw.ImageProvider? _pdfImage(Uint8List bytes) {
    final isJpeg = bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    final isPng = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50;
    if (isJpeg || isPng) return pw.MemoryImage(bytes);
    final decoded = img.decodeImage(bytes);
    return decoded == null ? null : pw.MemoryImage(img.encodePng(decoded));
  }
}

class _Zip {
  final archive = Archive();

  void text(String path, String content) =>
      archive.addFile(ArchiveFile.string(path, content));
  void bytes(String path, Uint8List content) =>
      archive.addFile(ArchiveFile.bytes(path, content));
  Uint8List encode() => ZipEncoder().encodeBytes(archive);
}

const _xmlHeader = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

class DocxWriter {
  static const _w =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

  static String _run(DocRun run) {
    final props = StringBuffer();
    if (run.bold) props.write('<w:b/>');
    if (run.italic) props.write('<w:i/>');
    final rPr = props.isEmpty ? '' : '<w:rPr>$props</w:rPr>';
    final out = StringBuffer();
    final lines = run.text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) out.write('<w:r>$rPr<w:br/></w:r>');
      final parts = lines[i].split('\t');
      for (var j = 0; j < parts.length; j++) {
        if (j > 0) out.write('<w:r>$rPr<w:tab/></w:r>');
        if (parts[j].isNotEmpty) {
          out.write(
            '<w:r>$rPr<w:t xml:space="preserve">${XmlScanner.escape(parts[j])}</w:t></w:r>',
          );
        }
      }
    }
    return out.toString();
  }

  static String _paragraph(
    List<DocRun> runs, {
    String? style,
    int? indentTwips,
  }) {
    final pPr = StringBuffer();
    if (style != null) pPr.write('<w:pStyle w:val="$style"/>');
    if (indentTwips != null) {
      pPr.write('<w:ind w:left="$indentTwips" w:hanging="240"/>');
    }
    return '<w:p>${pPr.isEmpty ? '' : '<w:pPr>$pPr</w:pPr>'}${runs.map(_run).join()}</w:p>';
  }

  static Uint8List write(DocModel model) {
    final body = StringBuffer();
    for (final block in model.blocks) {
      switch (block) {
        case DocHeading(:final level, :final text):
          body.write(_paragraph([DocRun(text)], style: 'Heading$level'));
        case DocParagraph():
          if (block.isListItem) {
            body.write(
              _paragraph([
                const DocRun('•\t'),
                ...block.runs,
              ], indentTwips: 480 + block.listLevel * 360),
            );
          } else {
            body.write(_paragraph(block.runs));
          }
        case DocTable(:final rows):
          body.write(
            '<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/>'
            '<w:tblBorders>${['top', 'left', 'bottom', 'right', 'insideH', 'insideV'].map((e) => '<w:$e w:val="single" w:sz="4" w:space="0" w:color="000000"/>').join()}</w:tblBorders>'
            '</w:tblPr>',
          );
          for (final row in rows) {
            body.write('<w:tr>');
            for (final cell in row) {
              body.write(
                '<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>${_paragraph([DocRun(cell)])}</w:tc>',
              );
            }
            body.write('</w:tr>');
          }
          body.write('</w:tbl>');
        case DocImage():
          break;
        case DocPageBreak():
          body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }

    final zip = _Zip()
      ..text(
        '[Content_Types].xml',
        '$_xmlHeader<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
            '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
            '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
            '</Types>',
      )
      ..text(
        '_rels/.rels',
        '$_xmlHeader<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
            '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
            '</Relationships>',
      )
      ..text(
        'docProps/core.xml',
        '$_xmlHeader<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
            'xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>${XmlScanner.escape(model.title)}</dc:title></cp:coreProperties>',
      )
      ..text(
        'word/_rels/document.xml.rels',
        '$_xmlHeader<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
            '</Relationships>',
      )
      ..text('word/styles.xml', _styles())
      ..text(
        'word/document.xml',
        '$_xmlHeader<w:document xmlns:w="$_w"><w:body>$body'
            '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>'
            '</w:body></w:document>',
      );
    return zip.encode();
  }

  static String _styles() {
    String heading(int level, int halfPoints) =>
        '<w:style w:type="paragraph" w:styleId="Heading$level">'
        '<w:name w:val="heading $level"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>'
        '<w:pPr><w:keepNext/><w:spacing w:before="240" w:after="120"/><w:outlineLvl w:val="${level - 1}"/></w:pPr>'
        '<w:rPr><w:b/><w:sz w:val="$halfPoints"/></w:rPr></w:style>';
    return '$_xmlHeader<w:styles xmlns:w="$_w">'
        '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Calibri"/>'
        '<w:sz w:val="22"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
        '${heading(1, 36)}${heading(2, 30)}${heading(3, 26)}'
        '<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/></w:style>'
        '</w:styles>';
  }
}

/// A slide holding one full-bleed picture.
class PictureSlide {
  final Uint8List jpeg;
  final int width;
  final int height;

  const PictureSlide(this.jpeg, this.width, this.height);
}

class PptxWriter {
  static const _p =
      'http://schemas.openxmlformats.org/presentationml/2006/main';
  static const _a = 'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const _r =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _relNs =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const _relType =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  static Uint8List writePictureSlides(List<PictureSlide> slides) {
    if (slides.isEmpty) throw ArgumentError('No slides to write');
    // Slide size follows the first page: 13.333 in wide, height by aspect ratio,
    // clamped to the range PowerPoint accepts.
    const slideWidth = 12192000;
    final slideHeight = (slideWidth * slides.first.height / slides.first.width)
        .round()
        .clamp(914400, 51206400);

    final zip = _Zip();
    final overrides = StringBuffer()
      ..write(
        '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
      )
      ..write(
        '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>',
      )
      ..write(
        '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>',
      )
      ..write(
        '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>',
      );
    final slideIds = StringBuffer();
    final presentationRels = StringBuffer()
      ..write(
        '<Relationship Id="rId1" Type="$_relType/slideMaster" Target="slideMasters/slideMaster1.xml"/>',
      );

    for (var i = 0; i < slides.length; i++) {
      final n = i + 1;
      final slide = slides[i];
      overrides.write(
        '<Override PartName="/ppt/slides/slide$n.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
      );
      slideIds.write('<p:sldId id="${255 + n}" r:id="rId${n + 1}"/>');
      presentationRels.write(
        '<Relationship Id="rId${n + 1}" Type="$_relType/slide" Target="slides/slide$n.xml"/>',
      );

      // Fit the picture inside the slide, centred.
      final scale = [
        slideWidth / slide.width,
        slideHeight / slide.height,
      ].reduce((a, b) => a < b ? a : b);
      final cx = (slide.width * scale).round();
      final cy = (slide.height * scale).round();
      final x = (slideWidth - cx) ~/ 2;
      final y = (slideHeight - cy) ~/ 2;

      zip.bytes('ppt/media/image$n.jpg', slide.jpeg);
      zip.text(
        'ppt/slides/_rels/slide$n.xml.rels',
        '$_xmlHeader<Relationships xmlns="$_relNs">'
            '<Relationship Id="rId1" Type="$_relType/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
            '<Relationship Id="rId2" Type="$_relType/image" Target="../media/image$n.jpg"/></Relationships>',
      );
      zip.text(
        'ppt/slides/slide$n.xml',
        '$_xmlHeader<p:sld xmlns:a="$_a" xmlns:r="$_r" xmlns:p="$_p"><p:cSld><p:spTree>'
            '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
            '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
            '<p:pic><p:nvPicPr><p:cNvPr id="2" name="Page $n"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>'
            '<p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>'
            '<p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>'
            '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>',
      );
    }
    presentationRels.write(
      '<Relationship Id="rId${slides.length + 2}" Type="$_relType/theme" Target="theme/theme1.xml"/>',
    );

    const emptyTree =
        '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree>';

    zip
      ..text(
        '[Content_Types].xml',
        '$_xmlHeader<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/><Default Extension="jpg" ContentType="image/jpeg"/>'
            '$overrides</Types>',
      )
      ..text(
        '_rels/.rels',
        '$_xmlHeader<Relationships xmlns="$_relNs">'
            '<Relationship Id="rId1" Type="$_relType/officeDocument" Target="ppt/presentation.xml"/></Relationships>',
      )
      ..text(
        'ppt/presentation.xml',
        '$_xmlHeader<p:presentation xmlns:a="$_a" xmlns:r="$_r" xmlns:p="$_p">'
            '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
            '<p:sldIdLst>$slideIds</p:sldIdLst><p:sldSz cx="$slideWidth" cy="$slideHeight"/><p:notesSz cx="6858000" cy="9144000"/>'
            '</p:presentation>',
      )
      ..text(
        'ppt/_rels/presentation.xml.rels',
        '$_xmlHeader<Relationships xmlns="$_relNs">$presentationRels</Relationships>',
      )
      ..text(
        'ppt/slideMasters/slideMaster1.xml',
        '$_xmlHeader<p:sldMaster xmlns:a="$_a" xmlns:r="$_r" xmlns:p="$_p">'
            '<p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>$emptyTree</p:cSld>'
            '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
            '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst></p:sldMaster>',
      )
      ..text(
        'ppt/slideMasters/_rels/slideMaster1.xml.rels',
        '$_xmlHeader<Relationships xmlns="$_relNs">'
            '<Relationship Id="rId1" Type="$_relType/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
            '<Relationship Id="rId2" Type="$_relType/theme" Target="../theme/theme1.xml"/></Relationships>',
      )
      ..text(
        'ppt/slideLayouts/slideLayout1.xml',
        '$_xmlHeader<p:sldLayout xmlns:a="$_a" xmlns:r="$_r" xmlns:p="$_p" type="blank" preserve="1">'
            '<p:cSld name="Blank">$emptyTree</p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>',
      )
      ..text(
        'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
        '$_xmlHeader<Relationships xmlns="$_relNs">'
            '<Relationship Id="rId1" Type="$_relType/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>',
      )
      ..text('ppt/theme/theme1.xml', _theme());
    return zip.encode();
  }

  static String _theme() {
    String color(String name, String hex) =>
        '<a:$name><a:srgbClr val="$hex"/></a:$name>';
    const solid = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>';
    const line =
        '<a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>';
    return '$_xmlHeader<a:theme xmlns:a="$_a" name="A2A"><a:themeElements>'
        '<a:clrScheme name="A2A">${color('dk1', '000000')}${color('lt1', 'FFFFFF')}${color('dk2', '1F1F1F')}${color('lt2', 'F2F2F2')}'
        '${color('accent1', '0A66E4')}${color('accent2', 'F2472A')}${color('accent3', 'F7C534')}${color('accent4', '55C24A')}'
        '${color('accent5', '8E52F5')}${color('accent6', '333333')}${color('hlink', '0A66E4')}${color('folHlink', '8E52F5')}</a:clrScheme>'
        '<a:fontScheme name="A2A"><a:majorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
        '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>'
        '<a:fmtScheme name="A2A"><a:fillStyleLst>$solid$solid$solid</a:fillStyleLst>'
        '<a:lnStyleLst>$line$line$line</a:lnStyleLst>'
        '<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>'
        '<a:bgFillStyleLst>$solid$solid$solid</a:bgFillStyleLst></a:fmtScheme>'
        '</a:themeElements></a:theme>';
  }
}
