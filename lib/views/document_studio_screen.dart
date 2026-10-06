import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/conversion_options.dart';
import '../models/conversion_result.dart';
import '../models/file_item.dart';
import '../services/document_converter_service.dart';
import '../services/format_detector.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/file_picker_box.dart';
import '../widgets/format_chips.dart';
import '../widgets/progress_dialog.dart';
import '../widgets/result_dialog.dart';

class DocumentStudioScreen extends StatefulWidget {
  const DocumentStudioScreen({super.key});

  @override
  State<DocumentStudioScreen> createState() => _DocumentStudioScreenState();
}

class _DocumentStudioScreenState extends State<DocumentStudioScreen> {
  final List<FileItem> _selectedDocs = [];
  String _selectedFormat = 'docx';
  final ConversionOptions _options = ConversionOptions();

  final List<FormatOption> _docFormats = const [
    FormatOption(extension: 'pdf', label: 'PDF', description: 'Standard PDF document', category: FileCategory.document),
    FormatOption(extension: 'docx', label: 'DOCX (Word)', description: 'Editable Word document', category: FileCategory.document),
    FormatOption(extension: 'pptx', label: 'PPTX (PowerPoint)', description: 'Presentation slides', category: FileCategory.document),
    FormatOption(extension: 'txt', label: 'TXT (Plain Text)', description: 'Extracted text content', category: FileCategory.document),
  ];

  Future<void> _pickDocs() async {
    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'md'],
    );
    if (pickedFiles.isNotEmpty) {
      final newItems = pickedFiles
          .where((p) => p.path != null)
          .map((p) => FileItem.fromFile(File(p.path!)))
          .toList();

      setState(() {
        for (final item in newItems) {
          if (!_selectedDocs.any((f) => f.path == item.path)) {
            _selectedDocs.add(item);
          }
        }
        if (_selectedDocs.isNotEmpty) {
          final firstExt = _selectedDocs.first.extension;
          _selectedFormat = firstExt == 'pdf' ? 'docx' : 'pdf';
        }
      });
    }
  }

  void _clearAllDocs() {
    setState(() => _selectedDocs.clear());
  }

  void _removeDocAt(int index) {
    setState(() => _selectedDocs.removeAt(index));
  }

  Future<void> _convert() async {
    if (_selectedDocs.isEmpty) return;

    final total = _selectedDocs.length;
    final results = <ConversionResult>[];

    bool isCancelled = false;
    double currentProgress = 0.0;
    String currentStatus = 'Processing document...';
    StateSetter? dialogSetState;

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          dialogSetState = setDialogState;
          return ProgressDialog(
            statusText: currentStatus,
            subText: 'Saved in Download/OmniConvert',
            progress: currentProgress,
            onCancel: () {
              isCancelled = true;
              nav.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Document conversion cancelled')),
              );
            },
          );
        },
      ),
    );

    for (int i = 0; i < total; i++) {
      if (isCancelled) break;
      final doc = _selectedDocs[i];

      if (dialogSetState != null) {
        dialogSetState!(() {
          currentStatus = total == 1 ? 'Converting ${doc.name}...' : 'Converting (${i + 1}/$total) ${doc.name}';
          currentProgress = (i / total);
        });
      }

      final res = await DocumentConverterService.convertDocument(
        sourceFile: doc,
        targetFormat: _selectedFormat,
        options: _options,
      );

      if (!isCancelled) {
        results.add(res);
        if (res.isSuccess) {
          await HistoryService.addResult(res);
        }
      }
    }

    if (isCancelled || !mounted) return;
    Navigator.of(context).pop();

    if (results.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => ResultDialog(results: results),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document & PDF Studio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilePickerBox(
              selectedFiles: _selectedDocs,
              onTap: _pickDocs,
              onClearAll: _clearAllDocs,
              onRemoveIndex: _removeDocAt,
              title: 'Select Documents',
              subtitle: 'Select one or multiple PDF, DOCX, PPTX, TXT files',
            ),
            if (_selectedDocs.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Target Document Format',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              FormatChips(
                formats: _docFormats,
                selectedFormat: _selectedFormat,
                onSelected: (fmt) => setState(() => _selectedFormat = fmt),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text(_selectedDocs.length == 1 ? 'Convert Document' : 'Convert ${_selectedDocs.length} Documents'),
                  onPressed: _convert,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
