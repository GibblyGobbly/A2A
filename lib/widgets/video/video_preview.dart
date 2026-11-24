// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_theme.dart';
import '../brutal.dart';
import 'clock_text.dart';

/// The video, fitted to the space, with optional preview-only rotation and
/// mirroring. Shows a message when the phone cannot play the file.
class VideoPreview extends StatelessWidget {
  final VideoPlayerController controller;
  final int quarterTurns;
  final bool flipHorizontal;
  final bool flipVertical;

  const VideoPreview({
    super.key,
    required this.controller,
    this.quarterTurns = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.hasError) {
          return Center(
            child: Text(
              'This phone cannot preview this file. The tools still work.',
              textAlign: TextAlign.center,
              style: AppTheme.caption,
            ),
          );
        }
        if (!value.isInitialized) {
          return Center(child: CircularProgressIndicator(color: AppTheme.ink));
        }
        Widget video = AspectRatio(
          aspectRatio: value.aspectRatio,
          child: VideoPlayer(controller),
        );
        if (flipHorizontal || flipVertical) {
          video = Transform.flip(
            flipX: flipHorizontal,
            flipY: flipVertical,
            child: video,
          );
        }
        if (quarterTurns % 4 != 0) {
          video = RotatedBox(quarterTurns: quarterTurns, child: video);
        }
        return Center(
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.ink, width: AppTheme.stroke),
            ),
            child: video,
          ),
        );
      },
    );
  }
}

/// Play or pause, and the current time over the length.
class PlayBar extends StatelessWidget {
  final VideoPlayerController controller;

  /// Called instead of a plain play, for example to start inside a range.
  final VoidCallback? onPlay;

  const PlayBar({super.key, required this.controller, this.onPlay});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final position = value.position.inMilliseconds / 1000;
        return Row(
          children: [
            BrutalIconButton(
              icon: value.isPlaying ? Icons.pause : Icons.play_arrow,
              tooltip: value.isPlaying ? 'Pause' : 'Play',
              onPressed: value.isInitialized
                  ? () => value.isPlaying
                        ? controller.pause()
                        : (onPlay ?? controller.play)()
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              '${formatClock(position, tenths: true)} / '
              '${formatClock(value.duration.inMilliseconds / 1000)}',
              style: AppTheme.body,
            ),
          ],
        );
      },
    );
  }
}
