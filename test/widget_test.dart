// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_converter/main.dart';
import 'package:universal_converter/models/conversion_result.dart';
import 'package:universal_converter/models/file_item.dart';
import 'package:universal_converter/services/history_service.dart';
import 'package:universal_converter/services/settings_service.dart';
import 'package:universal_converter/theme/app_theme.dart';
import 'package:universal_converter/views/history_screen.dart';
import 'package:universal_converter/views/settings_screen.dart';
import 'package:universal_converter/views/workspace/workspace_screen.dart';

void main() {
  setUp(() {
    SettingsService.notifier.value = const AppSettings(
      acceptedTermsVersion: SettingsService.termsVersion,
    );
  });

  testWidgets('first launch asks to accept the terms once', (tester) async {
    SettingsService.notifier.value = const AppSettings();
    await tester.pumpWidget(const A2AApp());
    await tester.pumpAndSettle();

    expect(find.text('WELCOME TO A2A'), findsOneWidget);
    await tester.tap(find.text('ACCEPT AND CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('WELCOME TO A2A'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('ACCEPT AND CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('OPEN FILES'), findsOneWidget);
    expect(SettingsService.termsAccepted, isTrue);
  });

  testWidgets('every widget follows a theme switch from settings', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const A2AApp());
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
    await tester.pumpWidget(const A2AApp());
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

  testWidgets('home offers open files and the four file types', (tester) async {
    await tester.pumpWidget(const A2AApp());
    await tester.pumpAndSettle();

    expect(find.text('OPEN FILES'), findsOneWidget);
    for (final label in ['Photos', 'Videos', 'Music', 'PDF and docs']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('workspace lists image tools and blocks single-file ones', (
    tester,
  ) async {
    final files = [_file('a.jpg'), _file('b.png')];
    await tester.pumpWidget(MaterialApp(home: WorkspaceScreen(files: files)));
    await tester.pumpAndSettle();

    expect(find.text('EDIT'), findsOneWidget);
    expect(find.text('Rotate and flip'), findsOneWidget);
    expect(
      find.text('One photo at a time. Remove the others to use it.'),
      findsWidgets,
    );

    await tester.scrollUntilVisible(
      find.text('Photo details'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('PRIVACY'), findsOneWidget);
  });

  testWidgets('a tool opens from the workspace and goes back', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WorkspaceScreen(files: [_file('a.jpg')])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Compress to size'));
    await tester.pumpAndSettle();
    expect(find.text('KEEP EACH PHOTO UNDER'), findsOneWidget);
    expect(find.text('MAKE IT UNDER 100 KB'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Compress to size'), findsOneWidget);
  });

  testWidgets('the pencil renames the name saved copies use', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WorkspaceScreen(files: [_file('53459.jpg')])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Rename 53459.jpg'));
    await tester.pumpAndSettle();
    expect(find.text('RENAME'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bad/name');
    await tester.pump();
    expect(find.textContaining('Names cannot contain'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'holiday');
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('holiday.jpg'), findsOneWidget);

    // Tools open on the renamed file.
    await tester.tap(find.text('Compress to size'));
    await tester.pumpAndSettle();
    expect(find.text('holiday.jpg'), findsOneWidget);
  });

  testWidgets('bottom bar opens the file history', (tester) async {
    await tester.pumpWidget(const A2AApp());
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

FileItem _file(String name) => FileItem(
  path: '/in/$name',
  name: name,
  extension: name.split('.').last,
  sizeInBytes: 2000,
  category: FileItem.detectCategory(name.split('.').last),
  modifiedAt: DateTime(2026, 1, 1),
);
