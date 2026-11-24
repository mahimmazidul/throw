import 'package:flutter_test/flutter_test.dart';

import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/models/payload_model.dart';
import 'package:throw_app/models/transfer_model.dart';

void main() {
  final now = DateTime.utc(2026, 11, 24);

  group('PayloadModel', () {
    test('text payload sets type, text, and sizeBytes', () {
      final payload = PayloadModel(
        id: 'p1',
        kind: PayloadKind.text,
        direction: PayloadDirection.sent,
        createdAt: now,
        text: 'hello throw',
        sizeBytes: 11,
      );
      expect(payload.kind, PayloadKind.text);
      expect(payload.text, 'hello throw');
      expect(payload.sizeBytes, 11);
      expect(payload.path, isNull);
    });

    test('file payload sets type, path, name, and sizeBytes', () {
      final payload = PayloadModel(
        id: 'p2',
        kind: PayloadKind.file,
        direction: PayloadDirection.sent,
        createdAt: now,
        path: '/tmp/photo.jpg',
        name: 'photo.jpg',
        sizeBytes: 2048,
      );
      expect(payload.kind, PayloadKind.file);
      expect(payload.path, '/tmp/photo.jpg');
      expect(payload.name, 'photo.jpg');
      expect(payload.sizeBytes, 2048);
    });
  });

  group('TransferModel', () {
    final device = DeviceModel(
      id: 'd1',
      name: 'ThinkPad',
      platform: DevicePlatform.linux,
      channel: TransferChannel.bluetooth,
      lastSeen: now,
    );

    test('progress computes ratio and clamps safely', () {
      final transfer = TransferModel(
        id: 't1',
        peer: device,
        payloads: [
          PayloadModel(
            id: 'p1',
            kind: PayloadKind.text,
            direction: PayloadDirection.sent,
            createdAt: now,
            text: 'abc',
            sizeBytes: 200,
          ),
        ],
        status: TransferStatus.transferring,
        bytesTransferred: 50,
        totalBytes: 200,
        startedAt: now,
      );

      expect(transfer.progress, closeTo(0.25, 0.0001));
    });

    test('progress returns 0.0 when totalBytes is 0', () {
      final transfer = TransferModel(
        id: 't2',
        peer: device,
        payloads: [
          PayloadModel(
            id: 'p2',
            kind: PayloadKind.text,
            direction: PayloadDirection.sent,
            createdAt: now,
            text: '',
            sizeBytes: 0,
          ),
        ],
        status: TransferStatus.transferring,
        bytesTransferred: 0,
        totalBytes: 0,
        startedAt: now,
      );

      expect(transfer.progress, 0.0);
    });
  });
}
