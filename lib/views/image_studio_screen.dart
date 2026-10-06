import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/conversion_options.dart';
import '../models/conversion_result.dart';
import '../models/file_item.dart';
import '../services/format_detector.dart';
import '../services/history_service.dart';
import '../services/image_converter_service.dart';
import '../theme/app_theme.dart';
import '../widgets/file_picker_box.dart';
import '../widgets/format_chips.dart';
import '../widgets/progress_dialog.dart';
import '../widgets/result_dialog.dart';
import '../widgets/settings_slider_card.dart';

class ImageStudioScreen extends StatefulWidget {
  const ImageStudioScreen({super.key});

  @override
  State<ImageStudioScreen> createState() => _ImageStudioScreenState();
}

class _ImageStudioScreenState extends State<ImageStudioScreen> {
  final List<FileItem> _selectedImages = [];
  String _selectedFormat = 'jpg';
  ConversionOptions _options = ConversionOptions(imageQuality: 80);

  final List<FormatOption> _imageFormats = const [
    FormatOption(extension: 'jpg', label: 'JPG / JPEG', description: 'Lossy with quality slider', category: FileCategory.image),
    FormatOption(extension: 'png', label: 'PNG', description: 'Lossless format', category: FileCategory.image),
    FormatOption(extension: 'webp', label: 'WEBP', description: 'High compression web image', category: FileCategory.image),
    FormatOption(extension: 'bmp', label: 'BMP', description: 'Bitmap', category: FileCategory.image),
    FormatOption(extension: 'pdf', label: 'PDF', description: 'Convert image to PDF page', category: FileCategory.document),
  ];

  Future<void> _pickImages() async {
    final pickedFiles = await FilePicker.pickFiles(type: FileType.image);
    if (pickedFiles.isNotEmpty) {
      final newItems = pickedFiles
          .where((p) => p.path != null)
          .map((p) => FileItem.fromFile(File(p.path!)))
          .toList();

      setState(() {
        for (final item in newItems) {
          if (!_selectedImages.any((f) => f.path == item.path)) {
            _selectedImages.add(item);
          }
        }
        if (_selectedImages.isNotEmpty) {
          final firstExt = _selectedImages.first.extension;
          _selectedFormat = firstExt == 'jpg' || firstExt == 'jpeg' ? 'png' : 'jpg';
        }
      });
    }
  }

  void _clearAllImages() {
    setState(() => _selectedImages.clear());
  }

  void _removeImageAt(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _convert() async {
    if (_selectedImages.isEmpty) return;

    final total = _selectedImages.length;
    final results = <ConversionResult>[];
    bool isCancelled = false;
    double currentProgress = 0.0;
    String currentStatus = 'Processing image...';
    StateSetter? dialogSetState;

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
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image conversion cancelled')),
                );
              }
            },
          );
        },
      ),
    );

    for (int i = 0; i < total; i++) {
      if (isCancelled) break;
      final img = _selectedImages[i];

      if (dialogSetState != null) {
        dialogSetState!(() {
          currentStatus = total == 1 ? 'Processing ${img.name}...' : 'Processing (${i + 1}/$total) ${img.name}';
          currentProgress = (i / total);
        });
      }

      final res = await ImageConverterService.convertImage(
        sourceFile: img,
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
        title: const Text('Image & Compression Studio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilePickerBox(
              selectedFiles: _selectedImages,
              onTap: _pickImages,
              onClearAll: _clearAllImages,
              onRemoveIndex: _removeImageAt,
              title: 'Select Images',
              subtitle: 'Select one or multiple PNG, JPG, WEBP, BMP images',
            ),
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Target Image Format',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              FormatChips(
                formats: _imageFormats,
                selectedFormat: _selectedFormat,
                onSelected: (fmt) => setState(() => _selectedFormat = fmt),
              ),
              const SizedBox(height: 16),
              SettingsSliderCard(
                targetFormat: _selectedFormat,
                options: _options,
                onChanged: (opt) => setState(() => _options = opt),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(_selectedImages.length == 1 ? 'Convert & Compress' : 'Convert & Compress ${_selectedImages.length} Images'),
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
