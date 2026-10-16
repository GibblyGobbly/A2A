import 'dart:developer' as developer;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings_service.dart';

class AppStorageService {
  static const MethodChannel _channel = MethodChannel(
    'com.universal.converter/storage',
  );
  static const String defaultOutputPath =
      '/storage/emulated/0/Download/OmniConvert';

  static Directory? _cachedOutputDir;

  /// Short, readable form of the current output folder, such as
  /// "Download/OmniConvert".
  static String get publicFolderLabel => getDisplayPath(
    SettingsService.current.outputDirectory ?? defaultOutputPath,
  );

  static void _log(String message, Object error) {
    developer.log('$message: $error', name: 'AppStorageService');
  }

  /// Android 10 and older need the legacy storage permission to write into Download/.
  /// Android 11+ lets any app create files in Download/ without a permission.
  static Future<void> _ensureLegacyWritePermission() async {
    if (!Platform.isAndroid) return;
    try {
      final sdkInt = await _channel.invokeMethod<int>('getSdkInt') ?? 0;
      if (sdkInt > 0 && sdkInt <= 29) {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      }
    } on PlatformException catch (e) {
      _log('Storage permission check failed', e);
    }
  }

  static Future<bool> _isWritable(Directory dir) async {
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probe = File('${dir.path}/.a2a_write_test');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on FileSystemException catch (e) {
      _log('Directory not writable: ${dir.path}', e);
      return false;
    }
  }

  static Future<Directory> getOutputDirectory() async {
    final cached = _cachedOutputDir;
    final chosen = SettingsService.current.outputDirectory;
    if (cached != null &&
        await cached.exists() &&
        (chosen == null || cached.path == chosen)) {
      return cached;
    }

    if (Platform.isAndroid) {
      await _ensureLegacyWritePermission();
      if (chosen != null && await _isWritable(Directory(chosen))) {
        return _cachedOutputDir = Directory(chosen);
      }
      String? publicPath;
      try {
        publicPath = await _channel.invokeMethod<String>('getPublicDirectory');
      } on PlatformException catch (e) {
        _log('getPublicDirectory failed', e);
      }
      final candidates = [
        if (publicPath != null && publicPath.isNotEmpty) Directory(publicPath),
        Directory(defaultOutputPath),
      ];
      for (final dir in candidates) {
        if (await _isWritable(dir)) {
          return _cachedOutputDir = dir;
        }
      }
    }

    final baseDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory('${baseDir.path}/OmniConvert');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    return _cachedOutputDir = outputDir;
  }

  /// Private scratch directory for intermediate files. Never shown to the user.
  static Future<Directory> createWorkDirectory() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(
      '${tmp.path}/a2a_work_${DateTime.now().microsecondsSinceEpoch}',
    );
    await dir.create(recursive: true);
    return dir;
  }

  static Future<void> deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) {
        await entity.delete(recursive: true);
      }
    } on FileSystemException catch (e) {
      _log('Could not delete ${entity.path}', e);
    }
  }

  static String sanitizeBaseName(String baseName) {
    final clean = baseName.replaceAll(RegExp(r'[^\w\s.-]'), '_').trim();
    return clean.isEmpty ? 'file' : clean;
  }

  static Future<String> generateOutputPath({
    required String baseName,
    required String extension,
  }) async {
    final dir = await getOutputDirectory();
    return uniquePath(dir.path, sanitizeBaseName(baseName), extension);
  }

  /// `name.ext`, or `name (2).ext` and so on when the name is taken.
  static String uniquePath(String dirPath, String baseName, String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '').trim();
    var candidate = '$dirPath/$baseName.$ext';
    var n = 2;
    while (File(candidate).existsSync() || Directory(candidate).existsSync()) {
      candidate = '$dirPath/$baseName ($n).$ext';
      n++;
    }
    return candidate;
  }

  static String uniqueDirectoryPath(String dirPath, String name) {
    var candidate = '$dirPath/$name';
    var n = 2;
    while (File(candidate).existsSync() || Directory(candidate).existsSync()) {
      candidate = '$dirPath/$name ($n)';
      n++;
    }
    return candidate;
  }

  static Future<void> notifyMediaScanner(String filePath) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('scanFile', {'path': filePath});
      } on PlatformException catch (e) {
        _log('Media scan failed for $filePath', e);
      }
    }
  }

  /// Lets the user pick the output folder. Returns null when the folder was
  /// set or the picker was cancelled, or a message explaining why it was refused.
  static Future<String?> chooseOutputDirectory() async {
    final String? path;
    try {
      path = await FilePicker.getDirectoryPath(
        dialogTitle: 'Folder for converted files',
      );
    } on PlatformException catch (e) {
      return 'The folder picker could not open: ${e.message}';
    }
    if (path == null || path.isEmpty) return null;
    if (path == '/') {
      return 'Android did not give A2A a file path for that location. Pick a folder on the phone storage.';
    }
    if (!await _isWritable(Directory(path))) {
      return 'Android does not let apps save into ${getDisplayPath(path)}. '
          'Pick a folder inside Download or Documents.';
    }
    _cachedOutputDir = null;
    await SettingsService.update(
      SettingsService.current.copyWith(outputDirectory: () => path),
    );
    return null;
  }

  static Future<void> resetOutputDirectory() async {
    _cachedOutputDir = null;
    await SettingsService.update(
      SettingsService.current.copyWith(outputDirectory: () => null),
    );
  }

  /// Opens the output folder in the system file manager. Returns false when no app can show it.
  static Future<bool> openOutputFolder() async {
    if (!Platform.isAndroid) return false;
    try {
      final dir = await getOutputDirectory();
      return await _channel.invokeMethod<bool>('openFolder', {
            'path': dir.path,
          }) ??
          false;
    } on PlatformException catch (e) {
      _log('openFolder failed', e);
      return false;
    }
  }

  static Future<bool> hasHardwareAv1Encoder() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasHardwareAv1Encoder') ??
          false;
    } on PlatformException catch (e) {
      _log('AV1 encoder probe failed', e);
      return false;
    }
  }

  /// Renders every page of a PDF to images with Android's PdfRenderer.
  static Future<List<String>> renderPdfPages({
    required String pdfPath,
    required String outDir,
    required String format,
    int dpi = 150,
    int quality = 85,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Rendering PDF pages needs Android');
    }
    final pages = await _channel.invokeListMethod<String>('renderPdfPages', {
      'path': pdfPath,
      'outDir': outDir,
      'format': format,
      'dpi': dpi,
      'quality': quality,
    });
    return pages ?? const [];
  }

  static Future<String> appVersion() async {
    if (!Platform.isAndroid) return '';
    try {
      return await _channel.invokeMethod<String>('getAppVersion') ?? '';
    } on PlatformException catch (e) {
      _log('Version lookup failed', e);
      return '';
    }
  }

  /// Opens [url] in the user's browser. Returns false when no browser exists.
  static Future<bool> openUrl(String url) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openUrl', {'url': url}) ??
          false;
    } on PlatformException catch (e) {
      _log('openUrl failed', e);
      return false;
    }
  }

  /// Bytes used by temporary copies (picked and shared files, work folders).
  static Future<int> temporaryFilesSize() async {
    var total = 0;
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) total += await entity.length();
      }
    } on FileSystemException catch (e) {
      _log('Could not measure cache', e);
    }
    return total;
  }

  /// Deletes temporary copies. Converted files and history are not touched.
  static Future<void> clearTemporaryFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list(followLinks: false)) {
        await deleteQuietly(entity);
      }
    } on FileSystemException catch (e) {
      _log('Could not clear cache', e);
    }
  }

  static String getDisplayPath(String fullPath) {
    if (fullPath.contains('/storage/emulated/0/')) {
      return fullPath.replaceFirst('/storage/emulated/0/', '');
    }
    final parts = fullPath.split('/');
    return parts.length > 2
        ? parts.sublist(parts.length - 2).join('/')
        : fullPath;
  }
}
