import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/conversion_options.dart';
import '../models/conversion_result.dart';
import '../models/file_item.dart';
import 'app_storage_service.dart';

class DocumentConverterService {
  static Future<ConversionResult> convertDocument({
    required FileItem sourceFile,
    required String targetFormat,
    required ConversionOptions options,
  }) async {
    final startTime = DateTime.now();
    final cleanTargetExt = targetFormat.toLowerCase().replaceAll('.', '');
    final cleanSourceExt = sourceFile.extension.toLowerCase().replaceAll('.', '');
    final baseName = sourceFile.name.contains('.')
        ? sourceFile.name.substring(0, sourceFile.name.lastIndexOf('.'))
        : sourceFile.name;

    final targetPath = await AppStorageService.generateOutputPath(
      baseName: baseName,
      extension: cleanTargetExt,
    );

    try {
      final inputBytes = await File(sourceFile.path).readAsBytes();

      if (cleanSourceExt == 'pdf') {
        if (cleanTargetExt == 'txt') {
          final text = _extractTextFromPdf(inputBytes);
          await File(targetPath).writeAsString(text);
        } else if (cleanTargetExt == 'docx') {
          final text = _extractTextFromPdf(inputBytes);
          final docxBytes = _createDocxFromText(text, title: baseName);
          await File(targetPath).writeAsBytes(docxBytes);
        } else if (cleanTargetExt == 'pptx') {
          final text = _extractTextFromPdf(inputBytes);
          final pptxBytes = _createPptxFromText(text, title: baseName);
          await File(targetPath).writeAsBytes(pptxBytes);
        }
      } else if (cleanSourceExt == 'docx') {
        final text = _extractTextFromDocx(inputBytes);
        if (cleanTargetExt == 'pdf') {
          final pdfBytes = await _createPdfFromText(text, title: baseName);
          await File(targetPath).writeAsBytes(pdfBytes);
        } else if (cleanTargetExt == 'txt') {
          await File(targetPath).writeAsString(text);
        } else if (cleanTargetExt == 'pptx') {
          final pptxBytes = _createPptxFromText(text, title: baseName);
          await File(targetPath).writeAsBytes(pptxBytes);
        }
      } else if (cleanSourceExt == 'txt' || cleanSourceExt == 'md') {
        final text = utf8.decode(inputBytes, allowMalformed: true);
        if (cleanTargetExt == 'pdf') {
          final pdfBytes = await _createPdfFromText(text, title: baseName);
          await File(targetPath).writeAsBytes(pdfBytes);
        } else if (cleanTargetExt == 'docx') {
          final docxBytes = _createDocxFromText(text, title: baseName);
          await File(targetPath).writeAsBytes(docxBytes);
        } else if (cleanTargetExt == 'pptx') {
          final pptxBytes = _createPptxFromText(text, title: baseName);
          await File(targetPath).writeAsBytes(pptxBytes);
        }
      } else {
        final text = utf8.decode(inputBytes, allowMalformed: true);
        final pdfBytes = await _createPdfFromText(text, title: baseName);
        await File(targetPath).writeAsBytes(pdfBytes);
      }

      final targetFile = File(targetPath);
      await AppStorageService.notifyMediaScanner(targetPath);
      final targetStat = await targetFile.stat();

      return ConversionResult(
        sourcePath: sourceFile.path,
        sourceName: sourceFile.name,
        targetPath: targetPath,
        targetName: targetPath.split('/').last,
        targetExtension: cleanTargetExt,
        originalSizeBytes: sourceFile.sizeInBytes,
        convertedSizeBytes: targetStat.size,
        duration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
        isSuccess: true,
      );
    } catch (e) {
      return ConversionResult(
        sourcePath: sourceFile.path,
        sourceName: sourceFile.name,
        targetPath: targetPath,
        targetName: '${baseName}_converted.$cleanTargetExt',
        targetExtension: cleanTargetExt,
        originalSizeBytes: sourceFile.sizeInBytes,
        convertedSizeBytes: 0,
        duration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
        isSuccess: false,
        errorMessage: e.toString(),
      );
    }
  }

  static String _extractTextFromPdf(List<int> bytes) {
    final document = sf.PdfDocument(inputBytes: bytes);
    final textExtractor = sf.PdfTextExtractor(document);
    final text = textExtractor.extractText();
    document.dispose();
    return text.isEmpty ? 'Empty document content' : text;
  }

  static String _extractTextFromDocx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final docXmlFile = archive.findFile('word/document.xml');
      if (docXmlFile != null) {
        final content = utf8.decode(docXmlFile.content as List<int>, allowMalformed: true);
        return content.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    } catch (_) {}
    return utf8.decode(bytes, allowMalformed: true);
  }

  static Future<List<int>> _createPdfFromText(String text, {required String title}) async {
    final pdf = pw.Document();
    final paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text(title, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
          );
        },
        build: (pw.Context context) {
          return paragraphs.map((p) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                p,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
              ),
            );
          }).toList();
        },
      ),
    );

    return await pdf.save();
  }

  static List<int> _createDocxFromText(String text, {required String title}) {
    final paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).toList();
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    buffer.write('<w:body>');

    for (final p in paragraphs) {
      final escaped = const HtmlEscape().convert(p);
      buffer.write('<w:p><w:r><w:t>$escaped</w:t></w:r></w:p>');
    }

    buffer.write('</w:body></w:document>');

    final archive = Archive();
    final contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';

    final rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';

    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypes.length, utf8.encode(contentTypes)));
    archive.addFile(ArchiveFile('_rels/.rels', rels.length, utf8.encode(rels)));
    final docXml = buffer.toString();
    archive.addFile(ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml)));

    return ZipEncoder().encode(archive);
  }

  static List<int> _createPptxFromText(String text, {required String title}) {
    final archive = Archive();

    final contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>'
        '</Types>';

    final presentationXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
        '<p:sldIdLst><p:sldId id="256" r:id="rId1" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/></p:sldIdLst>'
        '</p:presentation>';

    final slideXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<p:cSld><p:spTree>'
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr/>'
        '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
        '<p:txBody><a:bodyPr/><a:p><a:r><a:t>${const HtmlEscape().convert(title)}</a:t></a:r></a:p></p:txBody>'
        '</p:sp>'
        '</p:spTree></p:cSld>'
        '</p:sld>';

    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypes.length, utf8.encode(contentTypes)));
    archive.addFile(ArchiveFile('ppt/presentation.xml', presentationXml.length, utf8.encode(presentationXml)));
    archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slideXml.length, utf8.encode(slideXml)));

    return ZipEncoder().encode(archive);
  }
}
