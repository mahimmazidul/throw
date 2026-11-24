import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/device_model.dart';
import '../../lib/models/payload_model.dart';
import '../../lib/models/transfer_model.dart';

void main() {
  group('PayloadModel', () {
    test('text factory sets type, text, and sizeBytes', () {
      final payload = PayloadModel.text('hello throw');
      expect(payload.type, PayloadType.text);
      expect(payload.text, 'hello throw');
      expect(payload.sizeBytes, 11);
      expect(payload.filePath, isNull);
    });

    test('file factory sets type, filePath, fileName, and sizeBytes', () {
      final payload = PayloadModel.file(
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
    const device = DeviceModel(
      id: 'd1',
      name: 'ThinkPad',
      platform: DevicePlatform.linux,
      transport: TransportType.bluetooth,
    );

    test('progress computes ratio and clamps safely', () {
      final transfer = TransferModel(
        id: 't1',
        device: device,
        payload: PayloadModel.text('abc'),
        direction: TransferDirection.outgoing,
        state: TransferState.transferring,
        bytesTransferred: 50,
        totalBytes: 200,
        startedAt: DateTime(2026, 11, 24),
      );

      expect(transfer.progress, closeTo(0.25, 0.0001));
    });

    test('progress returns 0.0 when totalBytes is 0', () {
      final transfer = TransferModel(
        id: 't2',
        device: device,
        payload: PayloadModel.text(''),
        direction: TransferDirection.incoming,
        state: TransferState.transferring,
        bytesTransferred: 0,
        totalBytes: 0,
        startedAt: DateTime(2026, 11, 24),
      );

      expect(transfer.progress, 0.0);
    });
  });
}
