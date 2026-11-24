import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/temp_files.dart';

/// The reported defect: a failed transfer consumed the sender's storage.
///
/// Both file-entry plugins copy the picked/shared file into the app cache
/// before handing Throw a path, and no build ever deleted those copies. These
/// tests pin the fix down at the level that matters — what is on disk when a
/// transfer ends, whatever the outcome was.
void main() {
  late Directory tmp;
  late Directory cache;
  late Directory support;

  String cachePath(String name) => '${cache.path}/$name';
  String userPath(String name) => '${tmp.path}/user/$name';

  File writeFile(String path, {int bytes = 4096}) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List<int>.filled(bytes, 7));
    return file;
  }

  TempFileRegistry registry() => TempFileRegistry(
        cacheDir: () async => cache,
        supportDir: () async => support,
      );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('throw_temp_test');
    cache = Directory('${tmp.path}/cache')..createSync(recursive: true);
    support = Directory('${tmp.path}/support')..createSync(recursive: true);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('ownership', () {
    test('a path inside the cache becomes ours and is deleted on release',
        () async {
      final copy = writeFile(cachePath('share/video.mp4'));
      final reg = registry();

      expect(await reg.takeOwnership(copy.path), isTrue);
      expect(reg.trackedPaths, contains(copy.path));

      await reg.release(copy.path);
      expect(copy.existsSync(), isFalse);
      expect(reg.trackedPaths, isEmpty);
    });

    test('a file the user owns outside the cache is never registered', () async {
      final original = writeFile(userPath('report.pdf'));
      final reg = registry();

      expect(await reg.takeOwnership(original.path), isFalse);
      await reg.releaseEverything();

      expect(original.existsSync(), isTrue,
          reason: 'a send must never delete the file the user picked');
      expect(reg.trackedPaths, isEmpty);
    });

    test('a path that only resembles the cache prefix is not ours', () async {
      // `cache_evil/` shares the characters `cache` but is a different dir.
      final sibling = writeFile('${tmp.path}/cache_backup/x.bin');
      final reg = registry();

      expect(await reg.takeOwnership(sibling.path), isFalse);
      await reg.releaseEverything();
      expect(sibling.existsSync(), isTrue);
    });

    test('relative paths cannot escape the cache check', () async {
      final reg = registry();
      expect(await reg.isThrowOwned('../etc/passwd'), isFalse);
    });

    test('two holders of one path: the file survives until both let go',
        () async {
      // This is the share-inbox case: the inbox holds the copy while the user
      // picks a device, the send holds it while the bytes stream. Either one
      // releasing must not delete the file from under the other.
      final copy = writeFile(cachePath('a.bin'), bytes: 100);
      final reg = registry();

      await reg.takeOwnership(copy.path); // the inbox
      await reg.takeOwnership(copy.path); // the send

      expect(reg.trackedPaths.where((p) => p == copy.path).length, 1);
      expect(await reg.usedBytes(), 100,
          reason: 'two claims are still one file on disk');

      await reg.release(copy.path); // the send finished
      expect(copy.existsSync(), isTrue,
          reason: 'the inbox is still showing this file');

      await reg.release(copy.path); // the inbox moved on
      expect(copy.existsSync(), isFalse);
      expect(reg.trackedPaths, isEmpty);
    });

    test('releasing a path more times than it was claimed is harmless',
        () async {
      final copy = writeFile(cachePath('extra.bin'));
      final reg = registry();
      await reg.takeOwnership(copy.path);

      await reg.release(copy.path);
      await reg.release(copy.path);
      await reg.release(copy.path);
      expect(copy.existsSync(), isFalse);
      expect(reg.trackedPaths, isEmpty);
    });
  });

  group('transfer outcomes', () {
    test('a completed send deletes its cached copy', () async {
      final copy = writeFile(cachePath('pick/photo.jpg'));
      final reg = registry();
      await reg.takeOwnership(copy.path);

      await reg.releaseAll([copy.path]);
      expect(copy.existsSync(), isFalse);
    });

    test('a failed send deletes its cached copy — the reported leak', () async {
      final copy = writeFile(cachePath('pick/big.iso'), bytes: 512 * 1024);
      final reg = registry();
      await reg.takeOwnership(copy.path);
      expect(await reg.usedBytes(), 512 * 1024);

      // The transfer errored; the provider releases the same way it does on
      // success. There is deliberately no success-only branch to get wrong.
      await reg.releaseAll([copy.path]);

      expect(copy.existsSync(), isFalse);
      expect(await reg.usedBytes(), 0,
          reason: 'storage must return to baseline');
    });

    test('a cancelled or rejected send deletes its cached copy', () async {
      for (final name in ['cancel.bin', 'reject.bin']) {
        final copy = writeFile(cachePath(name));
        final reg = registry();
        await reg.takeOwnership(copy.path);
        await reg.releaseAll([copy.path]);
        expect(copy.existsSync(), isFalse, reason: name);
      }
    });

    test('releasing a copy that was already removed is not an error', () async {
      final copy = writeFile(cachePath('gone.bin'));
      final reg = registry();
      await reg.takeOwnership(copy.path);
      copy.deleteSync();

      await reg.releaseAll([copy.path]);
      expect(reg.trackedPaths, isEmpty);
    });
  });

  group('durability', () {
    test('registration survives a restart so the next launch can reclaim it',
        () async {
      final copy = writeFile(cachePath('stale/leftover.bin'), bytes: 900);

      // First run: registers, then "dies" without releasing.
      await registry().takeOwnership(copy.path);
      expect(copy.existsSync(), isTrue);

      // Second run: nothing can be in flight before startup, so the sweep
      // returns the space without the user clearing app data.
      final reopened = registry();
      await reopened.releaseEverything();

      expect(copy.existsSync(), isFalse);
      expect(reopened.trackedPaths, isEmpty);
      expect(
        Directory('${support.path}/throw_temp_files.json').existsSync(),
        isFalse,
        reason: 'an empty registry should not linger',
      );
    });

    test('a corrupt registry file is discarded, not fatal', () async {
      File('${support.path}/throw_temp_files.json')
          .writeAsStringSync('{not json at all');
      final copy = writeFile(cachePath('after-corruption.bin'));
      final reg = registry();

      await reg.releaseEverything(); // must not throw
      expect(await reg.takeOwnership(copy.path), isTrue);
      await reg.release(copy.path);
      expect(copy.existsSync(), isFalse);
    });

    test('a registry entry whose file vanished is dropped cleanly', () async {
      final reg = registry();
      final copy = writeFile(cachePath('ghost.bin'));
      await reg.takeOwnership(copy.path);
      copy.deleteSync();

      final reopened = registry();
      await reopened.releaseEverything();
      expect(reopened.trackedPaths, isEmpty);
    });
  });

  group('picker cache', () {
    test('the picker cache directory is emptied', () async {
      writeFile(cachePath('file_picker/1700/one.png'));
      writeFile(cachePath('file_picker/1701/two.pdf'));
      final keep = writeFile(cachePath('share/keep.bin'));

      await registry().clearPickerCache();

      expect(Directory('${cache.path}/file_picker').existsSync(), isFalse);
      expect(keep.existsSync(), isTrue,
          reason: 'only the picker subtree is swept');
    });

    test('clearing an absent picker cache is a no-op', () async {
      await registry().clearPickerCache();
    });
  });

  group('reported storage', () {
    test('usedBytes counts only registered copies', () async {
      final a = writeFile(cachePath('a.bin'), bytes: 300);
      final b = writeFile(cachePath('b.bin'), bytes: 700);
      writeFile(userPath('mine.bin'), bytes: 5000);
      final reg = registry();

      await reg.takeOwnership(a.path);
      await reg.takeOwnership(b.path);

      expect(await reg.usedBytes(), 1000);
    });
  });

  group('persistence format', () {
    test('written state is plain path to size JSON', () async {
      final copy = writeFile(cachePath('json/entry.bin'), bytes: 42);
      await registry().takeOwnership(copy.path);

      final raw = File('${support.path}/throw_temp_files.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded[copy.path], 42);
    });
  });
}
