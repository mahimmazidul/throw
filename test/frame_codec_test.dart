import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/frame_codec.dart';

/// The BLE frame parser is where a transfer either works or silently stalls.
///
/// The old inline parser had three defects: it was re-entrant across an await,
/// it buffered whole files in RAM, and a split header could wedge it forever.
/// These tests feed the decoder the exact byte splits a real BLE stack
/// produces (20-byte writes, magic straddling two notifications, two frames in
/// one notification) and assert the file body comes back byte-identical.
void main() {
  group('encoder / decoder round trip', () {
    test('a text frame survives', () {
      final frame = FrameEncoder.text(
        text: 'hello from Dhaka',
        metadata: {'from': 'Pixel 8', 'tid': '1'},
      );
      final frames = FrameDecoder().add(frame);

      expect(frames, hasLength(1));
      final text = frames.single as TextFrame;
      expect(text.text, 'hello from Dhaka');
      expect(text.metadata['from'], 'Pixel 8');
    });

    test('non-ASCII text survives byte for byte', () {
      // The old Android path used `codeUnits`, which mangled Bangla.
      const body = 'ফাইল পাঠানো হচ্ছে — 100%';
      final frame = FrameEncoder.text(
        text: body,
        metadata: const {},
      );
      final text = FrameDecoder().add(frame).single as TextFrame;
      expect(text.text, body);
    });

    test('a file arrives byte-identical when split into 20-byte writes', () {
      final body = Uint8List.fromList(
        List<int>.generate(5000, (i) => (i * 7 + 13) % 256),
      );
      final frames = <int>[
        ...FrameEncoder.fileStart(
          transferId: 't1',
          fileName: 'holiday.jpg',
          sizeBytes: body.length,
          metadata: const {'from': 'Pixel 8'},
        ),
        for (final chunk in FrameEncoder.fileChunks(
          transferId: 't1',
          body: body,
        ))
          ...chunk,
      ];

      final decoder = FrameDecoder();
      final out = <Frame>[];
      // The MTU on older Android BLE is 20 bytes; every frame here is split
      // across many notifications, including mid-header.
      for (var i = 0; i < frames.length; i += 20) {
        final end = i + 20 < frames.length ? i + 20 : frames.length;
        out.addAll(decoder.add(frames.sublist(i, end)));
      }

      final start = out.whereType<FileStartFrame>().single;
      expect(start.fileName, 'holiday.jpg');
      expect(start.sizeBytes, body.length);
      expect(start.metadata['from'], 'Pixel 8');

      final received = <int>[
        for (final chunk in out.whereType<FileChunkFrame>()) ...chunk.bytes,
      ];
      expect(received, equals(body), reason: 'file bytes must be identical');
    });

    test('two frames in one notification are both decoded', () {
      final first = FrameEncoder.text(text: 'one', metadata: const {'tid': 'a'});
      final second =
          FrameEncoder.text(text: 'two', metadata: const {'tid': 'b'});
      final out = FrameDecoder().add([...first, ...second]);

      expect(out.whereType<TextFrame>().map((f) => f.text), ['one', 'two']);
    });

    test('a magic sequence split across two notifications is still found', () {
      final frame = FrameEncoder.text(text: 'split', metadata: const {});
      final decoder = FrameDecoder();

      // Cut inside the four magic bytes.
      final cut = 2;
      expect(decoder.add(frame.sublist(0, cut)), isEmpty);
      final out = decoder.add(frame.sublist(cut));
      expect((out.single as TextFrame).text, 'split');
    });

    test('noise before the magic is discarded', () {
      final frame = FrameEncoder.text(text: 'clean', metadata: const {});
      final out = FrameDecoder().add([0x00, 0xFF, 0x12, ...frame]);
      expect((out.single as TextFrame).text, 'clean');
    });

    test('a hello frame carries the sender name', () {
      final frame = FrameEncoder.hello(
        deviceName: 'Mahim Pixel',
        platform: 'android',
      );
      final hello = FrameDecoder().add(frame).single as HelloFrame;
      expect(hello.deviceName, 'Mahim Pixel');
      expect(hello.platform, 'android');
    });
  });

  group('resilience', () {
    test('a bogus length prefix does not allocate or wedge the decoder', () {
      final decoder = FrameDecoder();
      // Magic, type 2, metaLen 0xFFFFFFFF — a corrupt header.
      final bogus = Uint8List.fromList([
        0x54, 0x48, 0x52, 0x57, 2,
        0xFF, 0xFF, 0xFF, 0xFF,
        0x00, 0x00, 0x00, 0x10,
      ]);
      // Must not throw, must not retain an absurd buffer.
      final out = decoder.add(bogus);
      expect(out, isEmpty);
      expect(decoder.pendingBytes, lessThan(FrameDecoder.maxFrameBytes));

      // And the decoder still works afterwards.
      final good = FrameEncoder.text(text: 'after', metadata: const {});
      expect((decoder.add(good).single as TextFrame).text, 'after');
    });

    test('an unknown frame type is skipped, not fatal', () {
      final decoder = FrameDecoder();
      final unknown = Uint8List.fromList([
        0x54, 0x48, 0x52, 0x57, 99,
        0x00, 0x00, 0x00, 0x02, // metaLen 2
        0x00, 0x00, 0x00, 0x01, // bodyLen 1
        0x7B, 0x7D, // {}
        0x41, // 'A'
      ]);
      final good = FrameEncoder.text(text: 'next', metadata: const {});
      final out = decoder.add([...unknown, ...good]);
      expect(out.whereType<TextFrame>().map((f) => f.text), ['next']);
    });

    test('mismatched metadata JSON decays to an empty map, not a crash', () {
      final decoder = FrameDecoder();
      final frame = Uint8List.fromList([
        0x54, 0x48, 0x52, 0x57, 1, // text
        0x00, 0x00, 0x00, 0x03, // metaLen 3
        0x00, 0x00, 0x00, 0x02, // bodyLen 2
        0x7B, 0x7B, 0x7B, // "{{{"
        0x68, 0x69, // "hi"
      ]);
      final text = decoder.add(frame).single as TextFrame;
      expect(text.metadata, isEmpty);
      expect(text.text, 'hi');
    });

    test('a partial frame is retained, not dropped', () {
      final frame = FrameEncoder.text(text: 'kept', metadata: const {});
      final decoder = FrameDecoder();
      expect(decoder.add(frame.sublist(0, frame.length - 1)), isEmpty);
      expect(decoder.pendingBytes, greaterThan(0));
      final out = decoder.add(frame.sublist(frame.length - 1));
      expect((out.single as TextFrame).text, 'kept');
    });

    test('chunks of one file never mix with another file', () {
      final a = Uint8List.fromList(List.filled(400, 0xAA));
      final b = Uint8List.fromList(List.filled(400, 0xBB));
      final bytes = <int>[
        ...FrameEncoder.fileStart(
          transferId: 'a',
          fileName: 'a.bin',
          sizeBytes: a.length,
          metadata: const {},
        ),
        ...FrameEncoder.fileStart(
          transferId: 'b',
          fileName: 'b.bin',
          sizeBytes: b.length,
          metadata: const {},
        ),
      ];
      // Interleave the two files' chunks, as two centrals writing at once
      // to one peripheral would.
      final aChunks = FrameEncoder.fileChunks(transferId: 'a', body: a).toList();
      final bChunks = FrameEncoder.fileChunks(transferId: 'b', body: b).toList();
      for (var i = 0; i < aChunks.length; i++) {
        bytes.addAll(aChunks[i]);
        if (i < bChunks.length) bytes.addAll(bChunks[i]);
      }

      final out = FrameDecoder().add(bytes);
      final byTransfer = <String, List<int>>{};
      for (final chunk in out.whereType<FileChunkFrame>()) {
        byTransfer.putIfAbsent(chunk.transferId, () => []).addAll(chunk.bytes);
      }
      expect(byTransfer['a'], equals(a));
      expect(byTransfer['b'], equals(b));
    });
  });

  group('text is sent as a text frame, never double-wrapped', () {
    // What `sendText` writes now: the text frame straight to the link.
    Uint8List singlyFramed() => FrameEncoder.text(
          text: 'meet me at 6',
          metadata: {'from': 'Laptop', 'tid': 't1'},
        );

    // What the old code effectively produced: that same frame wrapped again by
    // the file-chunk chunker that `_writeAll` applies to its argument.
    Uint8List doublyFramed() => Uint8List.fromList(
          FrameEncoder.fileChunks(
            transferId: 't1',
            body: singlyFramed(),
          ).expand((f) => f).toList(),
        );

    test('a single frame decodes as a text frame carrying the message', () {
      final frames = FrameDecoder().add(singlyFramed());

      expect(frames, hasLength(1));
      expect(frames.single, isA<TextFrame>());
      expect((frames.single as TextFrame).text, 'meet me at 6');
    });

    test('the old double-wrapped bytes never produce a text frame', () {
      final frames = FrameDecoder().add(doublyFramed());

      // This is the defect stated as an assertion: whatever arrives, it is not
      // the message. The text is buried inside a file body.
      expect(
        frames.whereType<TextFrame>(),
        isEmpty,
        reason: 'double-wrapping loses the message entirely',
      );
      expect(frames.whereType<FileChunkFrame>(), isNotEmpty);
    });
  });
}
