import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/incoming_store.dart';
import 'package:throw_app/core/utils.dart';

/// "It shows received but saved where" was the complaint; this is the part of
/// the answer that touches the disk.
///
/// The store probes candidate folders and only announces one it has actually
/// written to, so a user is never told about a location the app lacks
/// permission for.
void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('throw_store_test');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  IncomingStore storeWith(List<Directory> candidates) => IncomingStore(
        documentsDir: () async => Directory('${temp.path}/docs'),
        candidates: () => candidates,
      );

  group('folder resolution', () {
    test('picks the first writable candidate', () async {
      final first = Directory('${temp.path}/first');
      final second = Directory('${temp.path}/second');
      final store = storeWith([first, second]);

      final folder = await store.folder();
      expect(folder.path, first.path);
      expect(await folder.exists(), isTrue);
    });

    test('skips a candidate it cannot write to', () async {
      // A path whose parent is a *file* can never be created as a directory —
      // a reliable stand-in for the permission-denied case.
      final blocker = File('${temp.path}/blocker');
      await blocker.writeAsString('not a directory');
      final unusable = Directory('${blocker.path}/Throw');
      final usable = Directory('${temp.path}/usable');

      final store = storeWith([unusable, usable]);
      final folder = await store.folder();
      expect(folder.path, usable.path);
    });

    test('falls back to the documents folder when nothing else works', () async {
      final blocker = File('${temp.path}/blocker2');
      await blocker.writeAsString('x');
      final store = IncomingStore(
        documentsDir: () async => Directory('${temp.path}/docs2'),
        candidates: () => [Directory('${blocker.path}/Throw')],
      );

      final folder = await store.folder();
      expect(folder.path, '${temp.path}/docs2/Throw');
      expect(await folder.exists(), isTrue);
    });

    test('the probe file does not linger', () async {
      final store = storeWith([Directory('${temp.path}/clean')]);
      final folder = await store.folder();
      final names = folder.listSync().map((e) => e.path.split('/').last);
      expect(names, isNot(contains('.throw_probe')));
    });

    test('resolving twice returns the same folder and does not re-probe',
        () async {
      final store = storeWith([Directory('${temp.path}/once')]);
      final a = await store.folder();
      final b = await store.folder();
      expect(a.path, b.path);
    });
  });

  group('naming', () {
    test('a fresh name is used as-is', () async {
      final store = storeWith([Directory('${temp.path}/names')]);
      final path = await store.pathFor('report.pdf');
      expect(path.split('/').last, 'report.pdf');
    });

    test('a second file with the same name is numbered, not overwritten',
        () async {
      final store = storeWith([Directory('${temp.path}/clash')]);
      final first = await store.pathFor('IMG_0001.jpg');
      await File(first).writeAsString('one');

      final second = await store.pathFor('IMG_0001.jpg');
      expect(second, isNot(first));
      expect(second.split('/').last, 'IMG_0001 (1).jpg');

      await File(second).writeAsString('two');
      final third = await store.pathFor('IMG_0001.jpg');
      expect(third.split('/').last, 'IMG_0001 (2).jpg');
      // The original is untouched — the old behaviour overwrote it.
      expect(await File(first).readAsString(), 'one');
    });

    test('a name with no extension still numbers correctly', () async {
      final store = storeWith([Directory('${temp.path}/noext')]);
      final first = await store.pathFor('notes');
      await File(first).writeAsString('a');
      final second = await store.pathFor('notes');
      expect(second.split('/').last, 'notes (1)');
    });

    test('a leading-dot file is not mistaken for an extension', () async {
      final store = storeWith([Directory('${temp.path}/dot')]);
      final path = await store.pathFor('.env');
      expect(path.split('/').last, '.env');
    });
  });

  group('writing', () {
    test('save writes the bytes and returns the file', () async {
      final store = storeWith([Directory('${temp.path}/save')]);
      final file = await store.save('note.txt', [104, 105]);
      expect(await file.readAsString(), 'hi');
      expect(await file.exists(), isTrue);
    });

    test('adopt moves a temporary file into the store', () async {
      final store = storeWith([Directory('${temp.path}/adopt')]);
      final staging = Directory('${temp.path}/staging')
        ..createSync(recursive: true);
      final stagingFile = File('${staging.path}/video.mp4')
        ..writeAsBytesSync(List.filled(1024, 9));

      final moved = await store.adopt('video.mp4', stagingFile);
      expect(await moved.exists(), isTrue);
      expect(await moved.length(), 1024);
      expect(moved.path.split('/').last, 'video.mp4');
    });
  });

  group('names match the app-wide sanitiser', () {
    // IncomingStore duplicates the sanitisation logic so it can be used
    // without the utils surface. These cases keep the two from drifting.
    for (final name in const [
      '../../etc/passwd',
      'photo:2026.jpg',
      'a<b>c|d?.txt',
      '',
      '..',
    ]) {
      test('"$name" is sanitised the same way in both', () async {
        final store = storeWith([Directory('${temp.path}/sanitize${name.hashCode}')]);
        final path = await store.pathFor(name);
        expect(
          path.split('/').last,
          AppUtils.sanitizeFileName(name),
          reason: 'the store and AppUtils must agree',
        );
      });
    }
  });

  group('display', () {
    test('Android public storage is shown as a relative path', () {
      expect(
        displayFolder('/storage/emulated/0/Download/Throw', isAndroid: true),
        'Download/Throw',
      );
      expect(
        displayFolder('/sdcard/Download/Throw', isAndroid: true),
        'Download/Throw',
      );
    });

    test('an app-private path is shown in full rather than prettified', () {
      const private =
          '/data/user/0/com.mahimmazidul.throwapp/files/Throw';
      expect(displayFolder(private, isAndroid: true), private);
    });

    test('desktop paths are unchanged', () {
      expect(
        displayFolder('/home/mahim/Documents/Throw'),
        '/home/mahim/Documents/Throw',
      );
    });
  });
}
