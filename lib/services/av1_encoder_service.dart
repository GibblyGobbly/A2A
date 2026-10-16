import 'dart:io';
import 'package:flutter/services.dart';

/// Result of one run of the bundled SVT-AV1 encoder.
class Av1RunResult {
  final int exitCode;
  final String log;

  const Av1RunResult(this.exitCode, this.log);

  bool get isSuccess => exitCode == 0;

  /// Last few log lines, which carry FFmpeg's actual error.
  String get errorTail {
    final lines = log
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return (lines.length > 4 ? lines.sublist(lines.length - 4) : lines).join(
      '\n',
    );
  }
}

/// Runs the bundled FFmpeg + SVT-AV1 executable (see
/// android/native/build_av1_encoder.sh). The phone's CPU does the encoding on
/// all cores; no AV1 hardware encoder is needed.
class Av1EncoderService {
  static const MethodChannel _channel = MethodChannel(
    'com.universal.converter/storage',
  );
  static final Map<int, void Function(int micros)> _listeners = {};
  static int _nextId = 1;
  static int? _activeId;
  static Future<bool>? _available;

  static Future<bool> isAvailable() {
    if (!Platform.isAndroid) return Future.value(false);
    return _available ??= _channel
        .invokeMethod<bool>('hasAv1Encoder')
        .then((v) => v ?? false)
        .catchError((Object _) => false);
  }

  static void handleProgress(Object? arguments) {
    if (arguments is! Map) return;
    final id = arguments['id'];
    final micros = arguments['timeUs'];
    if (id is int && micros is int) _listeners[id]?.call(micros);
  }

  /// Runs the encoder with FFmpeg [args]. [onTime] receives the encoded media
  /// position in microseconds.
  static Future<Av1RunResult> run(
    List<String> args, {
    void Function(int micros)? onTime,
  }) async {
    final id = _nextId++;
    if (onTime != null) _listeners[id] = onTime;
    _activeId = id;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'av1Encode',
        {'id': id, 'args': args},
      );
      return Av1RunResult(
        result?['code'] as int? ?? -1,
        result?['log'] as String? ?? '',
      );
    } on PlatformException catch (e) {
      return Av1RunResult(-1, e.message ?? e.code);
    } finally {
      _listeners.remove(id);
      if (_activeId == id) _activeId = null;
    }
  }

  static Future<void> cancel() async {
    final id = _activeId;
    if (id == null) return;
    try {
      await _channel.invokeMethod('av1Cancel', {'id': id});
    } on PlatformException {
      // The process already exited; nothing to cancel.
    }
  }
}
