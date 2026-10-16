import 'dart:typed_data';

/// Format-neutral document representation shared by every reader and writer.
sealed class DocBlock {
  const DocBlock();
}

class DocRun {
  final String text;
  final bool bold;
  final bool italic;

  const DocRun(this.text, {this.bold = false, this.italic = false});
}

class DocHeading extends DocBlock {
  /// 1 is the largest.
  final int level;
  final String text;

  const DocHeading(this.level, this.text);
}

class DocParagraph extends DocBlock {
  final List<DocRun> runs;
  final bool isListItem;
  final int listLevel;

  const DocParagraph(this.runs, {this.isListItem = false, this.listLevel = 0});

  DocParagraph.plain(String text) : this([DocRun(text)]);

  String get text => runs.map((r) => r.text).join();
}

class DocTable extends DocBlock {
  final List<List<String>> rows;

  const DocTable(this.rows);
}

class DocImage extends DocBlock {
  final Uint8List bytes;

  const DocImage(this.bytes);
}

class DocPageBreak extends DocBlock {
  const DocPageBreak();
}

class DocModel {
  final String title;
  final List<DocBlock> blocks;

  /// Slides read from presentations are laid out on landscape pages.
  final bool landscape;

  const DocModel({
    required this.title,
    required this.blocks,
    this.landscape = false,
  });

  bool get hasText => blocks.any(
    (b) => switch (b) {
      DocHeading(:final text) => text.trim().isNotEmpty,
      DocParagraph() => b.text.trim().isNotEmpty,
      DocTable(:final rows) => rows.any(
        (r) => r.any((c) => c.trim().isNotEmpty),
      ),
      _ => false,
    },
  );

  String toPlainText() {
    final out = StringBuffer();
    for (final block in blocks) {
      switch (block) {
        case DocHeading(:final text):
          out
            ..writeln(text)
            ..writeln();
        case DocParagraph():
          final indent = '  ' * block.listLevel;
          out.writeln(block.isListItem ? '$indent- ${block.text}' : block.text);
          if (!block.isListItem) out.writeln();
        case DocTable(:final rows):
          for (final row in rows) {
            out.writeln(row.map((c) => c.replaceAll('\n', ' ')).join('\t'));
          }
          out.writeln();
        case DocImage():
          break;
        case DocPageBreak():
          out.writeln();
      }
    }
    return '${out.toString().trimRight()}\n';
  }
}
