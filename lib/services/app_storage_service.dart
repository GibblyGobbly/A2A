import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppStorageService {
  static const MethodChannel _channel = MethodChannel('com.universal.converter/storage');

  static Future<Directory> getOutputDirectory() async {
    if (Platform.isAndroid) {
      try {
        final String? publicPath = await _channel.invokeMethod<String>('getPublicDirectory');
        if (publicPath != null && publicPath.isNotEmpty) {
          final dir = Directory(publicPath);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      } catch (_) {}

      final defaultPublic = Directory('/storage/emulated/0/Download/OmniConvert');
      try {
        if (!await defaultPublic.exists()) {
          await defaultPublic.create(recursive: true);
        }
        return defaultPublic;
      } catch (_) {}
    }

    final baseDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory('${baseDir.path}/OmniConvert');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    return outputDir;
  }

  static Future<String> generateOutputPath({
    required String baseName,
    required String extension,
  }) async {
    final dir = await getOutputDirectory();
    final cleanExt = extension.toLowerCase().replaceAll('.', '').trim();
    final cleanBase = baseName.replaceAll(RegExp(r'[^\w\s\.-]'), '_').trim();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${cleanBase}_converted_$timestamp.$cleanExt';
  }

  static Future<void> notifyMediaScanner(String filePath) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('scanFile', {'path': filePath});
      } catch (_) {}
    }
  }

  static Future<void> openFolder([String? folderPath]) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('openFolder', {'path': folderPath});
      } catch (_) {}
    }
  }

  static String getDisplayPath(String fullPath) {
    if (fullPath.contains('/storage/emulated/0/')) {
      return fullPath.replaceFirst('/storage/emulated/0/', '');
    }
    return fullPath.split('/').length > 2
        ? fullPath.split('/').sublist(fullPath.split('/').length - 2).join('/')
        : fullPath;
  }
}

