import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import '../core/constants.dart';
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

  static final UUID _serviceUuid = UUID.fromString(AppConstants.bleServiceUuid);
  static final UUID _txCharUuid =
      UUID.fromString(AppConstants.bleTxCharacteristicUuid);
  static final UUID _rxCharUuid =
      UUID.fromString(AppConstants.bleRxCharacteristicUuid);

  final _devicesController = StreamController<List<DeviceModel>>.broadcast();
  final _transfersController =
      StreamController<List<TransferModel>>.broadcast();
  final _incomingController = StreamController<TransferModel>.broadcast();
  final _connectionRequestsController =
      StreamController<DeviceModel>.broadcast();

  final Map<String, DeviceModel> _discoveredDevices = {};
  final Map<String, Peripheral> _peripherals = {};
  final Map<String, GATTCharacteristic> _txCharacteristics = {};
  final Map<String, TransferModel> _transfers = {};

  StreamSubscription<DiscoveredEventArgs>? _discoveredSub;
  StreamSubscription<PeripheralConnectionStateChangedEventArgs>? _connSub;
  StreamSubscription<GATTCharacteristicNotifiedEventArgs>? _notifySub;
  StreamSubscription<GATTCharacteristicWriteRequestedEventArgs>? _writeReqSub;

  bool _isAdvertising = false;
  bool _isDiscovering = false;

  @override
  Stream<List<DeviceModel>> get discoveredDevices => _devicesController.stream;

  @override
  Stream<List<TransferModel>> get transfers => _transfersController.stream;

  @override
  Stream<TransferModel> get incomingTransfers => _incomingController.stream;

  @override
  Stream<DeviceModel> get connectionRequests =>
      _connectionRequestsController.stream;

  @override
  bool get isAdvertising => _isAdvertising;

  @override
  bool get isDiscovering => _isDiscovering;

  @override
  Future<void> startAdvertising(String deviceName) async {
    if (_peripheral == null) {
      // Linux does not support BLE peripheral/advertising in bluetooth_low_energy.
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
        platform: DevicePlatform.windows,
        channel: TransferChannel.bluetooth, lastSeen: DateTime.now(),
        isConnected: _discoveredDevices[id]?.isConnected ?? false,
      );
      _discoveredDevices[id] = device;
      _devicesController.add(_discoveredDevices.values.toList());
    });

    _connSub ??= _central.connectionStateChanged.listen((event) {
      final id = event.peripheral.uuid.toString();
      final connected = event.state == ConnectionState.connected;
      final existing = _discoveredDevices[id];
      if (existing != null) {
        _discoveredDevices[id] = existing.copyWith(isConnected: connected);
        _devicesController.add(_discoveredDevices.values.toList());
      }
    });

    _notifySub ??= _central.characteristicNotified.listen((event) {
      _handleIncomingBytes(event.peripheral.uuid.toString(), event.value);
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
  }

  @override
  Future<void> disconnect(DeviceModel device) async {
    final peripheral = _peripherals[device.id];
    if (peripheral != null) {
      await _central.disconnect(peripheral);
    }
    _txCharacteristics.remove(device.id);
  }

  @override
  Future<void> acceptConnection(DeviceModel device) async {
    // BLE connections are accepted at the GATT layer.
  }

  @override
  Future<void> rejectConnection(DeviceModel device) async {
    await disconnect(device);
  }

  @override
  Future<TransferModel> sendPayload(
    DeviceModel target,
    PayloadModel payload,
  ) async {
    final peripheral = _peripherals[target.id];
    final txChar = _txCharacteristics[target.id];
    if (peripheral == null || txChar == null) {
      throw StateError('Device ${target.id} is not connected.');
    }

    final Uint8List data;
    if (payload.type == PayloadType.text && payload.text != null) {
      data = Uint8List.fromList(utf8.encode(payload.text!));
    } else if (payload.filePath != null) {
      data = await File(payload.filePath!).readAsBytes();
    } else {
      throw ArgumentError('Payload has neither text nor filePath.');
    }

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
    _transfersController.add(_transfers.values.toList());

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
        _transfersController.add(_transfers.values.toList());
      }

      transfer = transfer.copyWith(
        status: TransferStatus.completed,
        bytesTransferred: data.length,
      );
      _transfers[transferId] = transfer;
      _transfersController.add(_transfers.values.toList());
      return transfer;
    } catch (e) {
      transfer = transfer.copyWith(state: TransferStatus.failed);
      _transfers[transferId] = transfer;
      _transfersController.add(_transfers.values.toList());
      rethrow;
    }
  }

  @override
  Future<void> cancelTransfer(TransferModel transfer) async {
    final existing = _transfers[transfer.id];
    if (existing != null) {
      _transfers[transfer.id] =
          existing.copyWith(state: TransferStatus.cancelled);
      _transfersController.add(_transfers.values.toList());
    }
  }

  void _handleIncomingBytes(String deviceId, Uint8List bytes) {
    final device = _discoveredDevices[deviceId] ??
        DeviceModel(
          id: deviceId,
          name: deviceId,
          platform: DevicePlatform.windows,
          channel: TransferChannel.bluetooth, lastSeen: DateTime.now(),
          isConnected: true,
        );

    final text = utf8.decode(bytes, allowMalformed: true);
    final transfer = TransferModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      peer: device,
      payload: PayloadModel(id: DateTime.now().microsecondsSinceEpoch.toString(), type: PayloadType.text, text: text, sizeBytes: text.length),
      
      status: TransferStatus.completed,
      bytesTransferred: bytes.length,
      totalBytes: bytes.length,
      startedAt: DateTime.now(),
    );
    _transfers[transfer.id] = transfer;
    _transfersController.add(_transfers.values.toList());
    _incomingController.add(transfer);
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
    await _incomingController.close();
    await _connectionRequestsController.close();
  }
}
