import 'dart:convert';
import 'dart:typed_data';

/// Wire format for desktop BLE transfers.
///
/// A frame is:
///
/// ```text
///  0..3   magic "THRW"
///  4      type (1 = text, 2 = file header, 3 = file chunk, 4 = hello)
///  5..8   metadata length (uint32 BE)
///  9..12  body length (uint32 BE)
///  13..   metadata (UTF-8 JSON) followed by the body bytes
/// ```
///
/// The old implementation lived inline in `BluetoothService` and had three
/// defects this class exists to remove:
///
///  * it was re-entrant — `_handleIncomingBytes` was `async` and awaited a
///    disk write mid-parse, so a second notification arriving during that
///    await re-entered the parser and both copies consumed the same buffer;
///  * it buffered the **entire file** in RAM before writing it (a 300 MB video
///    on a phone) because the whole frame had to be present to parse;
///  * an unknown or garbled frame could leave a partial header in the buffer
///    that never completed, so the connection silently stopped decoding.
///
/// [FrameDecoder] is synchronous and streams: `add()` returns every complete
/// message now available, keeps the remainder, and never retains more than one
/// partial frame's header plus whatever has arrived. Large bodies are delivered
/// as [FileChunk]s, so the service writes straight to disk.
enum FrameType {
  text(1),
  fileStart(2),
  fileChunk(3),
  hello(4);

  const FrameType(this.wire);

  final int wire;

  static FrameType? fromWire(int value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}

sealed class Frame {
  const Frame();
}

/// A complete text payload.
class TextFrame extends Frame {
  const TextFrame({required this.metadata, required this.text});

  final Map<String, dynamic> metadata;
  final String text;
}

/// Announces a file about to follow in [sizeBytes]-worth of chunks.
class FileStartFrame extends Frame {
  const FileStartFrame({
    required this.metadata,
    required this.fileName,
    required this.sizeBytes,
    required this.transferId,
  });

  final Map<String, dynamic> metadata;
  final String fileName;
  final int sizeBytes;

  /// Identifies which stream the following chunks belong to, so two files
  /// arriving at once (or a file arriving while a text does) never interleave
  /// their bytes.
  final String transferId;
}

/// One slice of a file body.
class FileChunkFrame extends Frame {
  const FileChunkFrame({required this.metadata, required this.bytes});

  final Map<String, dynamic> metadata;
  final Uint8List bytes;

  String get transferId => (metadata['tid'] as String?) ?? '';
}

/// Identity handshake: the sender's human-readable name and platform.
class HelloFrame extends Frame {
  const HelloFrame({
    required this.deviceName,
    required this.platform,
  });

  final String deviceName;
  final String platform;
}

/// Builds outgoing frames.
class FrameEncoder {
  FrameEncoder._();

  static const List<int> magic = [0x54, 0x48, 0x52, 0x57]; // THRW

  /// Chunk size for the body of a [FrameType.fileChunk]. BLE writes are capped
  /// by the negotiated MTU (often 20 bytes on older stacks), so the encoder
  /// does not choose the write size — this only bounds how much body one frame
  /// carries before the service splits it again.
  static const int chunkBodySize = 180;

  static Uint8List hello({
    required String deviceName,
    required String platform,
  }) =>
      _frame(
        FrameType.hello,
        {'name': deviceName, 'platform': platform},
        Uint8List(0),
      );

  static Uint8List text({
    required String text,
    required Map<String, dynamic> metadata,
  }) =>
      _frame(
        FrameType.text,
        metadata,
        Uint8List.fromList(utf8.encode(text)),
      );

  static Uint8List fileStart({
    required String transferId,
    required String fileName,
    required int sizeBytes,
    required Map<String, dynamic> metadata,
  }) =>
      _frame(
        FrameType.fileStart,
        {
          ...metadata,
          'tid': transferId,
          'name': fileName,
          'size': sizeBytes,
        },
        Uint8List(0),
      );

  /// Splits a file body into chunk frames. A generator so a 2 GB file is never
  /// materialised as one list.
  static Iterable<Uint8List> fileChunks({
    required String transferId,
    required Uint8List body,
    int chunkSize = chunkBodySize,
  }) sync* {
    for (var offset = 0; offset < body.length; offset += chunkSize) {
      final end = offset + chunkSize < body.length
          ? offset + chunkSize
          : body.length;
      yield _frame(
        FrameType.fileChunk,
        {'tid': transferId},
        Uint8List.sublistView(body, offset, end),
      );
    }
  }

  static Uint8List _frame(
    FrameType type,
    Map<String, dynamic> metadata,
    Uint8List body,
  ) {
    final metaBytes = utf8.encode(jsonEncode(metadata));
    final builder = BytesBuilder(copy: false)
      ..add(magic)
      ..addByte(type.wire)
      ..add(_uint32(metaBytes.length))
      ..add(_uint32(body.length))
      ..add(metaBytes)
      ..add(body);
    return builder.takeBytes();
  }

  static Uint8List _uint32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.big);
    return data.buffer.asUint8List();
  }
}

/// Synchronous, streaming frame decoder.
///
/// Feed it whatever the transport delivered; it returns the frames that became
/// complete. No `await` inside, so two notifications cannot interleave.
class FrameDecoder {
  final BytesBuilder _buffer = BytesBuilder(copy: true);

  /// Guard against a corrupt length prefix asking for a 4 GB allocation. A
  /// frame larger than this is dropped and the decoder resynchronises on the
  /// next magic sequence.
  static const int maxFrameBytes = 8 * 1024 * 1024;

  /// Decodes everything available. Returns an empty list when the buffer holds
  /// only a partial frame.
  List<Frame> add(List<int> bytes) {
    if (bytes.isEmpty) return const [];
    _buffer.add(bytes);

    var data = _buffer.toBytes();
    final frames = <Frame>[];
    var consumed = 0;

    while (true) {
      final start = _indexOfMagic(data, consumed);
      if (start < 0) {
        // No complete magic in the buffer. Keep the last 3 bytes, because a
        // magic sequence can straddle two notifications — and if the buffer is
        // *shorter* than the magic, keep all of it. The old code computed the
        // tail from the buffer end rather than from `consumed` and could drop
        // a 2-byte fragment, wedging the stream for good.
        final keep = data.length - consumed < 3 ? data.length - consumed : 3;
        consumed = data.length - keep;
        break;
      }

      // Drop any garbage before the magic.
      if (start > consumed) consumed = start;
      if (data.length - consumed < 13) {
        // A frame starts here but the header is incomplete: keep from `start`.
        break;
      }

      final type = FrameType.fromWire(data[consumed + 4]);
      final metaLen = _readUint32(data, consumed + 5);
      final bodyLen = _readUint32(data, consumed + 9);

      if (metaLen < 0 || bodyLen < 0 || metaLen + bodyLen > maxFrameBytes) {
        // Bogus header: skip the magic and look for the next one.
        consumed += 1;
        continue;
      }

      final frameLen = 13 + metaLen + bodyLen;
      if (data.length - consumed < frameLen) {
        // Partial body: keep from `start`.
        break;
      }

      final metaStart = consumed + 13;
      final bodyStart = metaStart + metaLen;
      final bodyEnd = bodyStart + bodyLen;
      final metadata = _decodeMetadata(
        Uint8List.sublistView(data, metaStart, bodyStart),
      );
      final body = Uint8List.sublistView(data, bodyStart, bodyEnd);

      final frame = _build(type, metadata, body);
      if (frame != null) frames.add(frame);

      consumed = bodyEnd;
    }

    // Between them, the two exit paths left `consumed` at the start of the
    // first byte that is still relevant: either a partial frame's beginning or
    // the first byte of a split magic. Everything before it is settled.
    final leftover =
        consumed > 0 && consumed <= data.length
            ? Uint8List.sublistView(data, consumed)
            : data;
    _buffer.clear();
    _buffer.add(leftover);
    return frames;
  }

  Frame? _build(
    FrameType? type,
    Map<String, dynamic> metadata,
    Uint8List body,
  ) {
    switch (type) {
      case FrameType.text:
        return TextFrame(
          metadata: metadata,
          text: utf8.decode(body, allowMalformed: true),
        );
      case FrameType.fileStart:
        final name = (metadata['name'] as String?) ?? 'received_file';
        final size = (metadata['size'] as int?) ?? 0;
        final tid = (metadata['tid'] as String?) ?? name;
        return FileStartFrame(
          metadata: metadata,
          fileName: name,
          sizeBytes: size,
          transferId: tid,
        );
      case FrameType.fileChunk:
        return FileChunkFrame(metadata: metadata, bytes: body);
      case FrameType.hello:
        return HelloFrame(
          deviceName: (metadata['name'] as String?) ?? '',
          platform: (metadata['platform'] as String?) ?? '',
        );
      case null:
        // Unknown type from a newer build: skip rather than kill the stream.
        return null;
    }
  }

  Map<String, dynamic> _decodeMetadata(Uint8List bytes) {
    if (bytes.isEmpty) return const {};
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  /// Index of [pattern] in [data] at or after [from], or -1.
  int _indexOfMagic(Uint8List data, int from) {
    const magic = FrameEncoder.magic;
    for (var i = from; i <= data.length - magic.length; i++) {
      if (data[i] == magic[0] &&
          data[i + 1] == magic[1] &&
          data[i + 2] == magic[2] &&
          data[i + 3] == magic[3]) {
        return i;
      }
    }
    return -1;
  }

  int _readUint32(Uint8List data, int offset) =>
      ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.big);

  /// Bytes currently held for an incomplete frame — exposed for tests and for
  /// a health check in the service.
  int get pendingBytes => _buffer.length;
}
