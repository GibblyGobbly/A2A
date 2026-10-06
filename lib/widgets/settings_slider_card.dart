import 'package:flutter/material.dart';
import '../models/conversion_options.dart';
import '../theme/app_theme.dart';

class SettingsSliderCard extends StatefulWidget {
  final String targetFormat;
  final ConversionOptions options;
  final ValueChanged<ConversionOptions> onChanged;

  const SettingsSliderCard({
    super.key,
    required this.targetFormat,
    required this.options,
    required this.onChanged,
  });

  @override
  State<SettingsSliderCard> createState() => _SettingsSliderCardState();
}

class _SettingsSliderCardState extends State<SettingsSliderCard> {
  late double _currentQuality;
  late double _currentCrf;

  @override
  void initState() {
    super.initState();
    _currentQuality = widget.options.imageQuality.toDouble();
    _currentCrf = widget.options.videoCrf.toDouble();
  }

  @override
  void didUpdateWidget(covariant SettingsSliderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.imageQuality != widget.options.imageQuality) {
      _currentQuality = widget.options.imageQuality.toDouble();
    }
    if (oldWidget.options.videoCrf != widget.options.videoCrf) {
      _currentCrf = widget.options.videoCrf.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanExt = widget.targetFormat.toLowerCase().replaceAll('.', '');

    if (['jpg', 'jpeg', 'webp'].contains(cleanExt)) {
      return _buildImageQualityCard(context);
    }

    if (cleanExt == 'mp3' || cleanExt == 'aac') {
      return _buildAudioBitrateCard(context);
    }

    if (['av1', 'mp4', 'webm', 'mkv'].contains(cleanExt)) {
      return _buildVideoCompressionCard(context, cleanExt);
    }

    return const SizedBox.shrink();
  }

  Widget _buildImageQualityCard(BuildContext context) {
    final displayPercent = _currentQuality.round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Compression Quality',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$displayPercent%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Slider(
            value: _currentQuality,
            min: 1,
            max: 100,
            onChanged: (val) {
              setState(() => _currentQuality = val);
              widget.onChanged(widget.options.copyWith(imageQuality: val.round()));
            },
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Smallest file (1%)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              Text('Highest quality (100%)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioBitrateCard(BuildContext context) {
    final bitrates = ['64k', '128k', '192k', '256k', '320k'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Bitrate',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: bitrates.map((b) {
              final isSelected = widget.options.audioBitrate == b;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => widget.onChanged(widget.options.copyWith(audioBitrate: b)),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryBlue : AppTheme.lightBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        b,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCompressionCard(BuildContext context, String format) {
    final displayCrf = _currentCrf.round();
    final resolutions = ['Original', '1080p', '720p', '480p'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                format == 'av1' ? 'AV1 Compression (CRF)' : 'Video Compression (CRF)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'CRF $displayCrf',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Slider(
            value: _currentCrf,
            min: 24,
            max: 48,
            onChanged: (val) {
              setState(() => _currentCrf = val);
              widget.onChanged(widget.options.copyWith(videoCrf: val.round()));
            },
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('High quality (24)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              Text('Balanced (38)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              Text('Smallest size (48)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Target Resolution',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: resolutions.map((res) {
              final isSelected = widget.options.videoResolution == res;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => widget.onChanged(widget.options.copyWith(videoResolution: res)),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryBlue : AppTheme.lightBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        res,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
