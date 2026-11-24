import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/temp_files.dart';
import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/models/payload_model.dart';
import 'package:throw_app/models/transfer_model.dart';
import 'package:throw_app/providers/transfer_provider.dart';
import 'package:throw_app/services/transfer_service.dart';

/// The defect as reported: "works but failed transfer consumes sender storage
/// of app". These drive the real [TransferProvider] against a service that
/// fails the way a dropped peer fails, and assert what is on disk afterwards.
class _Service implements TransferService {
  _Service({this.failFor = const {}});

  /// Endpoint ids whose send throws.
  final Set<String> failFor;

  /// Bytes each send consumes before it resolves, to prove the copy is read.
  final sent = <(String, String)>[];
  Completer<void>? hold;
  String? holdEndpoint;

  @override
  Future<void> sendFile({
    required String endpointId,
    required File file,
    String? displayName,
    int? sizeBytes,
  }) async {
    sent.add((endpointId, file.path));
    if (holdEndpoint == endpointId) {
      await hold?.future;
    }
    if (failFor.contains(endpointId)) {
      throw const SocketException('peer went away');
    }
  }

  @override
  Future<void> sendText({required String endpointId, required String text}) async {
    if (failFor.contains(endpointId)) {
      throw const SocketException('peer went away');
    }
  }

  @override
  Stream<DeviceModel> get devices => const Stream.empty();
  @override
  Stream<TransferModel> get transfers => const Stream.empty();
  @override
  Stream<ConnectionRequest> get connectionRequests => const Stream.empty();
  @override
  Stream<PayloadModel> get receivedPayloads => const Stream.empty();
  @override
  String get localDeviceName => 'Test';
  @override
  Future<void> startAdvertising({required String deviceName}) async {}
  @override
  Future<void> stopAdvertising() async {}
  @override
  Future<void> startDiscovery() async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> connect(DeviceModel device) async {}
  @override
  Future<void> disconnect(String endpointId) async {}
  @override
  Future<void> acceptConnection(String endpointId) async {}
  @override
  Future<void> rejectConnection(String endpointId) async {}
  @override
  Future<void> cancelTransfer(String transferId) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory tmp;
  late Directory cache;
  late Directory support;
  late TempFileRegistry registry;

  DeviceModel device(String id) => DeviceModel(
        id: id,
        name: 'Phone $id',
        platform: DevicePlatform.android,
        channel: TransferChannel.wifiDirect,
        lastSeen: DateTime.now(),
      );

  File cacheCopy(String name, {int bytes = 8192}) {
    final file = File('${cache.path}/share/$name');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List<int>.filled(bytes, 3));
    return file;
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('throw_transfer_leak');
    cache = Directory('${tmp.path}/cache')..createSync(recursive: true);
    support = Directory('${tmp.path}/support')..createSync(recursive: true);
    registry = TempFileRegistry(
      cacheDir: () async => cache,
      supportDir: () async => support,
    );
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('a FAILED send deletes the cached copy — the reported leak', () async {
    final copy = cacheCopy('holiday.mp4', bytes: 256 * 1024);
    final service = _Service(failFor: {'phone-1'});
    final provider = TransferProvider(service: service, tempFiles: registry);

    final ok = await provider.sendFile(
      device('phone-1'),
      filePath: copy.path,
      fileName: 'holiday.mp4',
      sizeBytes: 256 * 1024,
    );

    expect(ok, isFalse, reason: 'the send must report failure');
    expect(provider.error, isNotNull, reason: 'and say so in the UI');
    expect(copy.existsSync(), isFalse,
        reason: 'a failed transfer must not keep the sender\'s copy');
    expect(await registry.usedBytes(), 0);
  });

  test('a SUCCESSFUL send also deletes the cached copy', () async {
    final copy = cacheCopy('ok.png', bytes: 4096);
    final provider = TransferProvider(service: _Service(), tempFiles: registry);

    final ok = await provider.sendFile(
      device('phone-2'),
      filePath: copy.path,
      fileName: 'ok.png',
      sizeBytes: 4096,
    );

    expect(ok, isTrue);
    expect(copy.existsSync(), isFalse);
  });

  test('the user\'s own file is never deleted, on success or failure', () async {
    final original = File('${tmp.path}/Documents/budget.xlsx')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(1024, 9));

    for (final failing in [false, true]) {
      final provider = TransferProvider(
        service: _Service(failFor: failing ? {'d'} : const {}),
        tempFiles: registry,
      );
      await provider.sendFile(
        device('d'),
        filePath: original.path,
        fileName: 'budget.xlsx',
        sizeBytes: 1024,
      );
      expect(original.existsSync(), isTrue,
          reason: 'failing=$failing must never touch the picked original');
    }
  });

  test('one device failing does not delete the copy another is still sending',
      () async {
    final copy = cacheCopy('shared.zip', bytes: 64 * 1024);
    final service = _Service(failFor: {'slow'})..holdEndpoint = 'steady';
    service.hold = Completer<void>();
    final provider = TransferProvider(service: service, tempFiles: registry);

    // Start both; 'slow' fails at once, 'steady' is still streaming.
    final slow = provider.sendFile(
      device('slow'),
      filePath: copy.path,
      fileName: 'shared.zip',
      sizeBytes: 64 * 1024,
    );
    final steady = provider.sendFile(
      device('steady'),
      filePath: copy.path,
      fileName: 'shared.zip',
      sizeBytes: 64 * 1024,
    );

    expect(await slow, isFalse);
    expect(copy.existsSync(), isTrue,
        reason: 'the other device is still reading this file');

    service.hold!.complete();
    expect(await steady, isTrue);
    expect(copy.existsSync(), isFalse,
        reason: 'released once the last reader finished');
  });

  test('a fan-out where every device fails leaves no copies behind', () async {
    final copy = cacheCopy('big.iso', bytes: 512 * 1024);
    final provider = TransferProvider(
      service: _Service(failFor: {'a', 'b', 'c'}),
      tempFiles: registry,
    );

    final sent = await provider.sendFileTo(
      [device('a'), device('b'), device('c')],
      filePath: copy.path,
      fileName: 'big.iso',
      sizeBytes: 512 * 1024,
    );

    expect(sent, 0);
    expect(copy.existsSync(), isFalse);
    expect(await registry.usedBytes(), 0);
  });

  test('sending several files that all fail returns storage to baseline',
      () async {
    final copies = [
      cacheCopy('one.bin', bytes: 1000),
      cacheCopy('two.bin', bytes: 2000),
    ];
    final provider = TransferProvider(
      service: _Service(failFor: {'x'}),
      tempFiles: registry,
    );

    await provider.sendFilesTo(
      [device('x')],
      files: [
        for (final c in copies)
          (path: c.path, name: c.path.split('/').last, size: 1000),
      ],
    );

    expect(copies.any((c) => c.existsSync()), isFalse);
    expect(await registry.usedBytes(), 0);
  });

  test('disposing mid-send releases what it was holding', () async {
    final copy = cacheCopy('half.bin', bytes: 4096);
    final service = _Service()..holdEndpoint = 'p';
    service.hold = Completer<void>();
    final provider = TransferProvider(service: service, tempFiles: registry);

    final pending = provider.sendFile(
      device('p'),
      filePath: copy.path,
      fileName: 'half.bin',
      sizeBytes: 4096,
    );
    await Future<void>.delayed(Duration.zero);
    expect(copy.existsSync(), isTrue);

    provider.dispose();
    service.hold!.complete();
    await pending;
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(copy.existsSync(), isFalse,
        reason: 'nothing can be in flight once the provider is gone');
  });
}

void _storageRowTests() {}
