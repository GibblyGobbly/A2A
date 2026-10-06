import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/conversion_options.dart';
import '../models/conversion_result.dart';
import '../models/file_item.dart';
import '../services/format_detector.dart';
import '../services/history_service.dart';
import '../services/media_converter_service.dart';
import '../theme/app_theme.dart';
import '../widgets/file_picker_box.dart';
import '../widgets/format_chips.dart';
import '../widgets/progress_dialog.dart';
import '../widgets/result_dialog.dart';
import '../widgets/settings_slider_card.dart';

class MediaStudioScreen extends StatefulWidget {
  const MediaStudioScreen({super.key});

  @override
  State<MediaStudioScreen> createState() => _MediaStudioScreenState();
}

class _MediaStudioScreenState extends State<MediaStudioScreen> {
  final List<FileItem> _selectedMedia = [];
  String _selectedFormat = 'mp3';
  ConversionOptions _options = ConversionOptions(
    audioBitrate: '192k',
    videoCrf: 30,
    videoPreset: 6,
  );

  final List<FormatOption> _mediaFormats = const [
    FormatOption(extension: 'mp3', label: 'MP3 (Audio)', description: 'Extract audio stream with MP3 LAME', category: FileCategory.audio),
    FormatOption(extension: 'av1', label: 'AV1 (Video)', description: 'Next-gen video compression (MP4)', category: FileCategory.video),
    FormatOption(extension: 'aac', label: 'AAC (Audio)', description: 'High efficiency audio stream', category: FileCategory.audio),
    FormatOption(extension: 'wav', label: 'WAV (Audio)', description: 'Uncompressed waveform audio', category: FileCategory.audio),
    FormatOption(extension: 'webm', label: 'WEBM (Video)', description: 'WebM video container', category: FileCategory.video),
    FormatOption(extension: 'gif', label: 'GIF (Video Clip)', description: 'Animated clip', category: FileCategory.image),
  ];

  Future<void> _pickMedia() async {
    final pickedFiles = await FilePicker.pickFiles(type: FileType.video);
    if (pickedFiles.isNotEmpty) {
      final newItems = pickedFiles
          .where((p) => p.path != null)
          .map((p) => FileItem.fromFile(File(p.path!)))
          .toList();

      setState(() {
        for (final item in newItems) {
          if (!_selectedMedia.any((f) => f.path == item.path)) {
            _selectedMedia.add(item);
          }
        }
      });
    }
  }

  void _clearAllMedia() {
    setState(() => _selectedMedia.clear());
  }

  void _removeMediaAt(int index) {
    setState(() => _selectedMedia.removeAt(index));
  }

  Future<void> _convert() async {
    if (_selectedMedia.isEmpty) return;

    final total = _selectedMedia.length;
    final results = <ConversionResult>[];

    bool isCancelled = false;
    double currentProgress = 0.0;
    String currentStatus = 'Encoding media...';
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
                const SnackBar(content: Text('Media conversion cancelled')),
              );
            },
          );
        },
      ),
    );

    for (int i = 0; i < total; i++) {
      if (isCancelled) break;
      final media = _selectedMedia[i];

      if (dialogSetState != null) {
        dialogSetState!(() {
          currentStatus = total == 1 ? 'Encoding ${media.name}...' : 'Encoding (${i + 1}/$total) ${media.name}';
          currentProgress = (i / total);
        });
      }

      final res = await MediaConverterService.convertMedia(
        sourceFile: media,
        targetFormat: _selectedFormat,
        options: _options,
        onProgress: (p, status) {
          if (dialogSetState != null && !isCancelled) {
            dialogSetState!(() {
              currentProgress = (i + p) / total;
              currentStatus = 'Encoding (${i + 1}/$total): ${(p * 100).toInt()}%';
            });
          }
        },
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
        title: const Text('Audio & Video Studio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilePickerBox(
              selectedFiles: _selectedMedia,
              onTap: _pickMedia,
              onClearAll: _clearAllMedia,
              onRemoveIndex: _removeMediaAt,
              title: 'Select Media Files',
              subtitle: 'Select one or multiple MP4, MKV, MOV, WEBM, MP3 files',
            ),
            if (_selectedMedia.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Target Output Format',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              FormatChips(
                formats: _mediaFormats,
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
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: Text(_selectedMedia.length == 1 ? 'Process Media' : 'Process ${_selectedMedia.length} Media Files'),
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
