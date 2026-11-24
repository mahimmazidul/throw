import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../core/frame_codec.dart';
import '../core/incoming_store.dart';
import '../core/transfer_stats.dart';
import '../models/device_model.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';
import 'transfer_service.dart';

/// Cross-platform BLE transfer implementation backed by `bluetooth_low_energy`.
///
/// - Central role (`CentralManager`): Android, Windows, Linux.
/// - Peripheral role (`PeripheralManager`): Android, Windows (unsupported on Linux).
///
/// Frames are built and parsed by [FrameEncoder]/[FrameDecoder]. Files are
/// streamed as chunks straight into an [IncomingStore] file, so a large video
/// never sits in memory and a receipt always knows its path.
class BluetoothService implements TransferService {
  BluetoothService({IncomingStore? store})
      : _store = store ?? IncomingStore();

  final IncomingStore _store;

  final CentralManager _central = CentralManager();
  final PeripheralManager? _peripheral =
      Platform.isLinux ? null : PeripheralManager();

  static final UUID _serviceUuid =
      UUID.fromString('0000fe2c-0000-1000-8000-00805f9b34fb');
  static final UUID _txCharUuid =
      UUID.fromString('0000fe2d-0000-1000-8000-00805f9b34fb');
  static final UUID _rxCharUuid =
      UUID.fromString('0000fe2e-0000-1000-8000-00805f9b34fb');

  final _devicesController = StreamController<DeviceModel>.broadcast();
  final _transfersController = StreamController<TransferModel>.broadcast();
  final _connectionRequestsController =
      StreamController<ConnectionRequest>.broadcast();
  final _receivedPayloadsController =
      StreamController<PayloadModel>.broadcast();

  final Map<String, DeviceModel> _discoveredDevices = {};
  final Map<String, Peripheral> _peripherals = {};
  final Map<String, GATTCharacteristic> _txCharacteristics = {};
  final Map<String, TransferModel> _transfers = {};
  final Map<String, TransferRateTracker> _rateTrackers = {};

  /// One decoder per peer: two centrals writing at once must not share a
  /// buffer.
  final Map<String, FrameDecoder> _decoders = {};

  /// In-flight inbound files, keyed by the sender's transfer id.
  final Map<String, _InboundFile> _inbound = {};

  StreamSubscription<DiscoveredEventArgs>? _discoveredSub;
  StreamSubscription<PeripheralConnectionStateChangedEventArgs>? _connSub;
  StreamSubscription<GATTCharacteristicNotifiedEventArgs>? _notifySub;
  StreamSubscription<GATTCharacteristicWriteRequestedEventArgs>? _writeReqSub;

  bool _isAdvertising = false;
  bool _isDiscovering = false;
  String _localDeviceName = 'Throw';

  @override
  Stream<DeviceModel> get devices => _devicesController.stream;

  @override
  Stream<TransferModel> get transfers => _transfersController.stream;

  @override
  Stream<ConnectionRequest> get connectionRequests =>
      _connectionRequestsController.stream;

  @override
  Stream<PayloadModel> get receivedPayloads =>
      _receivedPayloadsController.stream;

  @override
  String get localDeviceName => _localDeviceName;

  @override
  Future<void> startAdvertising({required String deviceName}) async {
    // Remember the name even on Linux, where we cannot advertise: the HELLO
    // frame and the UI both read it.
    if (deviceName.trim().isNotEmpty) _localDeviceName = deviceName.trim();
    if (_peripheral == null) {
      _isAdvertising = false;
      return;
    }
    if (_isAdvertising) return;

    final service = GATTService(
      uuid: _serviceUuid,
      isPrimary: true,
      includedServices: [],
      characteristics: [
        GATTCharacteristic.mutable(
          uuid: _txCharUuid,
          properties: [
            GATTCharacteristicProperty.write,
            GATTCharacteristicProperty.writeWithoutResponse,
          ],
          permissions: [GATTCharacteristicPermission.write],
          descriptors: [],
        ),
        GATTCharacteristic.mutable(
          uuid: _rxCharUuid,
          properties: [
            GATTCharacteristicProperty.read,
            GATTCharacteristicProperty.notify,
          ],
          permissions: [GATTCharacteristicPermission.read],
          descriptors: [],
        ),
      ],
    );

    await _peripheral!.removeAllServices();
    await _peripheral!.addService(service);

    _writeReqSub ??=
        _peripheral!.characteristicWriteRequested.listen((event) async {
      await _peripheral!.respondWriteRequest(event.request);
      _onBytes(event.central.uuid.toString(), event.request.value);
    });

    final advertisement = Advertisement(
      // Windows does not allow a local name in the advertisement. The name
      // still reaches the peer through the HELLO frame on connect, which is the
      // second half of the fix for "it only shows Throw".
      name: Platform.isWindows ? null : _localDeviceName,
      serviceUUIDs: [_serviceUuid],
    );
    await _peripheral!.startAdvertising(advertisement);
    _isAdvertising = true;
  }

  @override
  Future<void> stopAdvertising() async {
    if (_peripheral == null || !_isAdvertising) return;
    await _peripheral!.stopAdvertising();
    _isAdvertising = false;
  }

  @override
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    _discoveredSub ??= _central.discovered.listen((event) {
      final id = event.peripheral.uuid.toString();
      _peripherals[id] = event.peripheral;

      String? name;
      try {
        name = event.advertisement.name;
      } catch (_) {
        name = null;
      }

      final existing = _discoveredDevices[id];
      final device = (existing ??
              DeviceModel(
                id: id,
                name: id,
                platform: DevicePlatform.unknown,
                channel: TransferChannel.bluetooth,
                isConnected: false,
                lastSeen: DateTime.now(),
              ))
          // A late discovery event with no name must not erase a name learned
          // from HELLO.
          .withLearnedName(name)
          .copyWith(lastSeen: DateTime.now());
      _discoveredDevices[id] = device;
      _devicesController.add(device);
    });

    _connSub ??= _central.connectionStateChanged.listen((event) {
      final id = event.peripheral.uuid.toString();
      final connected = event.state == ConnectionState.connected;
      final existing = _discoveredDevices[id];
      if (existing != null) {
        _upsertDevice(existing.copyWith(
          isConnected: connected,
          lastSeen: DateTime.now(),
        ));
      }
      if (!connected) {
        _decoders.remove(id);
        _abandonInboundFor(id);
      }
    });

    _notifySub ??= _central.characteristicNotified.listen((event) {
      _onBytes(event.peripheral.uuid.toString(), event.value);
    });

    await _central.startDiscovery(serviceUUIDs: [_serviceUuid]);
    _isDiscovering = true;
  }

  @override
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    await _central.stopDiscovery();
    _isDiscovering = false;
  }

  @override
  Future<void> connect(DeviceModel device) async {
    final peripheral = _peripherals[device.id];
    if (peripheral == null) {
      throw StateError('Peripheral ${device.id} not found.');
    }

    await _central.connect(peripheral);
    final services = await _central.discoverGATT(peripheral);
    for (final service in services) {
      if (service.uuid == _serviceUuid) {
        for (final char in service.characteristics) {
          if (char.uuid == _txCharUuid) {
            _txCharacteristics[device.id] = char;
          } else if (char.uuid == _rxCharUuid) {
            await _central.setCharacteristicNotifyState(
              peripheral,
              char,
              state: true,
            );
          }
        }
      }
    }

    // Identify ourselves as soon as the link is up, so the other side shows a
    // name rather than an address.
    try {
      await _write(
        device.id,
        FrameEncoder.hello(
          deviceName: _localDeviceName,
          platform: DevicePlatform.ofThisMachine().name,
        ),
      );
    } catch (_) {
      // A failed hello is not a failed connection; the name fallback covers it.
    }
  }

  @override
  Future<void> disconnect(String endpointId) async {
    final peripheral = _peripherals[endpointId];
    if (peripheral != null) {
      await _central.disconnect(peripheral);
    }
    _txCharacteristics.remove(endpointId);
    _decoders.remove(endpointId);
  }

  @override
  Future<void> acceptConnection(String endpointId) async {
    // BLE connections are accepted at the GATT layer.
  }

  @override
  Future<void> rejectConnection(String endpointId) async {
    await disconnect(endpointId);
  }

  @override
  Future<void> sendText({
    required String endpointId,
    required String text,
  }) async {
    final bytes = Uint8List.fromList(text.codeUnits);
    final transferId = _newId();

    final transfer = _startTransfer(
      id: transferId,
      endpointId: endpointId,
      payload: PayloadModel(
        id: transferId,
        kind: PayloadKind.text,
        direction: PayloadDirection.sent,
        text: text,
        sizeBytes: bytes.length,
        createdAt: DateTime.now(),
      ),
      totalBytes: bytes.length,
    );

    try {
      final frames = FrameEncoder.text(
        text: text,
        metadata: {'from': _localDeviceName, 'tid': transferId},
      );
      await _writeAll(endpointId, transferId, frames.length, frames, transfer);
      _complete(transferId, bytes.length);
    } catch (e) {
      _fail(transferId, e);
      rethrow;
    }
  }

  @override
  Future<void> sendFile({
    required String endpointId,
    required File file,
    String? displayName,
    int? sizeBytes,
  }) async {
    final fileName = (displayName ?? _basename(file.path)).trim();
    final size = sizeBytes ?? await file.length();
    final transferId = _newId();

    final transfer = _startTransfer(
      id: transferId,
      endpointId: endpointId,
      payload: PayloadModel(
        id: transferId,
        kind: PayloadKind.file,
        direction: PayloadDirection.sent,
        name: fileName,
        path: file.path,
        sizeBytes: size,
        createdAt: DateTime.now(),
      ),
      totalBytes: size,
    );

    try {
      // Header first: the receiver can open the destination file before the
      // first chunk arrives, and knows the total to draw a bar.
      await _write(
        endpointId,
        FrameEncoder.fileStart(
          transferId: transferId,
          fileName: fileName,
          sizeBytes: size,
          metadata: {'from': _localDeviceName},
        ),
      );

      var sent = 0;
      // Streamed in 8 KiB reads rather than `readAsBytes`: the old code held
      // the entire file in memory.
      await for (final chunk in file.openRead()) {
        await _writeAll(
          endpointId,
          transferId,
          sent + chunk.length,
          chunk,
          transfer,
        );
        sent += chunk.length;
        _publishProgress(transferId, sent, size);
      }
      _complete(transferId, size);
    } catch (e) {
      _fail(transferId, e);
      rethrow;
    }
  }

  /// Wraps [body] in file-chunk frames and writes each through the BLE link.
  Future<void> _writeAll(
    String endpointId,
    String transferId,
    int totalBytes,
    List<int> body,
    TransferModel transfer,
  ) async {
    final bytes = Uint8List.fromList(body);
    final frames = FrameEncoder.fileChunks(
      transferId: transferId,
      body: bytes,
    );
    for (final frame in frames) {
      await _write(endpointId, frame);
    }
  }

  Future<void> _write(String endpointId, Uint8List frame) async {
    final peripheral = _peripherals[endpointId];
    final txChar = _txCharacteristics[endpointId];
    if (peripheral == null || txChar == null) {
      throw StateError('Device $endpointId is not connected.');
    }

    final maxLen = await _central.getMaximumWriteLength(
      peripheral,
      type: GATTCharacteristicWriteType.withResponse,
    );
    final chunkSize = maxLen > 0 ? maxLen : 20;

    // The frame is split across writes; the receiver's decoder reassembles.
    for (var offset = 0; offset < frame.length; offset += chunkSize) {
      final end =
          offset + chunkSize < frame.length ? offset + chunkSize : frame.length;
      await _central.writeCharacteristic(
        peripheral,
        txChar,
        value: Uint8List.sublistView(frame, offset, end),
        type: GATTCharacteristicWriteType.withResponse,
      );
    }
  }

  @override
  Future<void> cancelTransfer(String transferId) async {
    final existing = _transfers[transferId];
    if (existing == null) return;
    _transfers[transferId] = existing.copyWith(
      status: TransferStatus.cancelled,
      endedAt: DateTime.now(),
    );
    _transfersController.add(_transfers[transferId]!);
  }

  // ── Inbound ─────────────────────────────────────────────────────────────

  /// Synchronous: buffers, decodes, and hands each complete frame to a
  /// handler. No `await` between decode steps, so re-entrancy is impossible.
  void _onBytes(String deviceId, Uint8List bytes) {
    final decoder = _decoders.putIfAbsent(deviceId, FrameDecoder.new);
    final frames = decoder.add(bytes);
    for (final frame in frames) {
      unawaited(_handleFrame(deviceId, frame));
    }
  }

  Future<void> _handleFrame(String deviceId, Frame frame) async {
    switch (frame) {
      case HelloFrame():
        final existing = _discoveredDevices[deviceId];
        if (existing != null) {
          _upsertDevice(existing.withLearnedName(frame.deviceName).copyWith(
                platform: DevicePlatform.parse(frame.platform),
                isConnected: true,
              ));
        } else {
          _upsertDevice(DeviceModel(
            id: deviceId,
            name: frame.deviceName,
            platform: DevicePlatform.parse(frame.platform),
            channel: TransferChannel.bluetooth,
            isConnected: true,
            lastSeen: DateTime.now(),
          ));
        }

      case TextFrame():
        final sender = frame.metadata['from'] as String?;
        final id = (frame.metadata['tid'] as String?) ?? _newId();
        final payload = PayloadModel(
          id: id,
          kind: PayloadKind.text,
          direction: PayloadDirection.received,
          text: frame.text,
          sizeBytes: frame.text.length,
          createdAt: DateTime.now(),
          senderName: sender,
        );
        final transfer = _startTransfer(
          id: id,
          endpointId: deviceId,
          payload: payload,
          totalBytes: payload.sizeBytes,
          direction: TransferDirection.receiving,
          senderName: sender,
        );
        _transfers[id] = transfer.copyWith(
          status: TransferStatus.completed,
          bytesTransferred: payload.sizeBytes,
          endedAt: DateTime.now(),
        );
        _transfersController.add(_transfers[id]!);
        _receivedPayloadsController.add(payload);

      case FileStartFrame():
        await _beginInboundFile(deviceId, frame);

      case FileChunkFrame():
        await _appendInboundChunk(frame);
    }
  }

  Future<void> _beginInboundFile(String deviceId, FileStartFrame frame) async {
    final transfer = _startTransfer(
      id: frame.transferId,
      endpointId: deviceId,
      payload: PayloadModel(
        id: frame.transferId,
        kind: PayloadKind.file,
        direction: PayloadDirection.received,
        name: frame.fileName,
        sizeBytes: frame.sizeBytes,
        createdAt: DateTime.now(),
        senderName: frame.metadata['from'] as String?,
      ),
      totalBytes: frame.sizeBytes,
      direction: TransferDirection.receiving,
      senderName: frame.metadata['from'] as String?,
    );
    _transfers[frame.transferId] = transfer;

    try {
      // Path is reserved now, file opened for append-streaming. Nothing is
      // announced to the receipt list until the last chunk lands.
      final path = await _store.pathFor(frame.fileName);
      final sink = File(path).openWrite();
      _inbound[frame.transferId] = _InboundFile(
        fileName: frame.fileName,
        path: path,
        expectedBytes: frame.sizeBytes,
        sink: sink,
        senderName: frame.metadata['from'] as String?,
      );
      _transfersController.add(transfer);
    } catch (e) {
      _fail(frame.transferId, e);
    }
  }

  Future<void> _appendInboundChunk(FileChunkFrame frame) async {
    final inbound = _inbound[frame.transferId];
    if (inbound == null) {
      // Chunks from a file whose header we never saw: ignore rather than write
      // bytes to an unknown path.
      return;
    }

    try {
      inbound.sink.add(frame.bytes);
      inbound.receivedBytes += frame.bytes.length;
      _publishProgress(
        frame.transferId,
        inbound.receivedBytes,
        inbound.expectedBytes,
      );

      if (inbound.expectedBytes > 0 &&
          inbound.receivedBytes >= inbound.expectedBytes) {
        await _finishInboundFile(frame.transferId, inbound);
      }
    } catch (e) {
      _inbound.remove(frame.transferId);
      _fail(frame.transferId, e);
    }
  }

  Future<void> _finishInboundFile(String id, _InboundFile inbound) async {
    _inbound.remove(id);
    await inbound.sink.flush();
    await inbound.sink.close();

    final transfer = _transfers[id];
    if (transfer != null) {
      _transfers[id] = transfer.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: inbound.receivedBytes,
        totalBytes: inbound.expectedBytes > 0
            ? inbound.expectedBytes
            : inbound.receivedBytes,
        endedAt: DateTime.now(),
        savedPath: inbound.path,
      );
      _transfersController.add(_transfers[id]!);
    }

    _receivedPayloadsController.add(
      PayloadModel(
        id: id,
        kind: PayloadKind.file,
        direction: PayloadDirection.received,
        name: inbound.fileName,
        path: inbound.path,
        sizeBytes: inbound.receivedBytes,
        createdAt: DateTime.now(),
        senderName: inbound.senderName,
      ),
    );
  }

  void _abandonInboundFor(String deviceId) {
    for (final entry in _inbound.entries.toList()) {
      final transfer = _transfers[entry.key];
      if (transfer != null && transfer.peer.id == deviceId) {
        _inbound.remove(entry.key);
        unawaited(entry.value.sink.close());
        _fail(entry.key, 'Connection lost');
      }
    }
  }

  // ── Transfer bookkeeping ─────────────────────────────────────────────────

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _basename(String path) => path.split(RegExp(r'[/\\]')).last;

  DeviceModel _peerFor(String endpointId, {String? senderName}) {
    final known = _discoveredDevices[endpointId];
    if (known != null) {
      return senderName == null ? known : known.withLearnedName(senderName);
    }
    return DeviceModel(
      id: endpointId,
      name: senderName ?? '',
      platform: DevicePlatform.unknown,
      channel: TransferChannel.bluetooth,
      isConnected: true,
      lastSeen: DateTime.now(),
    );
  }

  TransferModel _startTransfer({
    required String id,
    required String endpointId,
    required PayloadModel payload,
    required int totalBytes,
    TransferDirection direction = TransferDirection.sending,
    String? senderName,
  }) {
    final transfer = TransferModel(
      id: id,
      peer: _peerFor(endpointId, senderName: senderName),
      payloads: [payload],
      status: TransferStatus.transferring,
      bytesTransferred: 0,
      totalBytes: totalBytes,
      direction: direction,
      startedAt: DateTime.now(),
    );
    _transfers[id] = transfer;
    _rateTrackers[id] = TransferRateTracker();
    _transfersController.add(transfer);
    return transfer;
  }

  void _publishProgress(String id, int bytes, int total) {
    final existing = _transfers[id];
    if (existing == null) return;
    final tracker = _rateTrackers.putIfAbsent(id, TransferRateTracker.new)
      ..sample(bytes);
    final updated = existing.copyWith(
      bytesTransferred: bytes,
      totalBytes: total > 0 ? total : existing.totalBytes,
      speedBytesPerSecond: tracker.bytesPerSecond,
    );
    _transfers[id] = updated;
    _transfersController.add(updated);
  }

  void _complete(String id, int total) {
    final existing = _transfers[id];
    if (existing == null) return;
    final tracker = _rateTrackers.remove(id);
    _transfers[id] = existing.copyWith(
      status: TransferStatus.completed,
      bytesTransferred: total,
      totalBytes: total > 0 ? total : existing.totalBytes,
      // Final rate: the average over the whole transfer, not the last burst.
      speedBytesPerSecond:
          tracker?.averageBytesPerSecond(total) ?? existing.speedBytesPerSecond,
      endedAt: DateTime.now(),
    );
    _transfersController.add(_transfers[id]!);
  }

  void _fail(String id, Object error) {
    final existing = _transfers[id];
    if (existing == null) return;
    _rateTrackers.remove(id);
    _transfers[id] = existing.copyWith(
      status: TransferStatus.failed,
      error: error.toString(),
      endedAt: DateTime.now(),
    );
    _transfersController.add(_transfers[id]!);
  }

  void _upsertDevice(DeviceModel device) {
    _discoveredDevices[device.id] = device;
    _devicesController.add(device);
  }

  @override
  Future<void> dispose() async {
    await stopAdvertising();
    await stopDiscovery();
    await _discoveredSub?.cancel();
    await _connSub?.cancel();
    await _notifySub?.cancel();
    await _writeReqSub?.cancel();
    for (final inbound in _inbound.values) {
      await inbound.sink.close();
    }
    await _devicesController.close();
    await _transfersController.close();
    await _connectionRequestsController.close();
    await _receivedPayloadsController.close();
  }
}

/// State for a file being received: where it is going and how much has landed.
class _InboundFile {
  _InboundFile({
    required this.fileName,
    required this.path,
    required this.expectedBytes,
    required this.sink,
    this.senderName,
  });

  final String fileName;
  final String path;
  final int expectedBytes;
  final IOSink sink;
  final String? senderName;
  int receivedBytes = 0;
}
