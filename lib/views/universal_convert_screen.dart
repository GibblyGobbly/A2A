import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/conversion_options.dart';
import '../models/conversion_result.dart';
import '../models/file_item.dart';
import '../services/document_converter_service.dart';
import '../services/format_detector.dart';
import '../services/history_service.dart';
import '../services/image_converter_service.dart';
import '../services/media_converter_service.dart';
import '../theme/app_theme.dart';
import '../widgets/file_picker_box.dart';
import '../widgets/format_chips.dart';
import '../widgets/progress_dialog.dart';
import '../widgets/result_dialog.dart';
import '../widgets/settings_slider_card.dart';

class UniversalConvertScreen extends StatefulWidget {
  const UniversalConvertScreen({super.key});

  @override
  State<UniversalConvertScreen> createState() => _UniversalConvertScreenState();
}

class _UniversalConvertScreenState extends State<UniversalConvertScreen> {
  final List<FileItem> _selectedFiles = [];
  List<FormatOption> _availableFormats = [];
  String? _selectedTargetFormat;
  ConversionOptions _options = ConversionOptions();

  Future<void> _pickFiles() async {
    final pickedFiles = await FilePicker.pickFiles(type: FileType.any);
    if (pickedFiles.isNotEmpty) {
      final newItems = pickedFiles
          .where((p) => p.path != null)
          .map((p) => FileItem.fromFile(File(p.path!)))
          .toList();

      setState(() {
        for (final item in newItems) {
          if (!_selectedFiles.any((f) => f.path == item.path)) {
            _selectedFiles.add(item);
          }
        }
        if (_selectedFiles.isNotEmpty) {
          _availableFormats = FormatDetector.getAvailableTargets(_selectedFiles.first.extension);
          if (_availableFormats.isNotEmpty && (_selectedTargetFormat == null || !_availableFormats.any((f) => f.extension == _selectedTargetFormat))) {
            _selectedTargetFormat = _availableFormats.first.extension;
          }
        }
      });
    }
  }

  void _clearAllFiles() {
    setState(() {
      _selectedFiles.clear();
      _availableFormats = [];
      _selectedTargetFormat = null;
    });
  }

  void _removeFileAt(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      if (_selectedFiles.isEmpty) {
        _availableFormats = [];
        _selectedTargetFormat = null;
      }
    });
  }

  Future<void> _runConversion() async {
    if (_selectedFiles.isEmpty || _selectedTargetFormat == null) return;

    final targetExt = _selectedTargetFormat!;
    final total = _selectedFiles.length;
    final results = <ConversionResult>[];

    bool isCancelled = false;
    double currentProgress = 0.0;
    String currentStatus = 'Converting...';
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
            onCancel: () async {
              isCancelled = true;
              await MediaConverterService.cancelActiveConversions();
              nav.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Conversion cancelled')),
              );
            },
          );
        },
      ),
    );

    for (int i = 0; i < total; i++) {
      if (isCancelled) break;
      final fileItem = _selectedFiles[i];
      final cat = fileItem.category;

      if (dialogSetState != null) {
        dialogSetState!(() {
          currentStatus = total == 1 ? 'Converting ${fileItem.name}...' : 'Converting (${i + 1}/$total) ${fileItem.name}';
          currentProgress = (i / total);
        });
      }

      ConversionResult res;
      if (cat == FileCategory.image || ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif', 'ico'].contains(targetExt)) {
        res = await ImageConverterService.convertImage(
          sourceFile: fileItem,
          targetFormat: targetExt,
          options: _options,
        );
      } else if (cat == FileCategory.video || cat == FileCategory.audio || ['mp3', 'av1', 'webm', 'mkv', 'wav', 'aac'].contains(targetExt)) {
        res = await MediaConverterService.convertMedia(
          sourceFile: fileItem,
          targetFormat: targetExt,
          options: _options,
          onProgress: (p, status) {
            if (dialogSetState != null && !isCancelled) {
              dialogSetState!(() {
                currentProgress = (i + p) / total;
                currentStatus = 'Converting (${i + 1}/$total): ${(p * 100).toInt()}%';
              });
            }
          },
        );
      } else {
        res = await DocumentConverterService.convertDocument(
          sourceFile: fileItem,
          targetFormat: targetExt,
          options: _options,
        );
      }

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
        title: const Text('A2A'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilePickerBox(
              selectedFiles: _selectedFiles,
              onTap: _pickFiles,
              onClearAll: _clearAllFiles,
              onRemoveIndex: _removeFileAt,
              title: 'Select Files to Convert',
              subtitle: 'Select one or multiple files from device storage',
            ),
            if (_selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Convert To',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              FormatChips(
                formats: _availableFormats,
                selectedFormat: _selectedTargetFormat,
                onSelected: (fmt) {
                  setState(() => _selectedTargetFormat = fmt);
                },
              ),
              if (_selectedTargetFormat != null) ...[
                const SizedBox(height: 16),
                SettingsSliderCard(
                  targetFormat: _selectedTargetFormat!,
                  options: _options,
                  onChanged: (opt) => setState(() => _options = opt),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 20),
                    label: Text(_selectedFiles.length == 1 ? 'Convert File' : 'Convert ${_selectedFiles.length} Files'),
                    onPressed: _runConversion,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
