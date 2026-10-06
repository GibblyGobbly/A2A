import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/conversion_result.dart';

class HistoryService {
  static const String _fileName = 'conversion_history.json';
  static final ValueNotifier<List<ConversionResult>> historyNotifier = ValueNotifier<List<ConversionResult>>([]);
  static bool _isInitialized = false;

  static Future<File> _getHistoryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> init() async {
    if (_isInitialized) return;
    await refreshHistory();
    _isInitialized = true;
  }

  static Future<List<ConversionResult>> getHistory() async {
    try {
      final file = await _getHistoryFile();
      if (!await file.exists()) {
        historyNotifier.value = [];
        return [];
      }
      final jsonString = await file.readAsString();
      final List<dynamic> list = jsonDecode(jsonString);
      final results = list.map((item) => ConversionResult.fromJson(item)).toList();
      historyNotifier.value = results;
      return results;
    } catch (_) {
      historyNotifier.value = [];
      return [];
    }
  }

  static Future<void> refreshHistory() async {
    await getHistory();
  }

  static Future<void> addResult(ConversionResult result) async {
    try {
      final list = List<ConversionResult>.from(historyNotifier.value);
      list.insert(0, result);
      historyNotifier.value = list;

      final file = await _getHistoryFile();
      final jsonString = jsonEncode(list.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (_) {}
  }

  static Future<void> clearHistory() async {
    try {
      historyNotifier.value = [];
      final file = await _getHistoryFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<void> deleteItem(ConversionResult item) async {
    try {
      final list = List<ConversionResult>.from(historyNotifier.value);
      list.removeWhere((element) => element.targetPath == item.targetPath && element.timestamp == item.timestamp);
      historyNotifier.value = list;

      final file = await _getHistoryFile();
      final jsonString = jsonEncode(list.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (_) {}
  }
}
