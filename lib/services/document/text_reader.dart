import 'dart:convert';
import 'dart:typed_data';
import 'doc_model.dart';

class TextReader {
  /// Decodes UTF-8 or UTF-16 (with BOM, as written by Windows Notepad).
  static String decode(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _utf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _utf16(bytes.sublist(2), littleEndian: false);
    }
    final start =
        bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF
        ? 3
        : 0;
    return utf8.decode(bytes.sublist(start), allowMalformed: true);
  }

  static String _utf16(Uint8List bytes, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(
        littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
      );
    }
    return String.fromCharCodes(units);
  }

  /// Plain text: blank lines separate paragraphs; single line breaks are kept.
  static DocModel readText(Uint8List bytes, {required String title}) {
    final text = decode(bytes).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = <DocBlock>[];
    for (final para in text.split(RegExp(r'\n\s*\n'))) {
      if (para.trim().isEmpty) continue;
      if (para.contains('\f')) {
        for (final (i, part) in para.split('\f').indexed) {
          if (i > 0) blocks.add(const DocPageBreak());
          if (part.trim().isNotEmpty) {
            blocks.add(DocParagraph.plain(part.trimRight()));
          }
        }
      } else {
        blocks.add(DocParagraph.plain(para.trimRight()));
      }
    }
    return DocModel(title: title, blocks: blocks);
  }

  static final _heading = RegExp(r'^(#{1,6})\s+(.*?)\s*#*\s*$');
  static final _listItem = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+(.*)$');
  static final _inline = RegExp(
    r'(\*\*|__)(.+?)\1|(\*|_)(.+?)\3|`([^`]+)`|!?\[([^\]]*)\]\([^)]*\)',
  );

  /// Markdown subset: headings, lists, bold, italic, code spans, links and tables.
  static DocModel readMarkdown(Uint8List bytes, {required String title}) {
    final lines = decode(bytes).replaceAll('\r\n', '\n').split('\n');
    final blocks = <DocBlock>[];
    final paragraph = <String>[];
    final tableRows = <List<String>>[];
    var inCode = false;
    final code = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(DocParagraph(parseInline(paragraph.join(' '))));
      paragraph.clear();
    }

    void flushTable() {
      if (tableRows.isEmpty) return;
      blocks.add(DocTable(List.of(tableRows)));
      tableRows.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trimLeft().startsWith('```')) {
        if (inCode) {
          blocks.add(DocParagraph.plain(code.join('\n')));
          code.clear();
        } else {
          flushParagraph();
          flushTable();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        code.add(raw);
        continue;
      }
      if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
        flushParagraph();
        final cells = line
            .trim()
            .substring(1, line.trim().length - 1)
            .split('|')
            .map((c) => c.trim())
            .toList();
        final isDivider = cells.every(
          (c) => RegExp(r'^:?-{2,}:?$').hasMatch(c),
        );
        if (!isDivider) {
          tableRows.add(cells.map((c) => _plain(parseInline(c))).toList());
        }
        continue;
      }
      flushTable();
      if (line.trim().isEmpty) {
        flushParagraph();
        continue;
      }
      final heading = _heading.firstMatch(line);
      if (heading != null) {
        flushParagraph();
        blocks.add(
          DocHeading(
            heading.group(1)!.length.clamp(1, 3),
            _plain(parseInline(heading.group(2)!)),
          ),
        );
        continue;
      }
      final item = _listItem.firstMatch(line);
      if (item != null) {
        flushParagraph();
        blocks.add(
          DocParagraph(
            parseInline(item.group(3)!),
            isListItem: true,
            listLevel: item.group(1)!.length ~/ 2,
          ),
        );
        continue;
      }
      if (RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$').hasMatch(line)) {
        flushParagraph();
        continue;
      }
      paragraph.add(line.trim().replaceFirst(RegExp(r'^>\s?'), ''));
    }
    if (inCode && code.isNotEmpty) {
      blocks.add(DocParagraph.plain(code.join('\n')));
    }
    flushParagraph();
    flushTable();
    return DocModel(title: title, blocks: blocks);
  }

  static String _plain(List<DocRun> runs) => runs.map((r) => r.text).join();

  static List<DocRun> parseInline(String text) {
    final runs = <DocRun>[];
    var index = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > index) runs.add(DocRun(text.substring(index, m.start)));
      if (m.group(2) != null) {
        runs.add(DocRun(m.group(2)!, bold: true));
      } else if (m.group(4) != null) {
        runs.add(DocRun(m.group(4)!, italic: true));
      } else if (m.group(5) != null) {
        runs.add(DocRun(m.group(5)!));
      } else {
        runs.add(DocRun(m.group(6) ?? ''));
      }
      index = m.end;
    }
    if (index < text.length) runs.add(DocRun(text.substring(index)));
    return runs;
  }
}
