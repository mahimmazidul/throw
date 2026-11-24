import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guards over the l10n layer.
///
/// The audit found seven English strings hardcoded in widgets — the Discover
/// scan hint, the Home tagline, a tooltip, and the Settings subtitle among
/// them — plus one screen wired to the wrong key. Translation coverage tests
/// cannot see either problem because the strings never reach the ARB files.
void main() {
  group('ARB files', () {
    late Map<String, dynamic> en;
    late Map<String, dynamic> bn;

    setUpAll(() {
      en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
      bn = jsonDecode(File('lib/l10n/app_bn.arb').readAsStringSync())
          as Map<String, dynamic>;
    });

    List<String> keys(Map<String, dynamic> arb) =>
        arb.keys.where((k) => !k.startsWith('@')).toList();

    test('English and Bangla have exactly the same keys', () {
      expect(keys(bn).toSet(), keys(en).toSet());
    });

    test('no value is empty and Bangla is not a copy of English', () {
      for (final key in keys(en)) {
        expect((en[key] as String).trim(), isNotEmpty, reason: key);
        expect((bn[key] as String).trim(), isNotEmpty, reason: key);
      }
      // A handful of values are legitimately identical (product names), so
      // assert a healthy majority differ rather than every single one.
      final differing = keys(en).where((k) => en[k] != bn[k]).length;
      expect(
        differing / keys(en).length,
        greaterThan(0.9),
        reason: 'Bangla file looks untranslated',
      );
    });

    test(
        'placeholders referenced in values exist in metadata or the twin '
        'file', () {
      final placeholder = RegExp(r'\{(\w+)\}');
      for (final key in keys(en)) {
        final inEn = placeholder.allMatches(en[key] as String).map((m) => m[1]);
        final inBn = placeholder.allMatches(bn[key] as String).map((m) => m[1]);
        expect(inBn.toSet(), inEn.toSet(),
            reason: '$key uses different placeholders across locales');
      }
    });
  });

  group('widgets use the localization layer', () {
    // Screens and widgets whose user-visible copy must come from l10n.
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('/l10n/'))
        .toList();

    /// A `Text('...')` or `tooltip: '...'` with a literal that contains a space
    /// or starts with a capital letter — i.e. prose, not a constant.
    final literalCopy = RegExp(
      r"""(?:Text|tooltip:|label:|hintText:|title:|subtitle:)\s*\(?\s*'([A-Za-z][^']{3,})'""",
    );

    test('no screen or widget hardcodes display copy', () {
      final offenders = <String>[];
      for (final file in files) {
        final source = file.readAsStringSync();
        for (final match in literalCopy.allMatches(source)) {
          final text = match.group(1)!;
          // Whitelist: brand name and technical strings that are not copy.
          if (text == 'Throw-App' || text == 'Plus Jakarta Sans') continue;
          offenders.add('${file.path}: "$text"');
        }
      }
      expect(offenders, isEmpty,
          reason: 'user-visible copy must come from AppLocalizations:\n'
              '${offenders.join('\n')}');
    });

    test('every screen imports the localization layer', () {
      for (final file in files.where((f) => f.path.contains('/screens/'))) {
        expect(
          file.readAsStringSync(),
          contains('app_localizations.dart'),
          reason: '${file.path} renders copy but never reads l10n',
        );
      }
    });
  });
}
