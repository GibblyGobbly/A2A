// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import '../app_storage_service.dart';

/// Evenly spaced preview frames for timelines, grabbed by the native hardware
/// decoder. Stored in a private scratch folder; the caller deletes it.
class VideoThumbnailService {
  static const MethodChannel _channel = MethodChannel(
    'com.universal.converter/storage',
  );

  /// Returns the scratch folder and the thumbnail paths in time order. Empty
  /// paths when the phone cannot read frames from this file.
  static Future<({Directory folder, List<String> paths})> strip(
    String videoPath, {
    int count = 10,
    int height = 120,
  }) async {
    final folder = await AppStorageService.createWorkDirectory();
    if (!Platform.isAndroid) return (folder: folder, paths: <String>[]);
    try {
      final paths = await _channel.invokeListMethod<String>('videoThumbnails', {
        'path': videoPath,
        'outDir': folder.path,
        'count': count,
        'height': height,
      });
      return (folder: folder, paths: paths ?? <String>[]);
    } on PlatformException catch (e) {
      developer.log('Thumbnails failed: $e', name: 'VideoThumbnailService');
      return (folder: folder, paths: <String>[]);
    }
  }
}
