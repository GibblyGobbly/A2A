// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../../../models/file_item.dart';
import '../../../services/video/commands/frame_commands.dart';
import '../../../services/video/frame_extractor_service.dart';
import '../../../services/video/video_info_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/brutal.dart';
import '../../../widgets/task_runner.dart';
import '../../../widgets/tool_scaffold.dart';
import '../../../widgets/video/clock_text.dart';
import '../../../widgets/video/video_preview.dart';
import 'player_host.dart';

/// Save frames of a video as pictures.
class FramesScreen extends StatefulWidget {
  final FileItem file;

  const FramesScreen({super.key, required this.file});

  @override
  State<FramesScreen> createState() => _FramesScreenState();
}

class _FramesScreenState extends State<FramesScreen> with PlayerHost {
  static const _intervals = [0.5, 1.0, 2.0, 5.0, 10.0];

  /// Above this many pictures the button warns before starting.
  static const _manyFrames = 1000;

  FrameMode _mode = FrameMode.single;
  double? _fps;
  double _every = 1;
  String _format = 'jpg';

  @override
  String get playerPath => widget.file.path;

  @override
  void initState() {
    super.initState();
    player.addListener(_onTick);
    VideoInfoService.read(widget.file.path).then(
      (info) => mounted ? setState(() => _fps = info.fps) : null,
      // Without the frame rate only the "every frame" count is unknown.
      onError: (Object e) =>
          developer.log('Could not read fps: $e', name: 'FramesScreen'),
    );
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    player.removeListener(_onTick);
    super.dispose();
  }

  double get _duration => player.value.duration.inMilliseconds / 1000;
  double get _position => player.value.position.inMilliseconds / 1000;

  int? get _estimate => FrameCommands.estimateCount(
    _mode,
    durationSeconds: _duration,
    fps: _fps,
    everySeconds: _every,
  );

  Future<void> _save() async {
    if (_mode == FrameMode.single) {
      await player.pause();
      if (!mounted) return;
      final at = _position;
      await runTask(
        context,
        work: (_) => FrameExtractorService.single(
          file: widget.file,
          seconds: at,
          extension: _format,
        ),
        onCancel: FrameExtractorService.cancel,
      );
      return;
    }
    await runTask(
      context,
      work: (progress) => FrameExtractorService.many(
        file: widget.file,
        mode: _mode,
        extension: _format,
        everySeconds: _every,
        onProgress: progress,
      ),
      onCancel: FrameExtractorService.cancel,
      keepAlive: 'Saving frames',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = player.value.isInitialized && _duration > 0;
    return ToolScaffold(
      title: 'Save frames',
      subtitle: widget.file.name,
      scrollable: false,
      actionLabel: _actionLabel(),
      actionIcon: Icons.photo_library_outlined,
      onAction: ready ? _save : null,
      children: [
        Expanded(child: VideoPreview(controller: player)),
        if (_mode == FrameMode.single && ready) ...[
          Slider(
            value: _position.clamp(0.0, _duration),
            max: _duration,
            onChanged: (v) =>
                player.seekTo(Duration(milliseconds: (v * 1000).round())),
          ),
          Text(
            'Frame at ${formatClock(_position, tenths: true)}. '
            'Drag to pick the moment.',
            style: AppTheme.caption,
          ),
        ],
        const SizedBox(height: 16),
        const SectionLabel('Which frames'),
        ChoiceRow<FrameMode>(
          values: FrameMode.values,
          selected: _mode,
          labelOf: (m) => m.label,
          onSelected: (m) => setState(() => _mode = m),
        ),
        if (_mode == FrameMode.interval) ...[
          const SizedBox(height: 12),
          ChoiceRow<double>(
            values: _intervals,
            selected: _every,
            labelOf: (s) => '${s == s.roundToDouble() ? s.round() : s} S',
            onSelected: (s) => setState(() => _every = s),
          ),
        ],
        const SizedBox(height: 12),
        ChoiceRow<String>(
          values: const ['jpg', 'png'],
          selected: _format,
          labelOf: (f) => f.toUpperCase(),
          onSelected: (f) => setState(() => _format = f),
        ),
        const SizedBox(height: 8),
        Text(_hint(), style: AppTheme.caption),
      ],
    );
  }

  String _actionLabel() {
    if (_mode == FrameMode.single) return 'Save this frame';
    if (_mode == FrameMode.scenes) return 'Save scene changes';
    final n = _estimate;
    if (n == null) return 'Save every frame';
    return n > _manyFrames
        ? 'Save about $n pictures (large)'
        : 'Save about $n pictures';
  }

  String _hint() => switch (_mode) {
    FrameMode.single => 'Saved at full resolution.',
    FrameMode.interval =>
      'Pictures go into a new folder named after the video.',
    FrameMode.scenes =>
      'One picture each time the scene changes. Good for picking shots.',
    FrameMode.all =>
      'Every frame: a 1 minute video at 30 fps makes 1,800 pictures. '
          'Saved into a new folder.',
  };
}
