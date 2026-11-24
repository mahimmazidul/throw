import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:throw_app/core/constants.dart';
import 'package:throw_app/core/theme.dart';
import 'package:throw_app/l10n/app_localizations.dart';
import 'package:throw_app/models/app_error.dart';
import 'package:throw_app/widgets/error_banner.dart';

// ── WCAG ──────────────────────────────────────────────────────────────────

double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  group('colour plate meets WCAG AA', () {
    test('dark theme', () {
      expect(contrast(ThrowColors.text, ThrowColors.bg), greaterThan(4.5));
      expect(contrast(ThrowColors.text, ThrowColors.surface), greaterThan(4.5));
      expect(contrast(ThrowColors.secondary, ThrowColors.bg), greaterThan(4.5));
      // accent used as text on the canvas
      expect(
          contrast(ThrowColors.accentText, ThrowColors.bg), greaterThan(4.5));
      // white-ish on the accent fill (buttons)
      expect(
          contrast(ThrowColors.onAccent, ThrowColors.accent), greaterThan(4.5));
      expect(
          contrast(ThrowColors.onAccentContainer, ThrowColors.accentContainer),
          greaterThan(4.5));
    });

    test('light theme', () {
      expect(contrast(ThrowColors.lightText, ThrowColors.lightBg),
          greaterThan(4.5));
      expect(contrast(ThrowColors.lightText, ThrowColors.lightSurface),
          greaterThan(4.5));
      expect(contrast(ThrowColors.lightSecondary, ThrowColors.lightBg),
          greaterThan(4.5));
      expect(contrast(ThrowColors.lightAccent, ThrowColors.lightBg),
          greaterThan(4.5));
      expect(contrast(ThrowColors.onAccent, ThrowColors.lightAccent),
          greaterThan(4.5));
      expect(
          contrast(ThrowColors.lightOnAccentContainer,
              ThrowColors.lightAccentContainer),
          greaterThan(4.5));
    });

    test('the accent clears AA as foreground on its own tint in both themes',
        () {
      for (final tinted in [
        (ThrowColors.accent, ThrowColors.accentText, ThrowColors.bg),
        (ThrowColors.lightAccent, ThrowColors.lightAccent, ThrowColors.lightBg),
      ]) {
        final base = tinted.$3;
        final mixed = Color.fromARGB(
          255,
          (255 * (0.16 * tinted.$1.r + 0.84 * base.r)).round(),
          (255 * (0.16 * tinted.$1.g + 0.84 * base.g)).round(),
          (255 * (0.16 * tinted.$1.b + 0.84 * base.b)).round(),
        );
        expect(contrast(tinted.$2, mixed), greaterThan(4.5),
            reason: 'accent-as-text on a 16% accent tint must stay legible');
      }
    });

    test('no pure black or pure white surfaces', () {
      expect(ThrowColors.bg, isNot(const Color(0xFF000000)));
      expect(ThrowColors.lightBg, isNot(const Color(0xFFFFFFFF)));
    });
  });

  group('shape scale — no rectangles', () {
    test('controls are pills', () {
      expect(ThrowRadius.button.bottomLeft.x, 999);
      expect(ThrowRadius.chip.bottomLeft.x, 999);
      expect(ThrowRadius.track.bottomLeft.x, 999);
    });

    test('panels are soft enough to never read as a rectangle', () {
      expect(ThrowRadius.card.bottomLeft.x, greaterThanOrEqualTo(24));
      expect(ThrowRadius.sheet.bottomLeft.x, greaterThanOrEqualTo(32));
      expect(ThrowRadius.sheetTop.topLeft.x, greaterThanOrEqualTo(32));
      // top corners must be square on a bottom sheet
      expect(ThrowRadius.sheetTop.topLeft.x, greaterThan(0));
      expect(ThrowRadius.sheetTop.bottomLeft.x, 0);
    });

    test('a rectangle would fail this suite', () {
      const sharp = BorderRadius.all(Radius.circular(1));
      expect(sharp.bottomLeft.x, lessThan(24));
    });
  });

  group('AppError classification', () {
    test('permission failures are recognised', () {
      expect(
        AppError.fromObject(Exception('PlatformException(MISSING_PERMISSION)'))
            .code,
        AppErrorCode.permissionDenied,
      );
      expect(
        AppError.fromObject(Exception('SecurityException: denied')).code,
        AppErrorCode.permissionDenied,
      );
    });

    test('bluetooth and location are recognised', () {
      expect(
        AppError.fromObject(Exception('Bluetooth is disabled')).code,
        AppErrorCode.bluetoothOff,
      );
      expect(
        AppError.fromObject(Exception('Location services are off')).code,
        AppErrorCode.locationOff,
      );
    });

    test('anything else falls through to unknown with the raw detail kept', () {
      final e = AppError.fromObject(Exception('weird stack overflow'));
      expect(e.code, AppErrorCode.unknown);
      expect(e.detail, contains('weird stack overflow'));
    });

    test('only a blocked permission offers system settings', () {
      expect(
          const AppError(AppErrorCode.permissionBlocked).offerSettings, isTrue);
      expect(
          const AppError(AppErrorCode.permissionDenied).offerSettings, isFalse);
      expect(
          const AppError(AppErrorCode.transferFailed).offerSettings, isFalse);
      expect(const AppError(AppErrorCode.bluetoothOff).offerSettings, isFalse);
    });

    test('recovery failures are marked severe', () {
      expect(const AppError(AppErrorCode.transferFailed).isSevere, isTrue);
      expect(const AppError(AppErrorCode.discoveryFailed).isSevere, isTrue);
      expect(const AppError(AppErrorCode.permissionDenied).isSevere, isFalse);
    });
  });

  group('localization', () {
    Future<AppLocalizations> load(Locale locale) =>
        AppLocalizations.delegate.load(locale);

    test('every error code has copy in English', () async {
      final l10n = await load(const Locale('en'));
      for (final code in AppErrorCode.values) {
        final msg = describeError(AppError(code, detail: 'raw'), l10n);
        expect(msg.trim(), isNotEmpty, reason: 'code ${code.name} has no copy');
        expect(msg, isNot(contains('null')), reason: 'code ${code.name}');
      }
    });

    test('Bangla translations are actually translated', () async {
      final en = await load(const Locale('en'));
      final bn = await load(const Locale('bn'));
      // if these ever collapse to English, the .arb wiring broke
      expect(
          describeError(const AppError(AppErrorCode.permissionDenied), bn),
          isNot(equals(describeError(
              const AppError(AppErrorCode.permissionDenied), en))));
      expect(
          describeError(const AppError(AppErrorCode.transferFailed), bn),
          isNot(equals(
              describeError(const AppError(AppErrorCode.transferFailed), en))));
    });
  });

  // ── The regression that shipped v1.0.15 ────────────────────────────────
  //
  // Every palette token was written as a 6-digit literal (`Color(0x0A1214)`),
  // which Dart reads as `0x00RRGGBB` — alpha zero. The whole dark theme was
  // transparent, and every contrast assertion above passed because luminance
  // maths ignores alpha. These tests exist to make that impossible again.

  group('palette opacity', () {
    const tokens = <String, Color>{
      'bg': ThrowColors.bg,
      'surface': ThrowColors.surface,
      'surfaceHigh': ThrowColors.surfaceHigh,
      'border': ThrowColors.border,
      'text': ThrowColors.text,
      'secondary': ThrowColors.secondary,
      'accent': ThrowColors.accent,
      'onAccent': ThrowColors.onAccent,
      'accentContainer': ThrowColors.accentContainer,
      'onAccentContainer': ThrowColors.onAccentContainer,
      'accentText': ThrowColors.accentText,
      'lightBg': ThrowColors.lightBg,
      'lightSurface': ThrowColors.lightSurface,
      'lightSurfaceHigh': ThrowColors.lightSurfaceHigh,
      'lightBorder': ThrowColors.lightBorder,
      'lightText': ThrowColors.lightText,
      'lightSecondary': ThrowColors.lightSecondary,
      'lightAccentContainer': ThrowColors.lightAccentContainer,
      'lightOnAccentContainer': ThrowColors.lightOnAccentContainer,
      'lightAccent': ThrowColors.lightAccent,
    };

    test('every base token is fully opaque', () {
      for (final entry in tokens.entries) {
        expect(
          (entry.value.a * 255).round(),
          255,
          reason: '${entry.key} must be 0xFF over its RGB value; '
              'it is #${entry.value.toARGB32().toRadixString(16).padLeft(8, '0')}',
        );
      }
    });

    test('accents in three cuts stay distinguishable', () {
      // fill, dark-canvas text, light-canvas text — cheap guard against the
      // three being collapsed back into one value.
      expect(ThrowColors.accent, isNot(ThrowColors.accentText));
      expect(ThrowColors.accent, isNot(ThrowColors.lightAccent));
      expect(ThrowColors.accentText, isNot(ThrowColors.lightAccent));
    });
  });

  group('Bangla coverage in component themes', () {
    // Plus Jakarta Sans has no Bengali glyphs. If a component theme names it
    // without the bundled HindSiliguri fallback, every button, tab, snackbar
    // and navigation label turns into tofu boxes in Bangla — on Windows and
    // Linux, which is most of this app's desktop surface.
    test('no text style names the Latin face without the Bangla fallback', () {
      final themes = [ThrowTheme.dark(), ThrowTheme.light()];
      final offenders = <String>[];

      for (final theme in themes) {
        final styles = <String, TextStyle?>{
          'filledButton': theme.filledButtonTheme.style?.textStyle?.resolve({}),
          'outlinedButton':
              theme.outlinedButtonTheme.style?.textStyle?.resolve({}),
          'textButton': theme.textButtonTheme.style?.textStyle?.resolve({}),
          'snackBar': theme.snackBarTheme.contentTextStyle,
          'tabLabel': theme.tabBarTheme.labelStyle,
          'tabUnselected': theme.tabBarTheme.unselectedLabelStyle,
          'headlineSmall': theme.textTheme.headlineSmall,
          'titleSmall': theme.textTheme.titleSmall,
          'displaySmall': theme.textTheme.displaySmall,
          'bodyMedium': theme.textTheme.bodyMedium,
        };
        styles.forEach((name, style) {
          if (style == null) return;
          if (style.fontFamily == 'Plus Jakarta Sans' &&
              !(style.fontFamilyFallback?.contains('HindSiliguri') ?? false)) {
            offenders.add('${theme.brightness.name}/$name');
          }
        });
      }
      expect(offenders, isEmpty,
          reason: 'styles missing the Bangla fallback: $offenders');
    });

    test('the full M3 scale is declared, so nothing falls back to Roboto', () {
      final t = ThrowTheme.dark().textTheme;
      for (final entry in {
        'displayLarge': t.displayLarge,
        'displayMedium': t.displayMedium,
        'displaySmall': t.displaySmall,
        'headlineLarge': t.headlineLarge,
        'headlineMedium': t.headlineMedium,
        'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
        'titleSmall': t.titleSmall,
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'bodySmall': t.bodySmall,
        'labelLarge': t.labelLarge,
        'labelMedium': t.labelMedium,
        'labelSmall': t.labelSmall,
      }.entries) {
        expect(entry.value?.fontFamily, 'Plus Jakarta Sans',
            reason: '${entry.key} fell back to the default typography');
      }
    });
  });

  group('version consistency', () {
    test('AppConstants.appVersion matches pubspec.yaml', () {
      // The constant is what the update checker compares against the latest
      // release tag; if it drifts from the built version, users are either
      // nagged forever or never told about a real update.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*([^+\s]+)', multiLine: true)
          .firstMatch(pubspec);
      expect(match, isNotNull);
      expect(AppConstants.appVersion, match!.group(1));
    });
  });

  group('theme is actually dark', () {
    test('dark() paints an opaque dark canvas with opaque light text', () {
      final theme = ThrowTheme.dark();
      final bg = theme.scaffoldBackgroundColor;
      final fg = theme.colorScheme.onSurface;
      expect((bg.a * 255).round(), 255,
          reason: 'scaffold must not be transparent');
      expect(_luminance(bg), lessThan(0.05), reason: 'dark canvas expected');
      expect(_luminance(fg), greaterThan(0.5), reason: 'light text expected');
      expect(contrast(fg, bg), greaterThan(4.5));
    });

    test('light() paints an opaque, non-white canvas', () {
      final theme = ThrowTheme.light();
      final bg = theme.scaffoldBackgroundColor;
      expect((bg.a * 255).round(), 255);
      expect(bg, isNot(const Color(0xFFFFFFFF)));
      expect(_luminance(bg), greaterThan(0.5));
      expect(contrast(theme.colorScheme.onSurface, bg), greaterThan(4.5));
    });

    test('cards are visibly separated from the canvas in both themes', () {
      for (final theme in [ThrowTheme.dark(), ThrowTheme.light()]) {
        final card = theme.cardTheme.color!;
        final bg = theme.scaffoldBackgroundColor;
        expect((card.a * 255).round(), 255);
        expect(card, isNot(bg),
            reason: 'a card that matches the canvas is invisible');
      }
    });
  });

  group('error copy never exposes a raw exception', () {
    // The running Linux build showed "Something went wrong: Bad state: No
    // element" to the user when the BLE radio could not start. Nobody should
    // read a Dart exception on a phone.
    test('an unknown error with a detail gets human copy', () {
      const error = AppError(
        AppErrorCode.unknown,
        detail: 'Bad state: No element',
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      final message = describeError(error, l10n);
      expect(message, isNot(contains('Bad state')));
      expect(message, isNot(contains('No element')));
      expect(message.trim(), isNotEmpty);
    });

    test('the detail is preserved on the object for logging', () {
      const error = AppError(
        AppErrorCode.unknown,
        detail: 'PlatformException(foo)',
      );
      expect(error.detail, 'PlatformException(foo)');
    });

    test('a fallback code is used when the message is unrecognisable', () {
      final error = AppError.fromObject(
        StateError('Bad state: No element'),
        fallback: AppErrorCode.discoveryFailed,
      );
      expect(error.code, AppErrorCode.discoveryFailed);
    });

    test('a recognisable message still wins over the fallback', () {
      final error = AppError.fromObject(
        Exception('Missing permission: BLUETOOTH_SCAN'),
        fallback: AppErrorCode.discoveryFailed,
      );
      expect(error.code, AppErrorCode.permissionDenied);
    });

    testWidgets('the banner hides the raw detail behind a disclosure',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThrowTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: ErrorBanner(
            error: AppError(
              AppErrorCode.unknown,
              detail: 'Bad state: No element',
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Not visible until asked for.
      expect(find.text('Bad state: No element'), findsNothing);
      expect(find.textContaining('Bad state'), findsNothing);

      await tester.tap(find.text('Show details'));
      await tester.pumpAndSettle();
      expect(find.text('Bad state: No element'), findsOneWidget);
    });
  });

  group('ErrorBanner', () {
    testWidgets('renders the message for the code', (tester) async {
      await _pumpBanner(
        tester,
        const AppError(AppErrorCode.discoveryFailed),
        dismissible: true,
      );
      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(
          find.textContaining('Scanning for devices failed'), findsOneWidget);
    });

    testWidgets('offers system settings only when the permission is blocked',
        (tester) async {
      await _pumpBanner(tester, const AppError(AppErrorCode.permissionBlocked));
      expect(find.text('Open system settings'), findsOneWidget);
    });

    testWidgets('does not offer settings for an ordinary failure',
        (tester) async {
      await _pumpBanner(tester, const AppError(AppErrorCode.transferFailed));
      expect(find.text('Open system settings'), findsNothing);
    });

    testWidgets('dismiss is optional and wired when supplied', (tester) async {
      await _pumpBanner(tester, const AppError(AppErrorCode.transferFailed));
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await _pumpBanner(tester, const AppError(AppErrorCode.transferFailed),
          dismissible: true);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('is announced to screen readers', (tester) async {
      await _pumpBanner(tester, const AppError(AppErrorCode.locationOff),
          dismissible: true);
      final semantic = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(ErrorBanner),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantic.properties.label, contains('Location'));
    });
  });
}

Future<void> _pumpBanner(
  WidgetTester tester,
  AppError error, {
  bool dismissible = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThrowTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: ThrowColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorBanner(
              error: error,
              onDismiss: dismissible ? () {} : null,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
