// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:developer' as developer;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Runs FFmpeg commands in ffmpeg-kit with progress and cancellation. Only one
/// command runs at a time; tools process files one after another.
class FfmpegRunner {
  static int? _activeSessionId;
  static bool _cancelRequested = false;

  static bool get cancelRequested => _cancelRequested;

  /// Marks the start of a new job, clearing an earlier cancel.
  static void reset() => _cancelRequested = false;

  static Future<void> cancel() async {
    _cancelRequested = true;
    final id = _activeSessionId;
    try {
      await FFmpegKit.cancel(id);
    } on Exception catch (e) {
      developer.log('Cancel failed: $e', name: 'FfmpegRunner');
    }
  }

  /// Runs [args]. [totalMs] is the length of media being written, used to
  /// turn FFmpeg's time position into progress from 0 to 1. Returns null on
  /// success, 'Cancelled', or the last lines of FFmpeg's log.
  static Future<String?> run(
    List<String> args, {
    double totalMs = 0,
    void Function(double progress)? onProgress,
  }) async {
    if (_cancelRequested) return 'Cancelled';
    try {
      final session = await _start(args, totalMs, onProgress);
      final code = await session.getReturnCode();
      if (ReturnCode.isSuccess(code)) return null;
      if (ReturnCode.isCancel(code) || _cancelRequested) return 'Cancelled';
      return _failureText(session);
    } finally {
      _activeSessionId = null;
      FFmpegKitConfig.enableStatisticsCallback(null);
    }
  }

  static Future<FFmpegSession> _start(
    List<String> args,
    double totalMs,
    void Function(double)? onProgress,
  ) {
    final completer = Completer<FFmpegSession>();
    FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) => completer.complete(session),
      null,
      (statistics) {
        if (totalMs > 0 && onProgress != null) {
          onProgress((statistics.getTime() / totalMs).clamp(0.0, 1.0));
        }
      },
    ).then(
      (session) => _activeSessionId = session.getSessionId(),
      onError: completer.completeError,
    );
    return completer.future;
  }

  static Future<String> _failureText(FFmpegSession session) async {
    final logs = await session.getAllLogsAsString() ?? '';
    final lines = logs
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    // The last few log lines carry the actual FFmpeg error.
    final tail = lines.length > 4 ? lines.sublist(lines.length - 4) : lines;
    final code = (await session.getReturnCode())?.getValue();
    return tail.isEmpty ? 'FFmpeg failed with code $code' : tail.join('\n');
  }
}
