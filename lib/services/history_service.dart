import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/conversion_result.dart';

class HistoryService {
  static const String _fileName = 'conversion_history.json';
  static const int _maxEntries = 500;
  static final ValueNotifier<List<ConversionResult>> historyNotifier =
      ValueNotifier<List<ConversionResult>>([]);
  static bool _isInitialized = false;

  static void _log(String message, Object error) {
    developer.log('$message: $error', name: 'HistoryService');
  }

  static Future<File> _getHistoryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> init() async {
    if (_isInitialized) return;
    await refreshHistory();
    _isInitialized = true;
  }

  static Future<void> refreshHistory() async {
    try {
      final file = await _getHistoryFile();
      if (!await file.exists()) {
        historyNotifier.value = [];
        return;
      }
      final List<dynamic> list = jsonDecode(await file.readAsString());
      historyNotifier.value = list
          .whereType<Map<String, dynamic>>()
          .map(ConversionResult.fromJson)
          .toList();
    } on Exception catch (e) {
      // A corrupt history file must not stop the app from starting.
      _log('History could not be read; starting empty', e);
      historyNotifier.value = [];
    }
  }

  static Future<void> _persist(List<ConversionResult> list) async {
    historyNotifier.value = list;
    try {
      final file = await _getHistoryFile();
      await file.writeAsString(
        jsonEncode(list.map((e) => e.toJson()).toList()),
        flush: true,
      );
    } on Exception catch (e) {
      _log('History could not be saved', e);
    }
  }

  static Future<void> addResult(ConversionResult result) async {
    final list = [result, ...historyNotifier.value];
    await _persist(
      list.length > _maxEntries ? list.sublist(0, _maxEntries) : list,
    );
  }

  static Future<void> clearHistory() => _persist([]);

  static bool _same(ConversionResult a, ConversionResult b) =>
      a.targetPath == b.targetPath && a.timestamp == b.timestamp;

  static Future<void> deleteItem(ConversionResult item) =>
      _persist(historyNotifier.value.where((e) => !_same(e, item)).toList());

  static Future<void> deleteItems(List<ConversionResult> items) => _persist(
    historyNotifier.value
        .where((e) => !items.any((item) => _same(e, item)))
        .toList(),
  );

  /// Puts a removed item back at its previous position (for undo).
  static Future<void> restoreItem(ConversionResult item, int index) async {
    final list = List<ConversionResult>.from(historyNotifier.value);
    list.insert(index.clamp(0, list.length), item);
    await _persist(list);
  }
}
