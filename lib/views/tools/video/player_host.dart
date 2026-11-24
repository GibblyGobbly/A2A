// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Owns a [VideoPlayerController] for a screen: creates it, starts loading,
/// and disposes it. Errors show up in the controller's value.
mixin PlayerHost<T extends StatefulWidget> on State<T> {
  late final VideoPlayerController player;

  /// Path of the file to play; read once in [initState].
  String get playerPath;

  @override
  void initState() {
    super.initState();
    player = VideoPlayerController.file(File(playerPath));
    player.initialize().catchError((Object e) {
      // The controller keeps the error in its value; the preview shows it.
      developer.log('Preview failed: $e', name: 'PlayerHost');
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
