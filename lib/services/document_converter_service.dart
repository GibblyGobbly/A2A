import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/conversion_result.dart';
import '../models/conversion_target.dart';
import '../models/file_item.dart';
import 'app_storage_service.dart';
import 'document/doc_model.dart';
import 'document/doc_writers.dart';
import 'document/ooxml_readers.dart';
import 'document/pdf_merger.dart';
import 'document/pdf_text_reader.dart';
import 'document/text_reader.dart';

class DocumentConverterService {
  static DocFonts? _fonts;

  /// Android system fonts give PDFs full Unicode coverage without bundling fonts.
  /// Static Roboto files are preferred; the pdf package cannot apply variable font axes.
  static Future<DocFonts> _systemFonts() async {
    final cached = _fonts;
    if (cached != null) return cached;
    Future<Uint8List?> first(List<String> names) async {
      for (final name in names) {
        final file = File('/system/fonts/$name');
        try {
          if (await file.exists()) return await file.readAsBytes();
        } on FileSystemException catch (e) {
          developer.log(
            'Font not readable: ${file.path}: $e',
            name: 'DocumentConverterService',
          );
        }
      }
      return null;
    }

    if (!Platform.isAndroid) return _fonts = const DocFonts();
    return _fonts = DocFonts(
      regular: await first([
        'RobotoStatic-Regular.ttf',
        'Roboto-Regular.ttf',
        'NotoSans-Regular.ttf',
        'DroidSans.ttf',
      ]),
      bold: await first([
        'RobotoStatic-Bold.ttf',
        'Roboto-Bold.ttf',
        'NotoSans-Bold.ttf',
        'DroidSans-Bold.ttf',
      ]),
      italic: await first([
        'RobotoStatic-Italic.ttf',
        'Roboto-Italic.ttf',
        'NotoSans-Italic.ttf',
      ]),
      boldItalic: await first([
        'RobotoStatic-BoldItalic.ttf',
        'Roboto-BoldItalic.ttf',
        'NotoSans-BoldItalic.ttf',
      ]),
    );
  }

  static DocModel readModel(Uint8List bytes, String extension, String title) {
    switch (extension) {
      case 'pdf':
        return PdfTextReader.read(bytes, title: title);
      case 'docx':
        return DocxReader.read(bytes, title: title);
      case 'pptx':
        return PptxReader.read(bytes, title: title);
      case 'md':
        return TextReader.readMarkdown(bytes, title: title);
      case 'txt':
        return TextReader.readText(bytes, title: title);
    }
    throw FormatException('.$extension documents are not supported');
  }

  static Future<ConversionResult> convertDocument({
    required FileItem sourceFile,
    required ConversionTarget target,
    void Function(double progress)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final sourceExt = sourceFile.extension.toLowerCase();
    final written = <String>[];

    ConversionResult fail(Object e) => ConversionResult.failure(
      sourcePath: sourceFile.path,
      sourceName: sourceFile.name,
      targetExtension: target.extension,
      originalSizeBytes: sourceFile.sizeInBytes,
      startedAt: startTime,
      errorMessage: e is FormatException ? e.message : e.toString(),
    );

    try {
      if (sourceExt == 'pdf' &&
          (target.id == 'jpg' || target.id == 'png' || target.id == 'pptx')) {
        written.addAll(await _renderPdf(sourceFile, target, onProgress));
      } else {
        final input = await File(sourceFile.path).readAsBytes();
        final fonts = target.id == 'pdf'
            ? await _systemFonts()
            : const DocFonts();
        final title = sourceFile.baseName;
        final targetId = target.id;
        final output = await Isolate.run(() async {
          final model = readModel(input, sourceExt, title);
          switch (targetId) {
            case 'pdf':
              return PdfDocWriter.write(model, fonts: fonts);
            case 'docx':
              return DocxWriter.write(model);
            case 'txt':
              return encodeText(model.toPlainText());
          }
          throw FormatException('Cannot convert .$sourceExt to .$targetId');
        });
        final path = await AppStorageService.generateOutputPath(
          baseName: title,
          extension: target.extension,
        );
        written.add(path);
        await File(path).writeAsBytes(output, flush: true);
      }

      var total = 0;
      for (final path in written) {
        await AppStorageService.notifyMediaScanner(path);
        total += await File(path).length();
      }
      return ConversionResult(
        sourcePath: sourceFile.path,
        sourceName: sourceFile.name,
        targetPath: written.first,
        targetName: written.length == 1
            ? written.first.split('/').last
            : '${written.length} pages',
        targetExtension: target.extension,
        outputPaths: written,
        originalSizeBytes: sourceFile.sizeInBytes,
        convertedSizeBytes: total,
        duration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      for (final path in written) {
        await AppStorageService.deleteQuietly(File(path));
      }
      return fail(e);
    }
  }

  /// UTF-8, with a byte order mark when the text is not plain ASCII so that
  /// Windows Notepad shows it correctly.
  static Uint8List encodeText(String text) {
    final body = utf8.encode(text);
    if (body.length == text.length) return body;
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...body]);
  }

  /// PDF to page images or to a picture-per-slide PPTX, via Android's PdfRenderer.
  static Future<List<String>> _renderPdf(
    FileItem source,
    ConversionTarget target,
    void Function(double)? onProgress,
  ) async {
    final workDir = await AppStorageService.createWorkDirectory();
    try {
      final format = target.id == 'png' ? 'png' : 'jpg';
      final pages = await AppStorageService.renderPdfPages(
        pdfPath: source.path,
        outDir: workDir.path,
        format: format,
        dpi: 150,
        quality: 85,
      );
      if (pages.isEmpty) throw const FormatException('The PDF has no pages');
      onProgress?.call(0.6);

      final outputDir = await AppStorageService.getOutputDirectory();
      final base = AppStorageService.sanitizeBaseName(source.baseName);
      if (target.id == 'pptx') {
        final slides = <PictureSlide>[];
        for (final page in pages) {
          final bytes = await File(page).readAsBytes();
          final info = img.findDecoderForData(bytes)?.startDecode(bytes);
          if (info == null) {
            throw const FormatException('A rendered page could not be read');
          }
          slides.add(PictureSlide(bytes, info.width, info.height));
        }
        final pptx = await Isolate.run(
          () => PptxWriter.writePictureSlides(slides),
        );
        final path = AppStorageService.uniquePath(outputDir.path, base, 'pptx');
        await File(path).writeAsBytes(pptx, flush: true);
        return [path];
      }

      // One page keeps the plain name; several get their own folder.
      final Directory destination;
      if (pages.length == 1) {
        destination = outputDir;
      } else {
        destination = Directory(
          AppStorageService.uniqueDirectoryPath(outputDir.path, '$base pages'),
        );
        await destination.create(recursive: true);
      }
      final outputs = <String>[];
      try {
        for (var i = 0; i < pages.length; i++) {
          final name = pages.length == 1 ? base : '$base page ${i + 1}';
          final path = AppStorageService.uniquePath(
            destination.path,
            name,
            format,
          );
          // Cache and shared storage are different file systems, so copy instead of rename.
          await File(pages[i]).copy(path);
          outputs.add(path);
        }
      } catch (_) {
        if (pages.length > 1) {
          await AppStorageService.deleteQuietly(destination);
        }
        rethrow;
      }
      return outputs;
    } finally {
      await AppStorageService.deleteQuietly(workDir);
    }
  }

  static Future<ConversionResult> mergePdfs({
    required List<FileItem> sources,
    void Function(double progress)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final totalInput = sources.fold<int>(0, (sum, f) => sum + f.sizeInBytes);
    String? targetPath;
    try {
      final inputs = <Uint8List>[];
      for (final source in sources) {
        inputs.add(await File(source.path).readAsBytes());
      }
      onProgress?.call(0.3);
      final merged = await Isolate.run(() => PdfMerger.merge(inputs));
      targetPath = await AppStorageService.generateOutputPath(
        baseName: '${sources.first.baseName} merged',
        extension: 'pdf',
      );
      await File(targetPath).writeAsBytes(merged, flush: true);
      await AppStorageService.notifyMediaScanner(targetPath);
      return ConversionResult(
        sourcePath: sources.first.path,
        sourceName: '${sources.length} PDFs',
        targetPath: targetPath,
        targetName: targetPath.split('/').last,
        targetExtension: 'pdf',
        originalSizeBytes: totalInput,
        convertedSizeBytes: merged.length,
        duration: DateTime.now().difference(startTime),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (targetPath != null) {
        await AppStorageService.deleteQuietly(File(targetPath));
      }
      return ConversionResult.failure(
        sourcePath: sources.first.path,
        sourceName: '${sources.length} PDFs',
        targetExtension: 'pdf',
        originalSizeBytes: totalInput,
        startedAt: startTime,
        errorMessage: e is FormatException ? e.message : e.toString(),
      );
    }
  }
}
