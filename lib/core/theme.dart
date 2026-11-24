import 'package:flutter/material.dart';

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
/// ramp is flat on purpose. That rule used to stop at this file: the home and
/// discover headers still carried a `LinearGradient` wash, the exact kind of
/// radiant effect this palette exists to avoid. They are flat now.
///
/// The accent ships in three cuts rather than one, because a single moss
/// cannot clear WCAG AA on both a near-black and a sage field:
///
///  * [accent] — the fill; white sits on it at ~4.8:1.
///  * [accentText] — lighter sage, for accent *text* on the dark canvas
///    (~7:1, against ~3.7:1 for [accent]).
///  * [lightAccent] — deeper moss, for accent text on sage paper
///    (~6.6:1, against ~4.2:1 for [accent]).
abstract final class ThrowColors {
  // Dark (default)
  static const Color bg = Color(0xFF161A17);
  static const Color surface = Color(0xFF1D211E);
  static const Color surfaceHigh = Color(0xFF252A26);
  static const Color border = Color(0xFF333A34);
  static const Color text = Color(0xFFDFE5DD);
  static const Color secondary = Color(0xFF96A095);
  static const Color accent = Color(0xFF5A7A55);
  static const Color onAccent = Color(0xFFF4F8F1);
  static const Color accentContainer = Color(0xFF2C3A2A);
  static const Color onAccentContainer = Color(0xFFDCE7D9);

  /// Accent as text on the dark canvas — lighter sage so it clears AA.
  static const Color accentText = Color(0xFF8FAA89);

  // Light — sage paper, never #FFFFFF
  static const Color lightBg = Color(0xFFEBF0E8);
  static const Color lightSurface = Color(0xFFF5F8F3);
  static const Color lightSurfaceHigh = Color(0xFFE2E9DF);
  static const Color lightBorder = Color(0xFFD2DAD0);
  static const Color lightText = Color(0xFF1E241D);
  static const Color lightSecondary = Color(0xFF5F6B5C);
  static const Color lightAccentContainer = Color(0xFFD7E3D3);
  static const Color lightOnAccentContainer = Color(0xFF2A3A28);

  /// Accent for light mode — deeper moss so it clears AA on sage paper.
  static const Color lightAccent = Color(0xFF3E5A3B);
}

/// One corner scale for the whole app.
///
/// These numbers used to be re-typed inline across the screens — 4, 10, 12,
/// 14, 16 and 20 within a few hundred lines — so neighbouring cards rounded
/// differently for no reason. Everything reads from here.
abstract final class ThrowRadius {
  /// Progress-bar tracks and other thin elements.
  static const BorderRadius track = BorderRadius.all(Radius.circular(4));

  /// Small inline chips and badges.
  static const BorderRadius chip = BorderRadius.all(Radius.circular(10));

  /// Buttons, text fields, small clipped images.
  static const BorderRadius button = BorderRadius.all(Radius.circular(12));

  /// Cards and section headers.
  static const BorderRadius card = BorderRadius.all(Radius.circular(14));

  /// Hero cards and bottom sheets.
  static const BorderRadius sheet = BorderRadius.all(Radius.circular(20));

  /// Bottom sheets are only rounded on their top edge.
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(20));
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
  /// Plus Jakarta Sans type scale — clean, modern, readable.
  static TextTheme _typeScale() => const TextTheme(
        displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w700, height: 1.1, fontFamilyFallback: ['HindSiliguri']),
        displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w700, height: 1.1, fontFamilyFallback: ['HindSiliguri']),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2, fontFamilyFallback: ['HindSiliguri']),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.25, fontFamilyFallback: ['HindSiliguri']),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3, fontFamilyFallback: ['HindSiliguri']),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4, fontFamilyFallback: ['HindSiliguri']),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, fontFamilyFallback: ['HindSiliguri']),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, fontFamilyFallback: ['HindSiliguri']),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4, fontFamilyFallback: ['HindSiliguri']),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3, fontFamilyFallback: ['HindSiliguri']),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, fontFamilyFallback: ['HindSiliguri']),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3, fontFamilyFallback: ['HindSiliguri']),
      );

  /// Corners are softened from the original 6/8dp: biophilic guidance is to
  /// replace rigid right angles with gentle radii, and a rounder silhouette
  /// reads as calmer at the same information density.
  static const BorderRadius _cardRadius = ThrowRadius.card;
  static const BorderRadius _buttonRadius = ThrowRadius.button;

  /// Accent colour for *foreground* use — icons and labels sitting on an
  /// accent tint.
  ///
  /// The fill accent (#5A7A55) lands at ~2.9–3.2:1 on its own 14–16% tint in
  /// dark mode, which fails AA for the small text and glyphs that sit on
  /// those tints. These brightness-aware cuts clear 4.5:1 in both.
  static Color accentFg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? ThrowColors.accentText
          : ThrowColors.lightAccent;

  /// Flat hover/focus washes for the desktop build — alpha only, no glow.
  static const Color _hoverWash = Color(0x145A7A55);
  static const Color _focusWash = Color(0x245A7A55);
  static const Color _lightHoverWash = Color(0x0F3E5A3B);
  static const Color _lightFocusWash = Color(0x1A3E5A3B);

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
      textTheme: _typeScale().apply(
        fontFamily: 'Plus Jakarta Sans',
        bodyColor: ThrowColors.text,
        displayColor: ThrowColors.text,
      ),
      dividerTheme: const DividerThemeData(color: ThrowColors.border, thickness: 1, space: 1),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ThrowColors.accent,
        selectionColor: Color(0x5A5A7A55),
        selectionHandleColor: ThrowColors.accentText,
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
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
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
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ThrowColors.accentText,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ThrowColors.surfaceHigh,
        contentTextStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
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
          borderRadius: ThrowRadius.sheetTop,
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
      primary: ThrowColors.lightAccent,
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
      textTheme: _typeScale().apply(
        fontFamily: 'Plus Jakarta Sans',
        bodyColor: ThrowColors.lightText,
        displayColor: ThrowColors.lightText,
      ),
      dividerTheme: const DividerThemeData(
        color: ThrowColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ThrowColors.lightAccent,
        selectionColor: Color(0x4D3E5A3B),
        selectionHandleColor: ThrowColors.lightAccent,
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
          backgroundColor: ThrowColors.lightAccent,
          foregroundColor: ThrowColors.onAccent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
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
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ThrowColors.lightAccent,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ThrowColors.lightSurfaceHigh,
        contentTextStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
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
          borderRadius: ThrowRadius.sheetTop,
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
