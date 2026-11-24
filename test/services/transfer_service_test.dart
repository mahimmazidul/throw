import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/device_model.dart';
import '../../lib/models/payload_model.dart';
import '../../lib/models/transfer_model.dart';

void main() {
  group('PayloadModel', () {
    test('text payload sets type, text, and sizeBytes', () {
      const payload = PayloadModel(
        id: 'p1',
        type: PayloadType.text,
        text: 'hello throw',
        sizeBytes: 11,
      );
      expect(payload.type, PayloadType.text);
      expect(payload.text, 'hello throw');
      expect(payload.sizeBytes, 11);
      expect(payload.filePath, isNull);
    });

    test('file payload sets type, filePath, fileName, and sizeBytes', () {
      const payload = PayloadModel(
        id: 'p2',
        type: PayloadType.file,
        filePath: '/tmp/photo.jpg',
        fileName: 'photo.jpg',
        sizeBytes: 2048,
      );
      expect(payload.type, PayloadType.file);
      expect(payload.filePath, '/tmp/photo.jpg');
      expect(payload.fileName, 'photo.jpg');
      expect(payload.sizeBytes, 2048);
    });
  });

  group('TransferModel', () {
    final now = DateTime(2026, 11, 24);
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
        payloads: const [
          PayloadModel(
            id: 'p1',
            type: PayloadType.text,
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
        payloads: const [
          PayloadModel(
            id: 'p2',
            type: PayloadType.text,
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
