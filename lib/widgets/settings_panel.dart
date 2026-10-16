import 'package:flutter/material.dart';
import '../models/conversion_options.dart';
import '../models/conversion_target.dart';
import '../models/file_item.dart';
import '../theme/app_theme.dart';
import 'brutal.dart';

class SettingsPanel extends StatelessWidget {
  final ConversionTarget target;
  final ConversionOptions options;
  final List<FileItem> files;
  final ValueChanged<ConversionOptions> onChanged;

  const SettingsPanel({
    super.key,
    required this.target,
    required this.options,
    required this.files,
    required this.onChanged,
  });

  static const _imageSizes = <int?>[null, 3840, 2560, 1920, 1280, 800];
  static const _videoEdges = <int?>[null, 1080, 720, 480];
  static const _gifWidths = <int?>[320, 480, 640];
  static const _audioBitrates = [64, 96, 128, 192, 256, 320];

  int get _totalBytes => files.fold<int>(0, (sum, f) => sum + f.sizeInBytes);

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    void add(Widget w) {
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 16));
      sections.add(w);
    }

    switch (target.settings) {
      case TargetSettings.imageLossy:
        add(_modeToggle());
        add(options.usesTargetSize ? _targetSizeSlider() : _qualitySlider());
        add(_imageSize());
      case TargetSettings.imageLossless:
        add(_imageSize());
      case TargetSettings.imagePdf:
        add(_pdfLayout());
        add(_qualitySlider());
        add(_imageSize());
      case TargetSettings.video:
        add(_modeToggle());
        if (options.usesTargetSize) {
          add(_targetSizeSlider());
        } else {
          add(
            _choice(
              'Quality',
              VideoQuality.values,
              options.videoQuality,
              (v) => v.label,
              (v) => onChanged(options.copyWith(videoQuality: v)),
            ),
          );
        }
        add(
          _choice(
            'Resolution',
            _videoEdges,
            options.maxVideoShortEdge,
            (v) => v == null ? 'ORIGINAL' : '${v}P',
            (v) => onChanged(options.copyWith(maxVideoShortEdge: () => v)),
          ),
        );
      case TargetSettings.gif:
        add(
          _choice(
            'Width',
            _gifWidths,
            options.maxVideoShortEdge ?? 480,
            (v) => '$v PX',
            (v) => onChanged(options.copyWith(maxVideoShortEdge: () => v)),
          ),
        );
      case TargetSettings.audioLossy:
        add(
          _choice(
            'Bitrate',
            _audioBitrates,
            options.audioBitrateKbps,
            (v) => '$v K',
            (v) => onChanged(options.copyWith(audioBitrateKbps: v)),
          ),
        );
        add(
          Text(_audioHint(options.audioBitrateKbps), style: AppTheme.caption),
        );
      case TargetSettings.none:
        break;
    }

    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _choice<T>(
    String label,
    List<T> values,
    T selected,
    String Function(T) labelOf,
    ValueChanged<T> onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        ChoiceRow<T>(
          values: values,
          selected: selected,
          labelOf: labelOf,
          onSelected: onSelected,
        ),
      ],
    );
  }

  Widget _modeToggle() => _choice(
    'Compress by',
    CompressionMode.values,
    options.compressionMode,
    (m) => m.label,
    (m) => onChanged(options.copyWith(compressionMode: m)),
  );

  Widget _qualitySlider() {
    return ValueSlider(
      label: 'Quality',
      valueText: '${options.imageQuality}',
      value: options.imageQuality.toDouble(),
      min: 10,
      max: 100,
      divisions: 18,
      minHint: 'Smaller file',
      maxHint: 'Better quality',
      onChanged: (v) => onChanged(options.copyWith(imageQuality: v.round())),
    );
  }

  Widget _targetSizeSlider() {
    final estimate = FileItem.formatBytes(
      _totalBytes * options.targetSizePercent ~/ 100,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueSlider(
          label: 'Target size',
          valueText: '${options.targetSizePercent}%',
          value: options.targetSizePercent.toDouble(),
          min: 10,
          max: 90,
          divisions: 16,
          minHint: '10% of original',
          maxHint: '90%',
          onChanged: (v) =>
              onChanged(options.copyWith(targetSizePercent: v.round())),
        ),
        const SizedBox(height: 8),
        Text(
          files.length == 1
              ? 'About $estimate (from ${FileItem.formatBytes(_totalBytes)}).'
              : 'About $estimate in total (from ${FileItem.formatBytes(_totalBytes)}).',
          style: AppTheme.body,
        ),
      ],
    );
  }

  Widget _imageSize() => _choice(
    'Max size (longest edge)',
    _imageSizes,
    options.maxImageDimension,
    (v) => v == null ? 'ORIGINAL' : '$v',
    (v) => onChanged(options.copyWith(maxImageDimension: () => v)),
  );

  Widget _pdfLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _choice(
          'Page size',
          PdfPageSize.values,
          options.pdfPageSize,
          (v) => v.label,
          (v) => onChanged(options.copyWith(pdfPageSize: v)),
        ),
        if (options.pdfPageSize != PdfPageSize.fit) ...[
          const SizedBox(height: 16),
          _choice(
            'Orientation',
            PdfOrientation.values,
            options.pdfOrientation,
            (v) => v.label,
            (v) => onChanged(options.copyWith(pdfOrientation: v)),
          ),
        ],
        const SizedBox(height: 16),
        _choice(
          'Margins',
          PdfMargin.values,
          options.pdfMargin,
          (v) => v.label,
          (v) => onChanged(options.copyWith(pdfMargin: v)),
        ),
      ],
    );
  }

  static String _audioHint(int kbps) {
    if (kbps <= 64) return 'Speech and podcasts.';
    if (kbps <= 128) {
      return 'Good for most music. About 1 MB per minute at 128K.';
    }
    if (kbps <= 192) return 'High quality music.';
    return 'Near transparent. Larger files.';
  }
}
