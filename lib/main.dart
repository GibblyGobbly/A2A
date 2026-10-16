import 'dart:developer' as developer;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/history_service.dart';
import 'services/native_events.dart';
import 'services/settings_service.dart';
import 'services/share_intake_service.dart';
import 'theme/app_theme.dart';
import 'views/home_screen.dart';
import 'views/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerNativeLicenses();
  await SettingsService.init();
  await HistoryService.init();
  NativeEvents.init();
  await ShareIntakeService.init();

  // Picked files are copied into the cache by the picker; drop copies from earlier sessions.
  FilePicker.clearTemporaryFiles().catchError((Object e) {
    developer.log('Could not clear picker cache: $e', name: 'main');
  });

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const OmniConvertApp());
}

/// Flutter lists Dart package licenses automatically. The native encoder and
/// the bundled fonts are added here so the license page is complete.
void _registerNativeLicenses() {
  LicenseRegistry.addLicense(() async* {
    const entries = {
      'SVT-AV1': 'assets/licenses/SVT-AV1-LICENSE.txt',
      'SVT-AV1 patent license': 'assets/licenses/SVT-AV1-PATENTS.txt',
      'FFmpeg (AV1 encoder build)': 'assets/licenses/FFmpeg-LICENSE.txt',
      'Archivo Black': 'assets/licenses/OFL-ArchivoBlack.txt',
      'Space Grotesk': 'assets/licenses/OFL-SpaceGrotesk.txt',
    };
    for (final entry in entries.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString(entry.value));
    }
  });
}

/// Rebuilds every widget below [context]. Colour tokens are read from
/// [AppTheme.palette], so widgets that do not depend on [Theme] (including
/// const ones and other routes) would otherwise keep the old colours.
void _rebuildEverything(BuildContext context) {
  void mark(Element element) {
    element.markNeedsBuild();
    element.visitChildren(mark);
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) (context as Element).visitChildren(mark);
  });
}

class OmniConvertApp extends StatelessWidget {
  const OmniConvertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: SettingsService.notifier,
      builder: (context, settings, _) => MaterialApp(
        title: 'A2A',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: settings.themeMode,
        // Our colour tokens switch at once, so Material's own colours must too;
        // a cross-fade would leave the two out of step for 200 ms.
        themeAnimationDuration: Duration.zero,
        builder: (context, child) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          final palette = dark ? Palette.dark : Palette.light;
          if (!identical(AppTheme.palette, palette)) {
            AppTheme.palette = palette;
            _rebuildEverything(context);
          }
          final iconBrightness = dark ? Brightness.light : Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: iconBrightness,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: iconBrightness,
              systemNavigationBarContrastEnforced: false,
            ),
            child: child!,
          );
        },
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: SettingsService.termsAccepted
              ? const HomeScreen()
              : const WelcomeScreen(),
        ),
      ),
    );
  }
}
