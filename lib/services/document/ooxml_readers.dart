import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'doc_model.dart';
import 'xml_scanner.dart';

class _Package {
  final Archive archive;

  _Package(Uint8List bytes) : archive = _decode(bytes);

  static Archive _decode(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw const FormatException(
        'The file is damaged or is not an Office Open XML document',
      );
    }
  }

  String? text(String path) {
    final file = archive.findFile(path);
    return file == null
        ? null
        : utf8.decode(file.content, allowMalformed: true);
  }

  Uint8List? bytes(String path) => archive.findFile(path)?.content;

  Map<String, String> relationships(String partPath) {
    final slash = partPath.lastIndexOf('/');
    final relsPath =
        '${partPath.substring(0, slash + 1)}_rels/${partPath.substring(slash + 1)}.rels';
    final xml = text(relsPath);
    return xml == null
        ? const {}
        : XmlScanner.parseRelationships(xml, partPath);
  }
}

bool _isOn(XmlToken t, String valAttr) {
  final v = t.attributes[valAttr];
  return v == null || !(v == '0' || v == 'false' || v == 'off' || v == 'none');
}

/// Collects table rows and cells for both Word and DrawingML tables.
class _TableBuilder {
  final rows = <List<String>>[];
  List<String>? _row;
  StringBuffer? _cell;

  void startRow() => _row = [];
  void startCell() => _cell = StringBuffer();
  bool get inCell => _cell != null;

  void addCellParagraph(String text) {
    final cell = _cell;
    if (cell == null) return;
    if (cell.isNotEmpty) cell.write('\n');
    cell.write(text);
  }

  void endCell() {
    _row?.add(_cell?.toString() ?? '');
    _cell = null;
  }

  void endRow() {
    final row = _row;
    if (row != null && row.isNotEmpty) rows.add(row);
    _row = null;
  }
}

class DocxReader {
  static DocModel read(Uint8List bytes, {required String title}) {
    final pkg = _Package(bytes);
    final docXml = pkg.text('word/document.xml');
    if (docXml == null) {
      throw const FormatException(
        'This is not a Word document (word/document.xml is missing)',
      );
    }
    final rels = pkg.relationships('word/document.xml');
    final headingLevels = _headingLevels(pkg.text('word/styles.xml'));

    final blocks = <DocBlock>[];
    var runs = <DocRun>[];
    final runText = StringBuffer();
    var bold = false;
    var italic = false;
    var inRun = false;
    var inText = false;
    var skipDepth = 0; // inside deleted text or field instructions
    String? styleId;
    var isList = false;
    var listLevel = 0;
    var pageBreakAfter = false;
    final pendingImages = <Uint8List>[];
    var tableDepth = 0;
    _TableBuilder? table;

    void flushRun() {
      if (runText.isNotEmpty) {
        runs.add(DocRun(runText.toString(), bold: bold, italic: italic));
        runText.clear();
      }
    }

    void endParagraph() {
      flushRun();
      final text = runs.map((r) => r.text).join();
      if (tableDepth > 0) {
        table?.addCellParagraph(text);
      } else {
        final level = styleId == null ? null : headingLevels[styleId];
        if (level != null && text.trim().isNotEmpty) {
          blocks.add(DocHeading(level, text.trim()));
        } else if (text.trim().isNotEmpty) {
          blocks.add(
            DocParagraph(runs, isListItem: isList, listLevel: listLevel),
          );
        }
        for (final image in pendingImages) {
          blocks.add(DocImage(image));
        }
        if (pageBreakAfter) blocks.add(const DocPageBreak());
      }
      pendingImages.clear();
      runs = <DocRun>[];
      styleId = null;
      isList = false;
      listLevel = 0;
      pageBreakAfter = false;
    }

    for (final t in XmlScanner.scan(docXml)) {
      if (t.type == XmlTokenType.text) {
        if (inText && skipDepth == 0) runText.write(t.text);
        continue;
      }
      switch (t.name) {
        case 'w:del':
        case 'w:instrText':
          if (t.type == XmlTokenType.open) skipDepth++;
          if (t.type == XmlTokenType.close) skipDepth--;
        case 'w:p':
          if (t.type == XmlTokenType.open) {
            runs = <DocRun>[];
          } else if (t.isEnd) {
            endParagraph();
          }
        case 'w:pStyle':
          if (t.isStart) styleId = t.attributes['w:val'];
        case 'w:numPr':
          if (t.isStart) isList = true;
        case 'w:ilvl':
          if (t.isStart) {
            listLevel = int.tryParse(t.attributes['w:val'] ?? '') ?? 0;
          }
        case 'w:pageBreakBefore':
          if (t.isStart &&
              _isOn(t, 'w:val') &&
              tableDepth == 0 &&
              blocks.isNotEmpty &&
              blocks.last is! DocPageBreak) {
            blocks.add(const DocPageBreak());
          }
        case 'w:r':
          if (t.type == XmlTokenType.open) {
            inRun = true;
            bold = false;
            italic = false;
          } else if (t.isEnd) {
            flushRun();
            inRun = false;
          }
        case 'w:b':
          if (t.isStart && inRun) bold = _isOn(t, 'w:val');
        case 'w:i':
          if (t.isStart && inRun) italic = _isOn(t, 'w:val');
        case 'w:t':
          inText = t.type == XmlTokenType.open;
        case 'w:tab':
          if (t.isStart && inRun) runText.write('\t');
        case 'w:br':
        case 'w:cr':
          if (t.isStart && inRun) {
            if (t.attributes['w:type'] == 'page') {
              pageBreakAfter = true;
            } else {
              runText.write('\n');
            }
          }
        case 'a:blip':
        case 'v:imagedata':
          if (t.isStart) {
            final id = t.attributes['r:embed'] ?? t.attributes['r:id'];
            final path = id == null ? null : rels[id];
            final data = path == null ? null : pkg.bytes(path);
            if (data != null) pendingImages.add(data);
          }
        case 'w:tbl':
          if (t.type == XmlTokenType.open) {
            tableDepth++;
            if (tableDepth == 1) table = _TableBuilder();
          } else if (t.type == XmlTokenType.close) {
            if (tableDepth == 1 && table != null) {
              if (table.rows.isNotEmpty) blocks.add(DocTable(table.rows));
              for (final image in pendingImages) {
                blocks.add(DocImage(image));
              }
              pendingImages.clear();
              table = null;
            }
            tableDepth--;
          }
        case 'w:tr':
          if (tableDepth == 1 && t.type == XmlTokenType.open) table?.startRow();
          if (tableDepth == 1 && t.type == XmlTokenType.close) table?.endRow();
        case 'w:tc':
          if (tableDepth == 1 && t.type == XmlTokenType.open) {
            table?.startCell();
          }
          if (tableDepth == 1 && t.type == XmlTokenType.close) table?.endCell();
      }
    }

    return DocModel(title: title, blocks: blocks);
  }

  /// Maps style ids to heading levels using the style names, so localized
  /// documents whose style ids are not "Heading1" are still recognised.
  static Map<String, int> _headingLevels(String? stylesXml) {
    final levels = <String, int>{'Title': 1, 'Subtitle': 2};
    for (var i = 1; i <= 9; i++) {
      levels['Heading$i'] = i.clamp(1, 3);
    }
    if (stylesXml == null) return levels;
    String? currentId;
    for (final t in XmlScanner.scan(stylesXml)) {
      if (t.isStart && t.name == 'w:style') {
        currentId = t.attributes['w:styleId'];
      } else if (t.isStart && t.name == 'w:name' && currentId != null) {
        final name = (t.attributes['w:val'] ?? '').toLowerCase();
        final match = RegExp(r'^heading\s*(\d)').firstMatch(name);
        if (match != null) {
          levels[currentId] = int.parse(match.group(1)!).clamp(1, 3);
        } else if (name == 'title') {
          levels[currentId] = 1;
        } else if (name == 'subtitle') {
          levels[currentId] = 2;
        }
      }
    }
    return levels;
  }
}

class PptxReader {
  static DocModel read(Uint8List bytes, {required String title}) {
    final pkg = _Package(bytes);
    const presentationPath = 'ppt/presentation.xml';
    final presentation = pkg.text(presentationPath);
    if (presentation == null) {
      throw const FormatException(
        'This is not a PowerPoint presentation (ppt/presentation.xml is missing)',
      );
    }
    final presentationRels = pkg.relationships(presentationPath);
    final slidePaths = <String>[];
    for (final t in XmlScanner.scan(presentation)) {
      if (t.isStart && t.name == 'p:sldId') {
        final path = presentationRels[t.attributes['r:id']];
        if (path != null) slidePaths.add(path);
      }
    }

    final blocks = <DocBlock>[];
    for (var i = 0; i < slidePaths.length; i++) {
      final xml = pkg.text(slidePaths[i]);
      if (xml == null) continue;
      if (i > 0) blocks.add(const DocPageBreak());
      blocks.addAll(_readSlide(pkg, slidePaths[i], xml, i + 1));
    }
    return DocModel(title: title, blocks: blocks, landscape: true);
  }

  static List<DocBlock> _readSlide(
    _Package pkg,
    String path,
    String xml,
    int number,
  ) {
    final rels = pkg.relationships(path);
    final body = <DocBlock>[];
    String? slideTitle;
    var inTitleShape = false;
    var inShape = false;
    var shapeIsBody = false;
    var runs = <DocRun>[];
    final runText = StringBuffer();
    var bold = false;
    var italic = false;
    var inText = false;
    var level = 0;
    _TableBuilder? table;

    void flushRun() {
      if (runText.isNotEmpty) {
        runs.add(DocRun(runText.toString(), bold: bold, italic: italic));
        runText.clear();
      }
    }

    for (final t in XmlScanner.scan(xml)) {
      if (t.type == XmlTokenType.text) {
        if (inText) runText.write(t.text);
        continue;
      }
      switch (t.name) {
        case 'p:sp':
          inShape = t.type == XmlTokenType.open;
          if (!inShape) {
            inTitleShape = false;
            shapeIsBody = false;
          }
        case 'p:ph':
          if (t.isStart && inShape) {
            final type = t.attributes['type'];
            inTitleShape = type == 'title' || type == 'ctrTitle';
            shapeIsBody = type == null || type == 'body' || type == 'obj';
          }
        case 'a:p':
          if (t.type == XmlTokenType.open) {
            runs = <DocRun>[];
            level = 0;
          } else if (t.isEnd) {
            flushRun();
            final text = runs.map((r) => r.text).join().trim();
            if (text.isNotEmpty) {
              if (table != null && table.inCell) {
                table.addCellParagraph(text);
              } else if (inTitleShape) {
                slideTitle = slideTitle == null ? text : '$slideTitle $text';
              } else {
                body.add(
                  DocParagraph(runs, isListItem: shapeIsBody, listLevel: level),
                );
              }
            }
            runs = <DocRun>[];
          }
        case 'a:pPr':
          if (t.isStart) level = int.tryParse(t.attributes['lvl'] ?? '') ?? 0;
        case 'a:r':
          if (t.type == XmlTokenType.open) {
            bold = false;
            italic = false;
          } else if (t.isEnd) {
            flushRun();
          }
        case 'a:rPr':
          if (t.isStart) {
            bold = t.attributes['b'] == '1' || t.attributes['b'] == 'true';
            italic = t.attributes['i'] == '1' || t.attributes['i'] == 'true';
          }
        case 'a:t':
          inText = t.type == XmlTokenType.open;
        case 'a:br':
          if (t.isStart) runText.write('\n');
        case 'a:blip':
          if (t.isStart) {
            final target = rels[t.attributes['r:embed']];
            final data = target == null ? null : pkg.bytes(target);
            if (data != null) body.add(DocImage(data));
          }
        case 'a:tbl':
          if (t.type == XmlTokenType.open) {
            table = _TableBuilder();
          } else if (t.type == XmlTokenType.close && table != null) {
            if (table.rows.isNotEmpty) body.add(DocTable(table.rows));
            table = null;
          }
        case 'a:tr':
          if (t.type == XmlTokenType.open) table?.startRow();
          if (t.type == XmlTokenType.close) table?.endRow();
        case 'a:tc':
          if (t.type == XmlTokenType.open) table?.startCell();
          if (t.type == XmlTokenType.close) table?.endCell();
      }
    }

    return [DocHeading(1, slideTitle ?? 'Slide $number'), ...body];
  }
}
