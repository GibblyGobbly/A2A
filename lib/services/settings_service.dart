import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AppSettings {
  final ThemeMode themeMode;
  final bool haptics;

  /// Folder for converted files. Null uses Download/OmniConvert.
  final String? outputDirectory;

  /// Version of the Terms of Use the user accepted; 0 when never accepted.
  final int acceptedTermsVersion;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.haptics = true,
    this.outputDirectory,
    this.acceptedTermsVersion = 0,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? haptics,
    String? Function()? outputDirectory,
    int? acceptedTermsVersion,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      haptics: haptics ?? this.haptics,
      outputDirectory: outputDirectory != null
          ? outputDirectory()
          : this.outputDirectory,
      acceptedTermsVersion: acceptedTermsVersion ?? this.acceptedTermsVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'haptics': haptics,
    'outputDirectory': outputDirectory,
    'acceptedTermsVersion': acceptedTermsVersion,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      haptics: json['haptics'] as bool? ?? true,
      outputDirectory: json['outputDirectory'] as String?,
      acceptedTermsVersion: json['acceptedTermsVersion'] as int? ?? 0,
    );
  }
}

/// App preferences, stored as JSON in the app's private documents folder.
class SettingsService {
  /// Bump when the Terms of Use change materially; users accept again once.
  static const int termsVersion = 1;

  static final ValueNotifier<AppSettings> notifier = ValueNotifier(
    const AppSettings(),
  );

  static AppSettings get current => notifier.value;
  static bool get termsAccepted => current.acceptedTermsVersion >= termsVersion;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
  }

  static Future<void> init() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        notifier.value = AppSettings.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        );
      }
    } on Exception catch (e) {
      developer.log(
        'Settings could not be read; using defaults: $e',
        name: 'SettingsService',
      );
    }
  }

  static Future<void> update(AppSettings settings) async {
    notifier.value = settings;
    try {
      await (await _file()).writeAsString(
        jsonEncode(settings.toJson()),
        flush: true,
      );
    } on Exception catch (e) {
      developer.log('Settings could not be saved: $e', name: 'SettingsService');
    }
  }

  static Future<void> acceptTerms() =>
      update(current.copyWith(acceptedTermsVersion: termsVersion));
}
