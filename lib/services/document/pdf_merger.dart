import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class PdfMerger {
  /// Appends every page of every input, in order, keeping each page's size.
  /// Pages are copied as vector templates, so text stays selectable.
  static Uint8List merge(List<Uint8List> inputs) {
    final output = sf.PdfDocument();
    try {
      output.pageSettings.margins.all = 0;
      for (final (index, bytes) in inputs.indexed) {
        final sf.PdfDocument source;
        try {
          source = sf.PdfDocument(inputBytes: bytes);
        } on Object {
          throw FormatException(
            'PDF ${index + 1} is damaged or password protected',
          );
        }
        try {
          for (var i = 0; i < source.pages.count; i++) {
            final page = source.pages[i];
            final size = page.size;
            final section = output.sections!.add();
            section.pageSettings.size = size;
            section.pageSettings.margins.all = 0;
            final target = section.pages.add();
            target.graphics.drawPdfTemplate(
              page.createTemplate(),
              Offset.zero,
              size,
            );
          }
        } finally {
          source.dispose();
        }
      }
      return Uint8List.fromList(output.saveSync());
    } finally {
      output.dispose();
    }
  }
}
