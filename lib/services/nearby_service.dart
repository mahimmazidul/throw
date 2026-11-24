import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../models/device_model.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';
import 'transfer_service.dart';

/// Android transfer implementation backed by Google Nearby Connections
/// (WiFi Direct + Bluetooth LE). Only instantiated when [Platform.isAndroid].
class NearbyService implements TransferService {
  final Nearby _nearby = Nearby();
  final String _serviceId = AppConstants.androidServiceId;
  final Strategy _strategy = Strategy.P2P_CLUSTER;

  final _devicesController = StreamController<List<DeviceModel>>.broadcast();
  final _transfersController =
      StreamController<List<TransferModel>>.broadcast();
  final _incomingController = StreamController<TransferModel>.broadcast();
  final _connectionRequestsController =
      StreamController<DeviceModel>.broadcast();

  final Map<String, DeviceModel> _discoveredDevices = {};
  final Map<String, TransferModel> _transfers = {};
  final Map<int, String> _pendingFileNames = {};
  final Map<int, Payload> _receivedFilePayloads = {};

  String? _localDeviceName;
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

  void _guardPlatform() {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'NearbyService is only supported on Android.',
      );
    }
  }

  @override
  Future<void> startAdvertising(String deviceName) async {
    _guardPlatform();
    _localDeviceName = deviceName;
    if (_isAdvertising) return;

    try {
      final started = await _nearby.startAdvertising(
        deviceName,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      _isAdvertising = started;
    } catch (e) {
      _isAdvertising = false;
      rethrow;
    }
  }

  @override
  Future<void> stopAdvertising() async {
    _guardPlatform();
    if (!_isAdvertising) return;
    await _nearby.stopAdvertising();
    _isAdvertising = false;
  }

  @override
  Future<void> startDiscovery() async {
    _guardPlatform();
    if (_isDiscovering) return;

    try {
      final started = await _nearby.startDiscovery(
        _localDeviceName ?? AppConstants.defaultDeviceName,
        _strategy,
        onEndpointFound: (String id, String name, String serviceId) {
          final device = DeviceModel(
            id: id,
            name: name,
            platform: DevicePlatform.android,
            transport: TransportType.wifiDirect,
            isConnected: false,
          );
          _discoveredDevices[id] = device;
          _devicesController.add(_discoveredDevices.values.toList());
        },
        onEndpointLost: (String? id) {
          if (id != null) {
            _discoveredDevices.remove(id);
            _devicesController.add(_discoveredDevices.values.toList());
          }
        },
        serviceId: _serviceId,
      );
      _isDiscovering = started;
    } catch (e) {
      _isDiscovering = false;
      rethrow;
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _guardPlatform();
    if (!_isDiscovering) return;
    await _nearby.stopDiscovery();
    _isDiscovering = false;
  }

  @override
  Future<void> connect(DeviceModel device) async {
    _guardPlatform();
    await _nearby.requestConnection(
      _localDeviceName ?? AppConstants.defaultDeviceName,
      device.id,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
  }

  @override
  Future<void> disconnect(DeviceModel device) async {
    _guardPlatform();
    await _nearby.disconnectFromEndpoint(device.id);
    _updateDeviceConnection(device.id, false);
  }

  @override
  Future<void> acceptConnection(DeviceModel device) async {
    _guardPlatform();
    await _nearby.acceptConnection(
      device.id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  @override
  Future<void> rejectConnection(DeviceModel device) async {
    _guardPlatform();
    await _nearby.rejectConnection(device.id);
  }

  @override
  Future<TransferModel> sendPayload(
    DeviceModel target,
    PayloadModel payload,
  ) async {
    _guardPlatform();
    final transferId = DateTime.now().microsecondsSinceEpoch.toString();
    final transfer = TransferModel(
      id: transferId,
      device: target,
      payload: payload,
      direction: TransferDirection.outgoing,
      state: TransferState.transferring,
      bytesTransferred: 0,
      totalBytes: payload.sizeBytes,
      startedAt: DateTime.now(),
    );
    _transfers[transferId] = transfer;
    _transfersController.add(_transfers.values.toList());

    try {
      if (payload.type == PayloadType.text && payload.text != null) {
        final bytes = Uint8List.fromList(payload.text!.codeUnits);
        await _nearby.sendBytesPayload(target.id, bytes);
        _updateTransferState(
          transferId,
          TransferState.completed,
          bytesTransferred: bytes.length,
        );
      } else if (payload.filePath != null) {
        final payloadId = await _nearby.sendFilePayload(
          target.id,
          payload.filePath!,
        );
        final fileName = payload.fileName ?? 'file';
        final metaBytes = Uint8List.fromList('$payloadId:$fileName'.codeUnits);
        await _nearby.sendBytesPayload(target.id, metaBytes);

        _transfers[payloadId.toString()] = transfer.copyWith(
          id: payloadId.toString(),
        );
        _transfers.remove(transferId);
        _transfersController.add(_transfers.values.toList());
        return _transfers[payloadId.toString()]!;
      }
    } catch (e) {
      _updateTransferState(transferId, TransferState.failed);
      rethrow;
    }

    return _transfers[transferId]!;
  }

  @override
  Future<void> cancelTransfer(TransferModel transfer) async {
    _guardPlatform();
    final numericId = int.tryParse(transfer.id);
    if (numericId != null) {
      await _nearby.cancelPayload(numericId);
    }
    _updateTransferState(transfer.id, TransferState.cancelled);
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    final device = _discoveredDevices[id] ??
        DeviceModel(
          id: id,
          name: info.endpointName,
          platform: DevicePlatform.android,
          transport: TransportType.wifiDirect,
          isConnected: false,
        );
    _discoveredDevices[id] = device;
    _connectionRequestsController.add(device);
  }

  void _onConnectionResult(String id, Status status) {
    final connected = status == Status.CONNECTED;
    _updateDeviceConnection(id, connected);
  }

  void _onDisconnected(String id) {
    _updateDeviceConnection(id, false);
  }

  void _updateDeviceConnection(String id, bool isConnected) {
    final existing = _discoveredDevices[id];
    if (existing != null) {
      _discoveredDevices[id] = existing.copyWith(isConnected: isConnected);
      _devicesController.add(_discoveredDevices.values.toList());
    }
  }

  void _onPayloadReceived(String endpointId, Payload payload) async {
    final device = _discoveredDevices[endpointId] ??
        DeviceModel(
          id: endpointId,
          name: endpointId,
          platform: DevicePlatform.android,
          transport: TransportType.wifiDirect,
          isConnected: true,
        );

    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final text = String.fromCharCodes(payload.bytes!);
      final colonIdx = text.indexOf(':');
      if (colonIdx > 0) {
        final maybeId = int.tryParse(text.substring(0, colonIdx));
        if (maybeId != null) {
          final fileName = text.substring(colonIdx + 1);
          _pendingFileNames[maybeId] = fileName;
          await _finalizeFileIfReady(maybeId, device);
          return;
        }
      }

      final transfer = TransferModel(
        id: payload.id.toString(),
        device: device,
        payload: PayloadModel.text(text),
        direction: TransferDirection.incoming,
        state: TransferState.completed,
        bytesTransferred: payload.bytes!.length,
        totalBytes: payload.bytes!.length,
        startedAt: DateTime.now(),
      );
      _transfers[transfer.id] = transfer;
      _transfersController.add(_transfers.values.toList());
      _incomingController.add(transfer);
    } else if (payload.type == PayloadType.FILE) {
      _receivedFilePayloads[payload.id] = payload;
      final transfer = TransferModel(
        id: payload.id.toString(),
        device: device,
        payload: PayloadModel.file(
          filePath: payload.uri ?? '',
          fileName: _pendingFileNames[payload.id] ?? 'incoming_file',
          sizeBytes: 0,
        ),
        direction: TransferDirection.incoming,
        state: TransferState.transferring,
        bytesTransferred: 0,
        totalBytes: 0,
        startedAt: DateTime.now(),
      );
      _transfers[transfer.id] = transfer;
      _transfersController.add(_transfers.values.toList());
      _incomingController.add(transfer);
    }
  }

  void _onPayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) async {
    final id = update.id.toString();
    final existing = _transfers[id];
    if (existing == null) return;

    TransferState nextState = existing.state;
    if (update.status == PayloadStatus.SUCCESS) {
      nextState = TransferState.completed;
      final device = _discoveredDevices[endpointId] ?? existing.device;
      await _finalizeFileIfReady(update.id, device);
    } else if (update.status == PayloadStatus.FAILURE) {
      nextState = TransferState.failed;
    } else if (update.status == PayloadStatus.CANCELED) {
      nextState = TransferState.cancelled;
    }

    _transfers[id] = existing.copyWith(
      bytesTransferred: update.bytesTransferred,
      totalBytes: update.totalBytes,
      state: nextState,
    );
    _transfersController.add(_transfers.values.toList());
  }

  Future<void> _finalizeFileIfReady(int payloadId, DeviceModel device) async {
    final payload = _receivedFilePayloads[payloadId];
    final fileName = _pendingFileNames[payloadId];
    if (payload == null || fileName == null || payload.uri == null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final destPath = '${dir.path}/$fileName';
      await _nearby.copyFileAndDeleteOriginal(payload.uri!, destPath);
      _receivedFilePayloads.remove(payloadId);
      _pendingFileNames.remove(payloadId);

      final id = payloadId.toString();
      final existing = _transfers[id];
      if (existing != null) {
        _transfers[id] = existing.copyWith(
          payload: PayloadModel.file(
            filePath: destPath,
            fileName: fileName,
            sizeBytes: existing.totalBytes,
          ),
          state: TransferState.completed,
        );
        _transfersController.add(_transfers.values.toList());
      }
    } catch (_) {
      // Keep temp uri if move fails
    }
  }

  void _updateTransferState(
    String id,
    TransferState state, {
    int? bytesTransferred,
  }) {
    final existing = _transfers[id];
    if (existing == null) return;
    _transfers[id] = existing.copyWith(
      state: state,
      bytesTransferred: bytesTransferred ?? existing.bytesTransferred,
    );
    _transfersController.add(_transfers.values.toList());
  }

  @override
  Future<void> dispose() async {
    await stopAdvertising();
    await stopDiscovery();
    await _devicesController.close();
    await _transfersController.close();
    await _incomingController.close();
    await _connectionRequestsController.close();
  }
}
