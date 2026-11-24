import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:throw_app/core/temp_files.dart';
import 'package:throw_app/core/theme.dart';
import 'package:throw_app/l10n/app_localizations.dart';
import 'package:throw_app/widgets/storage_row.dart';

/// The Storage row is the user-visible proof that a failed transfer gave the
/// space back: it must report the truth and clear on demand.
///
/// The row touches the real filesystem, so every step that awaits I/O runs
/// inside [WidgetTester.runAsync] — `testWidgets` otherwise runs on a fake
/// clock where real file futures never complete.
void main() {
  late Directory tmp;
  late Directory cache;
  late Directory support;

  TempFileRegistry registry() => TempFileRegistry(
        cacheDir: () async => cache,
        supportDir: () async => support,
      );

  File cacheCopy(String name, {int bytes = 1536}) {
    final file = File('${cache.path}/share/$name');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List<int>.filled(bytes, 1));
    return file;
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('throw_storage_row');
    cache = Directory('${tmp.path}/cache')..createSync(recursive: true);
    support = Directory('${tmp.path}/support')..createSync(recursive: true);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Pumps the row and lets its real I/O settle.
  Future<void> pump(WidgetTester tester, TempFileRegistry reg) async {
    await tester.pumpWidget(
      Provider<TempFileRegistry>.value(
        value: reg,
        child: MaterialApp(
          theme: ThrowTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: StorageRow()),
        ),
      ),
    );
    // One runAsync lets the row's real I/O finish; the following pump paints
    // the frame that setState scheduled.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  testWidgets('with nothing held it says so and offers no action',
      (tester) async {
    await pump(tester, registry());

    expect(find.text('Nothing held'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('it reports the size held and clearing deletes the copies',
      (tester) async {
    final reg = registry();
    final copy = cacheCopy('pending.bin', bytes: 512 * 1024);
    await tester.runAsync(() => reg.takeOwnership(copy.path));

    await pump(tester, reg);

    expect(find.text('512 KB in temporary copies'), findsOneWidget,
        reason: 'the user can see exactly what is being held');
    expect(find.text('Clear'), findsOneWidget);

    // The tap is dispatched inside runAsync: `_clear` awaits real deletions,
    // and work started in the fake-async zone would stall on them forever.
    await tester.runAsync(() async {
      await tester.tap(find.text('Clear'));
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump();

    expect(copy.existsSync(), isFalse,
        reason: 'clearing must actually delete the copy');
    expect(find.text('Nothing held'), findsOneWidget);
    expect(find.text('Temporary copies deleted'), findsOneWidget,
        reason: 'the user is told it happened');
  });

  testWidgets('it re-reads the disk when the user comes back to the screen',
      (tester) async {
    // Settings lives in an IndexedStack, so the row is built once and kept
    // alive. A transfer that finishes while the user is on another tab must
    // still be reflected here.
    final reg = registry();
    final first = cacheCopy('before.bin', bytes: 1024);
    await tester.runAsync(() => reg.takeOwnership(first.path));

    await pump(tester, reg);
    expect(find.text('1.0 KB in temporary copies'), findsOneWidget);

    // User switches away (TickerMode off) and a transfer ends meanwhile.
    await tester.pumpWidget(
      TickerMode(
        enabled: false,
        child: Provider<TempFileRegistry>.value(
          value: reg,
          child: MaterialApp(
            theme: ThrowTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: StorageRow()),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final second = cacheCopy('during.bin', bytes: 2048);
      await reg.takeOwnership(second.path);
      await reg.releaseAll([first.path]);
    });

    // Back to Settings.
    await tester.pumpWidget(
      Provider<TempFileRegistry>.value(
        value: reg,
        child: MaterialApp(
          theme: ThrowTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: StorageRow()),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('2.0 KB in temporary copies'), findsOneWidget,
        reason: 'the row must not keep a number from before the switch');
  });

  testWidgets('after a failed transfer it reads Nothing held', (tester) async {
    final reg = registry();
    final copy = cacheCopy('failed.iso', bytes: 4096);
    await tester.runAsync(() async {
      await reg.takeOwnership(copy.path);
      // What the provider does the moment a send fails.
      await reg.releaseAll([copy.path]);
    });

    await pump(tester, reg);
    expect(find.text('Nothing held'), findsOneWidget,
        reason: 'the number must reflect the release, not the old copy');
  });
}
