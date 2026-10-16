import 'dart:io';
import 'package:flutter/services.dart';
import 'av1_encoder_service.dart';
import 'share_intake_service.dart';

/// Routes calls from the native side. A method channel has one handler, so
/// every native-to-Dart event is dispatched from here.
class NativeEvents {
  static const MethodChannel _channel = MethodChannel(
    'com.universal.converter/storage',
  );

  static void init() {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'sharedFiles':
          ShareIntakeService.accept(call.arguments);
        case 'av1Progress':
          Av1EncoderService.handleProgress(call.arguments);
      }
      return null;
    });
  }
}
