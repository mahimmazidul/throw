import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:throw_app/core/temp_files.dart';
import 'package:throw_app/providers/share_inbox_provider.dart';

/// The share sheet is where the leak started: `receive_sharing_intent` copies
/// the shared file into the app cache, and Throw used to keep that copy
/// forever. These pin down what the inbox holds and when it lets go.
void main() {
  late Directory tmp;
  late Directory cache;
  late Directory support;

  TempFileRegistry registry() => TempFileRegistry(
        cacheDir: () async => cache,
        supportDir: () async => support,
      );

  SharedMediaFile shared(String path, {SharedMediaType? type}) => SharedMediaFile(
        path: path,
        type: type ?? SharedMediaType.file,
      );

  File cacheCopy(String name) {
    final file = File('${cache.path}/$name');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List<int>.filled(2048, 5));
    return file;
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('throw_inbox');
    cache = Directory('${tmp.path}/cache')..createSync(recursive: true);
    support = Directory('${tmp.path}/support')..createSync(recursive: true);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('an accepted share registers its cache copy for deletion', () async {
    final copy = cacheCopy('from-gallery.jpg');
    final reg = registry();
    final inbox = ShareInboxProvider(tempFiles: reg);

    inbox.accept([shared(copy.path)]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(inbox.hasPending, isTrue);
    expect(inbox.pendingPaths, [copy.path]);
    expect(reg.trackedPaths, contains(copy.path));

    inbox.clear();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(copy.existsSync(), isFalse);
  });

  test('text and url shares are not file copies and are never registered',
      () async {
    final reg = registry();
    final inbox = ShareInboxProvider(tempFiles: reg);

    inbox.accept([
      shared('hello there', type: SharedMediaType.text),
      shared('https://example.com', type: SharedMediaType.url),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(inbox.pendingPaths, isEmpty);
    expect(reg.trackedPaths, isEmpty);
    expect(inbox.hasPending, isTrue, reason: 'text still needs sending');
  });

  test('a second share releases the first one\'s copy', () async {
    final first = cacheCopy('first.mp4');
    final second = cacheCopy('second.mp4');
    final reg = registry();
    final inbox = ShareInboxProvider(tempFiles: reg);

    inbox.accept([shared(first.path)]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(first.existsSync(), isTrue);

    inbox.accept([shared(second.path)]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(first.existsSync(), isFalse,
        reason: 'the superseded share must not linger on disk');
    expect(second.existsSync(), isTrue);
    expect(inbox.pendingPaths, [second.path]);
  });

  test('a copy still being sent survives the inbox clearing', () async {
    final copy = cacheCopy('sending.bin');
    final reg = registry();
    final inbox = ShareInboxProvider(tempFiles: reg);

    inbox.accept([shared(copy.path)]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // The transfer claims the same path while the bytes stream.
    await reg.takeOwnership(copy.path);
    inbox.clear();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(copy.existsSync(), isTrue,
        reason: 'the send is still reading this file');

    await reg.release(copy.path);
    expect(copy.existsSync(), isFalse,
        reason: 'last claim released — the copy goes');
  });

  test('removing one item keeps the others', () async {
    final a = cacheCopy('a.png');
    final b = cacheCopy('b.png');
    final inbox = ShareInboxProvider(tempFiles: registry());

    inbox.accept([shared(a.path), shared(b.path)]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    inbox.removeAt(0);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isTrue);
    expect(inbox.sharedFiles.length, 1);
  });

  test('disposing cleans up whatever the user never sent', () async {
    final copy = cacheCopy('abandoned.mov');
    final inbox = ShareInboxProvider(tempFiles: registry());

    inbox.accept([shared(copy.path)]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    inbox.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(copy.existsSync(), isFalse,
        reason: 'an un-sent share must not outlive the app session');
  });

  test('a shared path outside the cache is never deleted', () async {
    final original = File('${tmp.path}/Documents/thesis.pdf')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(1024, 4));
    final reg = registry();
    final inbox = ShareInboxProvider(tempFiles: reg);

    inbox.accept([shared(original.path)]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    inbox.clear();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(original.existsSync(), isTrue);
    expect(reg.trackedPaths, isEmpty);
  });
}
