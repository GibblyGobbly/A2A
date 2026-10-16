import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_converter/services/app_storage_service.dart';
import 'package:universal_converter/services/settings_service.dart';

void main() {
  test('settings survive a save and load, including the output folder', () {
    const settings = AppSettings(
      themeMode: ThemeMode.dark,
      haptics: false,
      outputDirectory: '/storage/emulated/0/Documents/Converted',
      acceptedTermsVersion: 1,
    );
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.haptics, isFalse);
    expect(restored.outputDirectory, settings.outputDirectory);
    expect(restored.acceptedTermsVersion, 1);
  });

  test('the output folder label follows the setting and can be reset', () {
    SettingsService.notifier.value = const AppSettings(
      outputDirectory: '/storage/emulated/0/Documents/Converted',
    );
    expect(AppStorageService.publicFolderLabel, 'Documents/Converted');

    SettingsService.notifier.value = SettingsService.current.copyWith(
      outputDirectory: () => null,
    );
    expect(AppStorageService.publicFolderLabel, 'Download/OmniConvert');
  });

  test('unknown or missing values fall back to defaults', () {
    final restored = AppSettings.fromJson({'themeMode': 'sepia'});
    expect(restored.themeMode, ThemeMode.system);
    expect(restored.haptics, isTrue);
    expect(restored.outputDirectory, isNull);
  });
}
