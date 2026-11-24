import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for Throw — quiet moss and stone, dark first.
///
/// Raw hex values live here and nowhere else; widgets read colors from
/// [Theme.of] so light/dark switching stays in one place.
///
/// The palette is deliberately narrow and desaturated. Grounding research:
///
///  * *Research on visual comfort of color matching in space station
///    experiment module*, Scientific Reports 15:9553 (2025) — pairing
///    **2–3 colors** produced the highest visual comfort while five colors
///    scored significantly worse (F = 16.044, p = 0.001), and the scheme with
///    the lowest visual-fatigue index was **low-saturation, high-brightness
///    blue + green + white**.
///  * *Light green background enhances reading performance in VDT tasks*,
///    Frontiers in Psychology (2025) — a light green field (RGB 207,232,204)
///    increased pupil diameter (a marker of lower fatigue), reduced negative
///    emotion and improved reading versus white, which participants reported
///    as causing glare and eye fatigue. So the light background here is a
///    sage paper, never pure white.
///  * *The effect of ambient illumination and text color on visual fatigue*,
///    PMC11175232 (2024) — red text produced the highest visual fatigue;
///    blue and green the lowest. There is no red anywhere in this file.
///  * Biophilic palette guidance: tonal variation within one natural family
///    (moss, olive, chalky sage) plus warm neutrals (stone, sand) rather than
///    a single obvious green or a bright accent.
///
/// Nothing here uses a gradient, a glow, or a tinted elevation — the surface
/// ramp is flat on purpose.
abstract final class ThrowColors {
  // Dark (default)
  static const Color bg = Color(0xFF161A17);
  static const Color surface = Color(0xFF1D211E);
  static const Color surfaceHigh = Color(0xFF252A26);
  static const Color border = Color(0xFF333A34);
  static const Color text = Color(0xFFDFE5DD);
  static const Color secondary = Color(0xFF96A095);
  static const Color accent = Color(0xFF5A7A55);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color accentContainer = Color(0xFF2C3A2A);
  static const Color onAccentContainer = Color(0xFFDCE7D9);

  // Light — sage paper, never #FFFFFF
  static const Color lightBg = Color(0xFFEBF0E8);
  static const Color lightSurface = Color(0xFFF5F8F3);
  static const Color lightSurfaceHigh = Color(0xFFE2E9DF);
  static const Color lightBorder = Color(0xFFD2DAD0);
  static const Color lightText = Color(0xFF1E241D);
  static const Color lightSecondary = Color(0xFF5F6B5C);
  static const Color lightAccentContainer = Color(0xFFD7E3D3);
  static const Color lightOnAccentContainer = Color(0xFF2A3A28);
}

/// Material 3 themes for Throw.
///
/// Dark is the product default ([ThemeMode.dark] in the app); light exists
/// for the theme toggle and for users who ask for it system-wide.
///
/// Both branches expose the same set of component themes — an earlier version
/// omitted the text button, navigation bar and navigation rail themes from
/// [light], so light mode silently fell back to stock Material shapes.
abstract final class ThrowTheme {
  /// Hind Siliguri type scale — weights carry hierarchy, sizes follow M3.
  static TextTheme _typeScale() => const TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w700, height: 1.1),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w700, height: 1.1),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.25),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3),
      );

  /// Corners are softened from the original 6/8dp: biophilic guidance is to
  /// replace rigid right angles with gentle radii, and a rounder silhouette
  /// reads as calmer at the same information density.
  static const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(14));
  static const BorderRadius _buttonRadius = BorderRadius.all(Radius.circular(12));

  /// Flat hover/focus washes for the desktop build — alpha only, no glow.
  static const Color _hoverWash = Color(0x145A7A55);
  static const Color _focusWash = Color(0x245A7A55);
  static const Color _lightHoverWash = Color(0x0F5A7A55);
  static const Color _lightFocusWash = Color(0x1A5A7A55);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ThrowColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: ThrowColors.accent,
      onPrimary: ThrowColors.onAccent,
      primaryContainer: ThrowColors.accentContainer,
      onPrimaryContainer: ThrowColors.onAccentContainer,
      secondary: ThrowColors.secondary,
      onSecondary: ThrowColors.bg,
      secondaryContainer: ThrowColors.surfaceHigh,
      onSecondaryContainer: ThrowColors.text,
      surface: ThrowColors.bg,
      onSurface: ThrowColors.text,
      surfaceContainerLow: ThrowColors.surface,
      surfaceContainer: ThrowColors.surface,
      surfaceContainerHigh: ThrowColors.surfaceHigh,
      surfaceContainerHighest: ThrowColors.surfaceHigh,
      outline: ThrowColors.border,
      outlineVariant: ThrowColors.border,
      error: const Color(0xFFB87A6E),
      onError: ThrowColors.onAccent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: ThrowColors.bg,
      hoverColor: _hoverWash,
      focusColor: _focusWash,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      textTheme: GoogleFonts.hindSiliguriTextTheme(_typeScale()).apply(
        bodyColor: ThrowColors.text,
        displayColor: ThrowColors.text,
      ),
      dividerTheme: const DividerThemeData(color: ThrowColors.border, thickness: 1, space: 1),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ThrowColors.accent,
        selectionColor: Color(0x5A5A7A55),
        selectionHandleColor: ThrowColors.accent,
      ),
      cardTheme: const CardThemeData(
        color: ThrowColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: _cardRadius,
          side: BorderSide(color: ThrowColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ThrowColors.accent,
          foregroundColor: ThrowColors.onAccent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: GoogleFonts.hindSiliguri(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ThrowColors.text,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: const BorderSide(color: ThrowColors.border),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: GoogleFonts.hindSiliguri(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ThrowColors.accent,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: GoogleFonts.hindSiliguri(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ThrowColors.surfaceHigh,
        contentTextStyle: GoogleFonts.hindSiliguri(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ThrowColors.text,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: _cardRadius),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ThrowColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: ThrowColors.surface,
        elevation: 0,
        indicatorColor: ThrowColors.surfaceHigh,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: ThrowColors.secondary, size: 22),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: ThrowColors.surface,
        elevation: 0,
        indicatorColor: ThrowColors.surfaceHigh,
        // NavigationRailThemeData has no iconTheme in Flutter 3.50; the rail
        // picks its icon color up from ThemeData.iconTheme instead.
        labelType: NavigationRailLabelType.all,
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ThrowColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: ThrowColors.accent,
      onPrimary: ThrowColors.onAccent,
      primaryContainer: ThrowColors.lightAccentContainer,
      onPrimaryContainer: ThrowColors.lightOnAccentContainer,
      secondary: ThrowColors.lightSecondary,
      onSecondary: ThrowColors.lightSurface,
      secondaryContainer: ThrowColors.lightSurfaceHigh,
      onSecondaryContainer: ThrowColors.lightText,
      surface: ThrowColors.lightSurface,
      onSurface: ThrowColors.lightText,
      surfaceContainerLow: ThrowColors.lightSurface,
      surfaceContainer: ThrowColors.lightSurface,
      surfaceContainerHigh: ThrowColors.lightSurfaceHigh,
      surfaceContainerHighest: ThrowColors.lightSurfaceHigh,
      outline: ThrowColors.lightBorder,
      outlineVariant: ThrowColors.lightBorder,
      error: const Color(0xFF9C5A4E),
      onError: ThrowColors.onAccent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: ThrowColors.lightBg,
      hoverColor: _lightHoverWash,
      focusColor: _lightFocusWash,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      textTheme: GoogleFonts.hindSiliguriTextTheme(_typeScale()).apply(
        bodyColor: ThrowColors.lightText,
        displayColor: ThrowColors.lightText,
      ),
      dividerTheme: const DividerThemeData(
        color: ThrowColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ThrowColors.accent,
        selectionColor: Color(0x4D5A7A55),
        selectionHandleColor: ThrowColors.accent,
      ),
      cardTheme: const CardThemeData(
        color: ThrowColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: _cardRadius,
          side: BorderSide(color: ThrowColors.lightBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ThrowColors.accent,
          foregroundColor: ThrowColors.onAccent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: GoogleFonts.hindSiliguri(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ThrowColors.lightText,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: const BorderSide(color: ThrowColors.lightBorder),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: GoogleFonts.hindSiliguri(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ThrowColors.accent,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: GoogleFonts.hindSiliguri(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ThrowColors.lightSurfaceHigh,
        contentTextStyle: GoogleFonts.hindSiliguri(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ThrowColors.lightText,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: _cardRadius),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ThrowColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: ThrowColors.lightSurface,
        elevation: 0,
        indicatorColor: ThrowColors.lightSurfaceHigh,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: ThrowColors.lightSecondary, size: 22),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: ThrowColors.lightSurface,
        elevation: 0,
        indicatorColor: ThrowColors.lightSurfaceHigh,
        labelType: NavigationRailLabelType.all,
      ),
    );
  }
}
