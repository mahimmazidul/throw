import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for Throw — soothing blue-slate, dark first.
///
/// Raw hex values live here and nowhere else; widgets read colors from
/// [Theme.of] so light/dark switching stays in one place.
abstract final class ThrowColors {
  // Dark (default)
  static const Color bg = Color(0xFF14171F);
  static const Color surface = Color(0xFF1B1F29);
  static const Color surfaceHigh = Color(0xFF222632);
  static const Color border = Color(0xFF282D3A);
  static const Color text = Color(0xFFE4E8F0);
  static const Color secondary = Color(0xFF98A0B3);
  static const Color accent = Color(0xFF8B7CF7);
  static const Color onAccent = Color(0xFFFFFFFF);

  // Light
  static const Color lightBg = Color(0xFFF4F5F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFDDE1EA);
  static const Color lightText = Color(0xFF14171F);
  static const Color lightSecondary = Color(0xFF5A6377);
}

/// Material 3 themes for Throw.
///
/// Dark is the product default ([ThemeMode.dark] in the app); light exists
/// for the V3 theme toggle and for users who ask for it system-wide.
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

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ThrowColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: ThrowColors.accent,
      onPrimary: ThrowColors.onAccent,
      primaryContainer: const Color(0xFF37306B),
      onPrimaryContainer: const Color(0xFFE8E1FF),
      secondary: ThrowColors.secondary,
      onSecondary: ThrowColors.bg,
      surface: ThrowColors.bg,
      onSurface: ThrowColors.text,
      surfaceContainerLow: ThrowColors.surface,
      surfaceContainer: ThrowColors.surface,
      surfaceContainerHigh: ThrowColors.surfaceHigh,
      surfaceContainerHighest: ThrowColors.surfaceHigh,
      outline: ThrowColors.border,
      outlineVariant: ThrowColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: ThrowColors.bg,
      textTheme: GoogleFonts.hindSiliguriTextTheme(_typeScale()).apply(color: ThrowColors.text),
      dividerTheme: const DividerThemeData(color: ThrowColors.border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: ThrowColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: ThrowColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ThrowColors.accent,
          foregroundColor: ThrowColors.onAccent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ThrowColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ThrowColors.surface,
        elevation: 0,
        indicatorColor: ThrowColors.surfaceHigh,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? ThrowColors.accent : ThrowColors.secondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.hindSiliguri(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected) ? ThrowColors.accent : ThrowColors.secondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: ThrowColors.surface,
        elevation: 0,
        indicatorColor: ThrowColors.surfaceHigh,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? ThrowColors.accent : ThrowColors.secondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.hindSiliguri(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected) ? ThrowColors.accent : ThrowColors.secondary,
          ),
        ),
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
      surface: ThrowColors.lightSurface,
      onSurface: ThrowColors.lightText,
      surfaceContainerLow: ThrowColors.lightSurface,
      surfaceContainer: ThrowColors.lightSurface,
      surfaceContainerHigh: ThrowColors.lightBg,
      surfaceContainerHighest: ThrowColors.lightBg,
      outline: ThrowColors.lightBorder,
      outlineVariant: ThrowColors.lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: ThrowColors.lightBg,
      textTheme: GoogleFonts.hindSiliguriTextTheme(_typeScale()).apply(color: ThrowColors.lightText),
      dividerTheme: const DividerThemeData(color: ThrowColors.lightBorder, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: ThrowColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: ThrowColors.lightBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ThrowColors.accent,
          foregroundColor: ThrowColors.onAccent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.hindSiliguri(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ThrowColors.lightSurface,
        contentTextStyle: GoogleFonts.hindSiliguri(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ThrowColors.lightText,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ThrowColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }
}
