// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Keeps long jobs alive with the screen off through a native foreground
/// service, and mirrors their progress in a notification.
class BackgroundWorkService {
  static const MethodChannel _channel = MethodChannel(
    'com.universal.converter/storage',
  );

  static String _title = '';
  static int _lastPercent = -2;
  static DateTime _lastUpdate = DateTime(0);

  static Future<void> _call(String method, [Map<String, Object?>? args]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod(method, args);
    } on PlatformException catch (e) {
      // The job still runs without the service; it may just stop if the
      // screen turns off.
      developer.log('$method failed: $e', name: 'BackgroundWorkService');
    }
  }

  static Future<void> start(String title) async {
    if (!Platform.isAndroid) return;
    _title = title;
    _lastPercent = -2;
    // Android 13+ hides the progress notification without this permission.
    // Asked once; the job runs either way.
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    await _call('workStart', {'title': title});
  }

  /// At most a few updates per second, and only when the percent changes.
  static void update(double? progress, String status) {
    final percent = progress == null ? -1 : (progress * 100).round();
    final now = DateTime.now();
    if (percent == _lastPercent ||
        now.difference(_lastUpdate) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastPercent = percent;
    _lastUpdate = now;
    _call('workUpdate', {
      'title': _title,
      'text': percent < 0 ? status : '$percent%  $status',
      'percent': percent,
    });
  }

  static Future<void> stop() => _call('workStop');
}
