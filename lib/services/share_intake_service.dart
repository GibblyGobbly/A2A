import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';

/// Files shared into A2A from other apps. The native side copies them into the
/// app cache; the matching tool screen takes them with [take].
class ShareIntakeService {
  static const MethodChannel _channel = MethodChannel(
    'com.universal.converter/storage',
  );
  static final ValueNotifier<List<FileItem>> pending = ValueNotifier(const []);

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    await _deleteOldCopies();
    try {
      accept(await _channel.invokeMethod<List<dynamic>>('takeSharedFiles'));
    } on PlatformException catch (e) {
      developer.log(
        'Could not read shared files: $e',
        name: 'ShareIntakeService',
      );
    }
  }

  /// Shared files are copied into the cache; drop copies older than a day.
  static Future<void> _deleteOldCopies() async {
    try {
      final cache = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(const Duration(days: 1));
      await for (final entity in cache.list(followLinks: false)) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (entity is Directory &&
            name.startsWith('shared_') &&
            (await entity.stat()).modified.isBefore(cutoff)) {
          await entity.delete(recursive: true);
        }
      }
    } on FileSystemException catch (e) {
      developer.log(
        'Could not clean shared copies: $e',
        name: 'ShareIntakeService',
      );
    }
  }

  /// Called by [NativeEvents] when files are shared while the app is running.
  static void accept(Object? arguments) {
    if (arguments is! List) return;
    final items = <FileItem>[];
    for (final path in arguments.whereType<String>()) {
      final file = File(path);
      if (file.existsSync()) items.add(FileItem.fromFile(file));
    }
    if (items.isNotEmpty) pending.value = items;
  }

  /// Returns and clears pending files of [category].
  static List<FileItem> take(FileCategory category) {
    final mine = pending.value.where((f) => f.category == category).toList();
    if (mine.isNotEmpty) {
      pending.value = pending.value
          .where((f) => f.category != category)
          .toList();
    }
    return mine;
  }
}
