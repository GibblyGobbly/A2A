// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../../models/file_item.dart';
import '../../../services/video/video_tools_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/icon_label_button.dart';
import '../../../widgets/task_runner.dart';
import '../../../widgets/tool_scaffold.dart';
import '../../../widgets/video/video_preview.dart';
import 'player_host.dart';

/// Turn or mirror videos. Turning alone is instant; mirroring re-encodes.
class VideoRotateScreen extends StatefulWidget {
  final List<FileItem> files;

  const VideoRotateScreen({super.key, required this.files});

  @override
  State<VideoRotateScreen> createState() => _VideoRotateScreenState();
}

class _VideoRotateScreenState extends State<VideoRotateScreen> with PlayerHost {
  int _turns = 0;
  bool _flipH = false;
  bool _flipV = false;

  @override
  String get playerPath => widget.files.first.path;

  bool get _unchanged => _turns == 0 && !_flipH && !_flipV;

  /// Mirrors as seen on screen. The preview flips before it turns, so after a
  /// quarter turn a left-right mirror is a top-bottom flip of the source.
  void _mirror({required bool sideways}) => setState(() {
    final sourceX = sideways != _turns.isOdd;
    if (sourceX) {
      _flipH = !_flipH;
    } else {
      _flipV = !_flipV;
    }
  });

  Future<void> _save() {
    final flips = _flipH || _flipV;
    return runTask(
      context,
      work: (progress) => VideoToolsService.rotateFlip(
        files: widget.files,
        quarterTurns: _turns,
        flipHorizontal: _flipH,
        flipVertical: _flipV,
        onProgress: progress,
      ),
      onCancel: VideoToolsService.cancel,
      keepAlive: flips ? 'Mirroring video' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.files.length;
    return ToolScaffold(
      title: 'Rotate and flip',
      subtitle: count == 1
          ? widget.files.first.name
          : '$count videos, same change to all',
      scrollable: false,
      actionLabel: count == 1 ? 'Save copy' : 'Save $count copies',
      onAction: _unchanged ? null : _save,
      children: [
        Expanded(
          child: VideoPreview(
            controller: player,
            quarterTurns: _turns,
            flipHorizontal: _flipH,
            flipVertical: _flipV,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: IconLabelButton(
                icon: Icons.rotate_left,
                label: 'Left',
                onPressed: () => setState(() => _turns = (_turns + 3) % 4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: IconLabelButton(
                icon: Icons.rotate_right,
                label: 'Right',
                onPressed: () => setState(() => _turns = (_turns + 1) % 4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: IconLabelButton(
                icon: Icons.flip,
                label: 'Mirror',
                onPressed: () => _mirror(sideways: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: IconLabelButton(
                icon: Icons.swap_vert,
                label: 'Flip',
                onPressed: () => _mirror(sideways: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _flipH || _flipV
              ? 'Mirroring re-encodes the video on the phone\'s video chip.'
              : 'Turning is instant and keeps the exact quality.',
          style: AppTheme.caption,
        ),
      ],
    );
  }
}
