import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:path_provider/path_provider.dart';

import '../core/utils.dart';
import '../models/device_model.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';
import 'transfer_service.dart';

/// Cross-platform BLE transfer implementation backed by `bluetooth_low_energy`.
///
/// - Central role (`CentralManager`): Android, Windows, Linux.
/// - Peripheral role (`PeripheralManager`): Android, Windows (unsupported on Linux).
class BluetoothService implements TransferService {
  final CentralManager _central = CentralManager();
  final PeripheralManager? _peripheral =
      Platform.isLinux ? null : PeripheralManager();

  static final UUID _serviceUuid =
      UUID.fromString('0000fe2c-0000-1000-8000-00805f9b34fb');
  static final UUID _txCharUuid =
      UUID.fromString('0000fe2d-0000-1000-8000-00805f9b34fb');
  static final UUID _rxCharUuid =
      UUID.fromString('0000fe2e-0000-1000-8000-00805f9b34fb');

  static const List<int> _magic = [0x54, 0x48, 0x52, 0x57]; // THRW
  static const int _typeText = 1;
  static const int _typeFile = 2;

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
  final Map<String, BytesBuilder> _rxBuffers = {};

  StreamSubscription<DiscoveredEventArgs>? _discoveredSub;
  StreamSubscription<PeripheralConnectionStateChangedEventArgs>? _connSub;
  StreamSubscription<GATTCharacteristicNotifiedEventArgs>? _notifySub;
  StreamSubscription<GATTCharacteristicWriteRequestedEventArgs>? _writeReqSub;

  bool _isAdvertising = false;
  bool _isDiscovering = false;

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
  Future<void> startAdvertising({required String deviceName}) async {
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
      _handleIncomingBytes(
        event.central.uuid.toString(),
        event.request.value,
      );
    });

    final advertisement = Advertisement(
      name: Platform.isWindows ? null : deviceName,
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

      final device = DeviceModel(
        id: id,
        name: (name != null && name.isNotEmpty) ? name : id,
        platform: _guessPlatform(),
        channel: TransferChannel.bluetooth,
        isConnected: _discoveredDevices[id]?.isConnected ?? false,
        lastSeen: DateTime.now(),
      );
      _discoveredDevices[id] = device;
      _devicesController.add(device);
    });

    _connSub ??= _central.connectionStateChanged.listen((event) {
      final id = event.peripheral.uuid.toString();
      final connected = event.state == ConnectionState.connected;
      final existing = _discoveredDevices[id];
      if (existing != null) {
        final updated = existing.copyWith(
          isConnected: connected,
          lastSeen: DateTime.now(),
        );
        _discoveredDevices[id] = updated;
        _devicesController.add(updated);
      }
    });

    _notifySub ??= _central.characteristicNotified.listen((event) {
      _handleIncomingBytes(event.peripheral.uuid.toString(), event.value);
    });

    await _central.startDiscovery(serviceUUIDs: [_serviceUuid]);
    _isDiscovering = true;
  }

  DevicePlatform _guessPlatform() {
    if (Platform.isWindows) return DevicePlatform.windows;
    if (Platform.isLinux) return DevicePlatform.linux;
    return DevicePlatform.android;
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
  }

  @override
  Future<void> disconnect(String endpointId) async {
    final peripheral = _peripherals[endpointId];
    if (peripheral != null) {
      await _central.disconnect(peripheral);
    }
    _txCharacteristics.remove(endpointId);
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
    final data = Uint8List.fromList(utf8.encode(text));
    final payload = PayloadModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: PayloadKind.text,
      direction: PayloadDirection.sent,
      text: text,
      sizeBytes: data.length,
      createdAt: DateTime.now(),
    );
    final frame = _buildFrame(_typeText, {'name': 'text'}, data);
    await _sendBytes(endpointId, payload, frame);
  }

  @override
  Future<void> sendFile({
    required String endpointId,
    required File file,
  }) async {
    final data = await file.readAsBytes();
    final fileName = AppUtils.sanitizeFileName(
      file.path.split(RegExp(r'[/\\]')).last,
    );
    final payload = PayloadModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: PayloadKind.file,
      direction: PayloadDirection.sent,
      path: file.path,
      name: fileName,
      sizeBytes: data.length,
      createdAt: DateTime.now(),
    );
    final frame = _buildFrame(
      _typeFile,
      {'name': fileName, 'size': data.length},
      data,
    );
    await _sendBytes(endpointId, payload, frame);
  }

  Uint8List _buildFrame(int type, Map<String, dynamic> meta, Uint8List data) {
    final metaBytes = utf8.encode(jsonEncode(meta));
    final builder = BytesBuilder();
    builder.add(_magic);
    builder.add([type]);
    final metaLen = ByteData(4)..setUint32(0, metaBytes.length, Endian.big);
    builder.add(metaLen.buffer.asUint8List());
    final dataLen = ByteData(4)..setUint32(0, data.length, Endian.big);
    builder.add(dataLen.buffer.asUint8List());
    builder.add(metaBytes);
    builder.add(data);
    return builder.toBytes();
  }

  Future<void> _sendBytes(
    String endpointId,
    PayloadModel payload,
    Uint8List data,
  ) async {
    final peripheral = _peripherals[endpointId];
    final txChar = _txCharacteristics[endpointId];
    if (peripheral == null || txChar == null) {
      throw StateError('Device $endpointId is not connected.');
    }

    final target = _discoveredDevices[endpointId] ??
        DeviceModel(
          id: endpointId,
          name: endpointId,
          platform: _guessPlatform(),
          channel: TransferChannel.bluetooth,
          isConnected: true,
          lastSeen: DateTime.now(),
        );

    final transferId = DateTime.now().microsecondsSinceEpoch.toString();
    var transfer = TransferModel(
      id: transferId,
      peer: target,
      payloads: [payload],
      status: TransferStatus.transferring,
      bytesTransferred: 0,
      totalBytes: data.length,
      startedAt: DateTime.now(),
    );
    _transfers[transferId] = transfer;
    _transfersController.add(transfer);

    try {
      final maxLen = await _central.getMaximumWriteLength(
        peripheral,
        type: GATTCharacteristicWriteType.withResponse,
      );
      final chunkSize = maxLen > 0 ? maxLen : 20;

      for (var offset = 0; offset < data.length; offset += chunkSize) {
        final end = (offset + chunkSize < data.length)
            ? offset + chunkSize
            : data.length;
        final chunk = data.sublist(offset, end);
        await _central.writeCharacteristic(
          peripheral,
          txChar,
          value: chunk,
          type: GATTCharacteristicWriteType.withResponse,
        );
        transfer = transfer.copyWith(bytesTransferred: end);
        _transfers[transferId] = transfer;
        _transfersController.add(transfer);
      }

      transfer = transfer.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: data.length,
        endedAt: DateTime.now(),
      );
      _transfers[transferId] = transfer;
      _transfersController.add(transfer);
    } catch (e) {
      transfer = transfer.copyWith(
        status: TransferStatus.failed,
        error: e.toString(),
        endedAt: DateTime.now(),
      );
      _transfers[transferId] = transfer;
      _transfersController.add(transfer);
      rethrow;
    }
  }

  @override
  Future<void> cancelTransfer(String transferId) async {
    final existing = _transfers[transferId];
    if (existing != null) {
      final updated = existing.copyWith(
        status: TransferStatus.cancelled,
        endedAt: DateTime.now(),
      );
      _transfers[transferId] = updated;
      _transfersController.add(updated);
    }
  }

  void _handleIncomingBytes(String deviceId, Uint8List bytes) {
    final buffer = _rxBuffers.putIfAbsent(deviceId, () => BytesBuilder());
    buffer.add(bytes);
    _tryParseFrames(deviceId);
  }

  Future<void> _tryParseFrames(String deviceId) async {
    final buffer = _rxBuffers[deviceId];
    if (buffer == null) return;
    var data = buffer.toBytes();

    while (true) {
      // Find magic
      final magicIndex = _indexOfMagic(data);
      if (magicIndex < 0) {
        // Keep tail bytes in case magic is split across chunks.
        final keep = data.length > 3 ? 3 : data.length;
        _rxBuffers[deviceId] = BytesBuilder()
          ..add(Uint8List.sublistView(data, data.length - keep));
        return;
      }
      if (magicIndex > 0) {
        data = Uint8List.sublistView(data, magicIndex);
      }
      // Minimum header: 4 magic + 1 type + 4 metaLen + 4 dataLen = 13
      if (data.length < 13) {
        _rxBuffers[deviceId] = BytesBuilder()..add(data);
        return;
      }
      final type = data[4];
      final metaLen = ByteData.sublistView(data, 5, 9).getUint32(0, Endian.big);
      final dataLen = ByteData.sublistView(data, 9, 13).getUint32(0, Endian.big);
      final frameLen = 13 + metaLen + dataLen;
      if (data.length < frameLen) {
        _rxBuffers[deviceId] = BytesBuilder()..add(data);
        return;
      }

      final metaBytes = Uint8List.sublistView(data, 13, 13 + metaLen);
      final payloadBytes =
          Uint8List.sublistView(data, 13 + metaLen, frameLen);
      data = Uint8List.sublistView(data, frameLen);

      Map<String, dynamic> meta = const {};
      try {
        meta = jsonDecode(utf8.decode(metaBytes)) as Map<String, dynamic>;
      } catch (_) {}

      await _emitReceived(deviceId, type, meta, payloadBytes);
    }
  }

  int _indexOfMagic(Uint8List data) {
    for (var i = 0; i <= data.length - 4; i++) {
      if (data[i] == _magic[0] &&
          data[i + 1] == _magic[1] &&
          data[i + 2] == _magic[2] &&
          data[i + 3] == _magic[3]) {
        return i;
      }
    }
    return -1;
  }

  Future<void> _emitReceived(
    String deviceId,
    int type,
    Map<String, dynamic> meta,
    Uint8List payloadBytes,
  ) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    if (type == _typeFile) {
      final rawName = (meta['name'] as String?) ?? 'received_file';
      final fileName = AppUtils.sanitizeFileName(rawName);
      try {
        final dir = await getApplicationDocumentsDirectory();
        final dest = File('${dir.path}/$fileName');
        await dest.writeAsBytes(payloadBytes, flush: true);
        _receivedPayloadsController.add(
          PayloadModel(
            id: id,
            kind: PayloadKind.file,
            direction: PayloadDirection.received,
            name: fileName,
            path: dest.path,
            sizeBytes: payloadBytes.length,
            createdAt: DateTime.now(),
          ),
        );
      } catch (e) {
        _receivedPayloadsController.add(
          PayloadModel(
            id: id,
            kind: PayloadKind.file,
            direction: PayloadDirection.received,
            name: fileName,
            sizeBytes: payloadBytes.length,
            createdAt: DateTime.now(),
          ),
        );
      }
      return;
    }

    // Text (or unknown treated as text)
    final text = utf8.decode(payloadBytes, allowMalformed: true);
    _receivedPayloadsController.add(
      PayloadModel(
        id: id,
        kind: PayloadKind.text,
        direction: PayloadDirection.received,
        text: text,
        sizeBytes: payloadBytes.length,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await stopAdvertising();
    await stopDiscovery();
    await _discoveredSub?.cancel();
    await _connSub?.cancel();
    await _notifySub?.cancel();
    await _writeReqSub?.cancel();
    await _devicesController.close();
    await _transfersController.close();
    await _connectionRequestsController.close();
    await _receivedPayloadsController.close();
  }
}
