import 'package:flutter/material.dart';
import '../models/file_item.dart';

/// Colours for one brightness. Every text pairing meets WCAG AAA (7:1):
/// [ink] and [inkSoft] on [paper], [surface] and [muted]; [ink] on
/// [selection]; [onAccent] on [accent].
class Palette {
  final Brightness brightness;
  final Color paper;
  final Color surface;
  final Color muted;
  final Color ink;
  final Color inkSoft;
  final Color accent;
  final Color onAccent;
  final Color selection;
  final Color errorInk;
  final Color shadow;

  const Palette({
    required this.brightness,
    required this.paper,
    required this.surface,
    required this.muted,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.onAccent,
    required this.selection,
    required this.errorInk,
    required this.shadow,
  });

  static const light = Palette(
    brightness: Brightness.light,
    paper: Color(0xFFFDF7E6),
    surface: Color(0xFFFFFFFF),
    muted: Color(0xFFF1EAD6),
    ink: Color(0xFF111111),
    inkSoft: Color(0xFF3B3B3B),
    accent: Color(0xFFF7C534),
    onAccent: Color(0xFF111111),
    selection: Color(0xFFF7C534),
    errorInk: Color(0xFF9E1C00),
    shadow: Color(0xFF111111),
  );

  static const dark = Palette(
    brightness: Brightness.dark,
    paper: Color(0xFF151412),
    surface: Color(0xFF1F1D1A),
    muted: Color(0xFF2A2723),
    ink: Color(0xFFF3EEE2),
    inkSoft: Color(0xFFC9C3B5),
    accent: Color(0xFFF7C534),
    onAccent: Color(0xFF111111),
    selection: Color(0xFF4A3E14),
    errorInk: Color(0xFFFF9B85),
    shadow: Color(0xFF000000),
  );
}

/// Soft neo-brutalist design tokens taken from the app icon: paper, thin ink
/// outlines, rounded corners, one yellow accent, and a small hard shadow on
/// primary actions only.
///
/// Colour tokens read the active [palette], which [OmniConvertApp] sets from
/// the resolved theme. Screens call [watch] so they rebuild when it changes.
class AppTheme {
  static Palette palette = Palette.light;

  /// Registers a dependency on the theme so the caller rebuilds on a switch.
  static Palette watch(BuildContext context) {
    Theme.of(context);
    return palette;
  }

  static bool get isDark => palette.brightness == Brightness.dark;

  static Color get paper => palette.paper;
  static Color get surface => palette.surface;
  static Color get muted => palette.muted;
  static Color get ink => palette.ink;
  static Color get inkSoft => palette.inkSoft;
  static Color get accent => palette.accent;
  static Color get onAccent => palette.onAccent;
  static Color get selection => palette.selection;
  static Color get errorInk => palette.errorInk;

  /// Foreground for content placed on [background].
  static Color onColor(Color background) =>
      background == accent ? onAccent : ink;

  static const double stroke = 1.5;
  static const double strokeHeavy = 2;
  static const Offset shadowOffset = Offset(3, 3);
  static const BorderRadius radius = BorderRadius.all(Radius.circular(14));
  static const BorderRadius radiusSmall = BorderRadius.all(Radius.circular(10));
  static List<BoxShadow> get hardShadow => [
    BoxShadow(color: palette.shadow, offset: shadowOffset),
  ];

  static const String displayFont = 'ArchivoBlack';
  static const String bodyFont = 'SpaceGrotesk';

  static IconData categoryIcon(FileCategory category) {
    switch (category) {
      case FileCategory.image:
        return Icons.image_outlined;
      case FileCategory.video:
        return Icons.movie_outlined;
      case FileCategory.audio:
        return Icons.graphic_eq;
      case FileCategory.document:
        return Icons.description_outlined;
      case FileCategory.unknown:
        return Icons.insert_drive_file_outlined;
    }
  }

  static TextStyle get display =>
      TextStyle(fontFamily: displayFont, color: ink, fontSize: 24, height: 1.1);
  static TextStyle get title =>
      TextStyle(fontFamily: displayFont, color: ink, fontSize: 18, height: 1.1);
  static TextStyle get label => TextStyle(
    fontFamily: bodyFont,
    color: ink,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );
  static TextStyle get body => TextStyle(
    fontFamily: bodyFont,
    color: ink,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  static TextStyle get caption => TextStyle(
    fontFamily: bodyFont,
    color: inkSoft,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static ThemeData get lightTheme => _build(Palette.light);
  static ThemeData get darkTheme => _build(Palette.dark);

  static ThemeData _build(Palette p) {
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: p.ink, width: stroke),
    );
    final bodyStyle = TextStyle(
      fontFamily: bodyFont,
      color: p.ink,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      fontFamily: bodyFont,
      scaffoldBackgroundColor: p.paper,
      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: p.ink,
        onPrimary: p.paper,
        secondary: p.accent,
        onSecondary: p.onAccent,
        surface: p.surface,
        onSurface: p.ink,
        error: p.errorInk,
        onError: p.paper,
        outline: p.ink,
      ),
      textTheme: TextTheme(bodyLarge: bodyStyle, bodyMedium: bodyStyle),
      iconTheme: IconThemeData(color: p.ink),
      // Predictive back on Android: the page shrinks and follows the gesture.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(color: p.ink, thickness: 1, space: 1),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: p.ink,
        inactiveTrackColor: p.muted,
        thumbColor: p.accent,
        overlayColor: p.ink.withAlpha(0x22),
        trackShape: const RoundedRectSliderTrackShape(),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 12,
          elevation: 0,
          pressedElevation: 0,
        ),
        showValueIndicator: ShowValueIndicator.never,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : p.ink,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.muted,
        ),
        trackOutlineColor: WidgetStatePropertyAll(p.ink),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: TextStyle(
          fontFamily: bodyFont,
          color: p.paper,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        // The snackbar is ink coloured, so its action needs the opposite tone.
        actionTextColor: p.brightness == Brightness.light
            ? p.accent
            : const Color(0xFF5C4300),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.paper,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: p.ink, width: strokeHeavy),
        ),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.paper,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: p.ink, width: strokeHeavy),
        ),
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: p.ink,
      ),
      popupMenuTheme: PopupMenuThemeData(color: p.paper),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: p.ink, width: strokeHeavy),
        ),
        hintStyle: TextStyle(fontFamily: bodyFont, color: p.inkSoft),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.ink,
        selectionColor: p.accent.withAlpha(0x88),
        selectionHandleColor: p.ink,
      ),
    );
  }
}
