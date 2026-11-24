// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/file_item.dart';
import '../../../services/app_storage_service.dart';
import '../../../services/video/video_thumbnail_service.dart';
import '../../../services/video/video_tools_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/brutal.dart';
import '../../../widgets/gesture_safe_padding.dart';
import '../../../widgets/switch_row.dart';
import '../../../widgets/task_runner.dart';
import '../../../widgets/tool_scaffold.dart';
import '../../../widgets/video/clock_text.dart';
import '../../../widgets/video/trim_timeline.dart';
import '../../../widgets/video/video_preview.dart';
import 'player_host.dart';

/// Keep one part of a video or audio file.
class TrimScreen extends StatefulWidget {
  final FileItem file;

  const TrimScreen({super.key, required this.file});

  @override
  State<TrimScreen> createState() => _TrimScreenState();
}

class _TrimScreenState extends State<TrimScreen> with PlayerHost {
  List<String> _thumbs = const [];
  Directory? _thumbFolder;
  double _start = 0;
  double? _end;
  bool _precise = false;

  bool get _isVideo => widget.file.category == FileCategory.video;

  @override
  String get playerPath => widget.file.path;

  double get _duration => player.value.duration.inMilliseconds / 1000;

  @override
  void initState() {
    super.initState();
    player.addListener(_onTick);
    if (_isVideo) _loadThumbs();
  }

  Future<void> _loadThumbs() async {
    final strip = await VideoThumbnailService.strip(widget.file.path);
    if (!mounted) {
      await AppStorageService.deleteQuietly(strip.folder);
      return;
    }
    setState(() {
      _thumbFolder = strip.folder;
      _thumbs = strip.paths;
    });
  }

  /// Rebuilds for the play position, and stops playback at the end handle.
  void _onTick() {
    final end = _end;
    final position = player.value.position.inMilliseconds / 1000;
    if (end != null && player.value.isPlaying && position >= end) {
      player.pause();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    player.removeListener(_onTick);
    final folder = _thumbFolder;
    if (folder != null) AppStorageService.deleteQuietly(folder);
    super.dispose();
  }

  void _playRange() {
    final position = player.value.position.inMilliseconds / 1000;
    final end = _end ?? _duration;
    if (position < _start || position >= end - 0.05) {
      player.seekTo(Duration(milliseconds: (_start * 1000).round()));
    }
    player.play();
  }

  Future<void> _save() {
    final end = _end ?? _duration;
    return runTask(
      context,
      work: (progress) => VideoToolsService.trim(
        file: widget.file,
        start: _start,
        end: end,
        precise: _precise,
        onProgress: progress,
      ),
      onCancel: VideoToolsService.cancel,
      keepAlive: _precise ? 'Trimming ${widget.file.name}' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = player.value.isInitialized && _duration > 0;
    final end = _end ?? _duration;
    return ToolScaffold(
      title: 'Trim',
      subtitle: widget.file.name,
      scrollable: false,
      actionLabel: 'Save trimmed copy',
      actionIcon: Icons.content_cut,
      onAction: ready ? _save : null,
      children: [
        Expanded(
          child: _isVideo
              ? VideoPreview(controller: player)
              : Center(
                  child: CategoryTile(
                    color: AppTheme.muted,
                    icon: Icons.graphic_eq,
                    size: 96,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        PlayBar(controller: player, onPlay: _playRange),
        const SizedBox(height: 8),
        if (ready)
          GestureSafePadding(
            child: TrimTimeline(
              thumbnails: _thumbs,
              duration: _duration,
              start: _start,
              end: end,
              position: player.value.position.inMilliseconds / 1000,
              onRangeChanged: (s, e) => setState(() {
                _start = s;
                _end = e;
              }),
              onSeek: (t) =>
                  player.seekTo(Duration(milliseconds: (t * 1000).round())),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'From ${formatClock(_start, tenths: true)} to '
          '${formatClock(end, tenths: true)}, '
          'keeps ${formatClock(end - _start, tenths: true)}',
          style: AppTheme.body,
        ),
        const SizedBox(height: 8),
        SwitchRow(
          label: 'Exact cut',
          caption: _precise
              ? 'Cuts on the exact frame. Takes longer.'
              : 'Instant, no quality loss. May start up to 2 s early.',
          value: _precise,
          onChanged: (v) => setState(() => _precise = v),
        ),
      ],
    );
  }
}
