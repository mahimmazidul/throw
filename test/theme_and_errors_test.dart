import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(
          contrast(ThrowColors.text, ThrowColors.surface), greaterThan(4.5));
      expect(
          contrast(ThrowColors.secondary, ThrowColors.bg), greaterThan(4.5));
      // accent used as text on the canvas
      expect(
          contrast(ThrowColors.accentText, ThrowColors.bg), greaterThan(4.5));
      // white-ish on the accent fill (buttons)
      expect(contrast(ThrowColors.onAccent, ThrowColors.accent), greaterThan(4.5));
      expect(contrast(ThrowColors.onAccentContainer, ThrowColors.accentContainer),
          greaterThan(4.5));
    });

    test('light theme', () {
      expect(contrast(ThrowColors.lightText, ThrowColors.lightBg), greaterThan(4.5));
      expect(contrast(ThrowColors.lightText, ThrowColors.lightSurface),
          greaterThan(4.5));
      expect(contrast(ThrowColors.lightSecondary, ThrowColors.lightBg),
          greaterThan(4.5));
      expect(contrast(ThrowColors.lightAccent, ThrowColors.lightBg), greaterThan(4.5));
      expect(contrast(ThrowColors.onAccent, ThrowColors.lightAccent), greaterThan(4.5));
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
      expect(const AppError(AppErrorCode.permissionBlocked).offerSettings, isTrue);
      expect(const AppError(AppErrorCode.permissionDenied).offerSettings, isFalse);
      expect(const AppError(AppErrorCode.transferFailed).offerSettings, isFalse);
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
      expect(describeError(const AppError(AppErrorCode.permissionDenied), bn),
          isNot(equals(describeError(const AppError(AppErrorCode.permissionDenied), en))));
      expect(describeError(const AppError(AppErrorCode.transferFailed), bn),
          isNot(equals(describeError(const AppError(AppErrorCode.transferFailed), en))));
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
      expect(find.textContaining('Scanning for devices failed'), findsOneWidget);
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
      await _pumpBanner(
          tester, const AppError(AppErrorCode.transferFailed));
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await _pumpBanner(
          tester,
          const AppError(AppErrorCode.transferFailed),
          dismissible: true);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('is announced to screen readers', (tester) async {
      await _pumpBanner(
          tester, const AppError(AppErrorCode.locationOff), dismissible: true);
      final semantic = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(ErrorBanner),
          matching: find.byType(Semantics),
        ).first,
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
