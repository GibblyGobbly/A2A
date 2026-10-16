import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_converter/main.dart';
import 'package:universal_converter/models/conversion_result.dart';
import 'package:universal_converter/services/history_service.dart';
import 'package:universal_converter/services/settings_service.dart';
import 'package:universal_converter/theme/app_theme.dart';
import 'package:universal_converter/views/history_screen.dart';
import 'package:universal_converter/views/settings_screen.dart';

void main() {
  setUp(() {
    SettingsService.notifier.value = const AppSettings(
      acceptedTermsVersion: SettingsService.termsVersion,
    );
  });

  testWidgets('first launch asks to accept the terms once', (tester) async {
    SettingsService.notifier.value = const AppSettings();
    await tester.pumpWidget(const OmniConvertApp());
    await tester.pumpAndSettle();

    expect(find.text('WELCOME TO A2A'), findsOneWidget);
    await tester.tap(find.text('ACCEPT AND CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('WELCOME TO A2A'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('ACCEPT AND CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('PICK FILES'), findsOneWidget);
    expect(SettingsService.termsAccepted, isTrue);
  });

  testWidgets('every widget follows a theme switch from settings', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const OmniConvertApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings').first);
    await tester.pumpAndSettle();

    Color titleColor() =>
        tester.widget<Text>(find.text('SETTINGS')).style!.color!;
    Color rowColor() =>
        tester.widget<Text>(find.text('Haptic feedback')).style!.color!;

    // The bug sequence: system (dark) -> light -> system.
    for (final (mode, palette) in [
      (ThemeMode.light, Palette.light),
      (ThemeMode.system, Palette.dark),
      (ThemeMode.light, Palette.light),
      (ThemeMode.dark, Palette.dark),
    ]) {
      await tester.tap(find.text(mode.name.toUpperCase()));
      await tester.pumpAndSettle();
      expect(titleColor(), palette.ink, reason: '$mode title');
      expect(rowColor(), palette.ink, reason: '$mode row');
    }
  });

  testWidgets('settings switches to dark mode', (tester) async {
    await tester.pumpWidget(const OmniConvertApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);

    await tester.tap(find.text('DARK'));
    await tester.pumpAndSettle();
    expect(SettingsService.current.themeMode, ThemeMode.dark);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(
      Theme.of(tester.element(find.byWidget(scaffold))).brightness,
      Brightness.dark,
    );

    await tester.scrollUntilVisible(
      find.text('Privacy Policy'),
      200,
      scrollable: find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('PRIVACY POLICY'), findsOneWidget);
    expect(find.textContaining('does not collect'), findsOneWidget);
  });

  testWidgets('home shows the image tool and swipes to the video tool', (
    tester,
  ) async {
    await tester.pumpWidget(const OmniConvertApp());
    await tester.pumpAndSettle();

    expect(find.text('IMAGE'), findsWidgets);
    expect(find.text('PICK FILES'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(
      find.text('Shrink videos, change format or pull out the audio.'),
      findsOneWidget,
    );
  });

  testWidgets('bottom bar opens the file history', (tester) async {
    await tester.pumpWidget(const OmniConvertApp());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('FILES'));
    await tester.pumpAndSettle();
    expect(
      find.text('Your converted files will show up here.'),
      findsOneWidget,
    );
  });

  testWidgets('long-press selects files and select all picks every match', (
    tester,
  ) async {
    HistoryService.historyNotifier.value = [
      _entry('a.jpg'),
      _entry('b.mp4'),
      _entry('c.pdf'),
    ];
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HistoryScreen())),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('a.jpg'));
    await tester.pumpAndSettle();
    expect(find.text('1 SELECTED'), findsOneWidget);

    await tester.tap(find.text('b.mp4'));
    await tester.pumpAndSettle();
    expect(find.text('2 SELECTED'), findsOneWidget);

    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('3 SELECTED'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pumpAndSettle();
    expect(find.text('FILES'), findsOneWidget);
    HistoryService.historyNotifier.value = [];
  });
}

ConversionResult _entry(String name) => ConversionResult(
  sourcePath: '/in/$name',
  sourceName: name,
  targetPath: '/out/$name',
  targetName: name,
  targetExtension: name.split('.').last,
  originalSizeBytes: 2000,
  convertedSizeBytes: 1000,
  duration: Duration.zero,
  timestamp: DateTime(2026, 1, 1),
);
