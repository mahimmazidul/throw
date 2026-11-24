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

  final _devicesController = StreamController<DeviceModel>.broadcast();
  final _transfersController = StreamController<TransferModel>.broadcast();
  final _connectionRequestsController =
      StreamController<ConnectionRequest>.broadcast();
  final _receivedPayloadsController =
      StreamController<PayloadModel>.broadcast();

  final Map<String, DeviceModel> _discoveredDevices = {};
  final Map<String, TransferModel> _transfers = {};
  final Map<int, String> _pendingFileNames = {};
  final Map<int, Payload> _receivedFilePayloads = {};

  String _localDeviceName = 'Throw Android';
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

  void _guardPlatform() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('NearbyService is only supported on Android.');
    }
  }

  @override
  Future<void> startAdvertising({required String deviceName}) async {
    _guardPlatform();
    _localDeviceName = deviceName;
    if (_isAdvertising) return;

    final started = await _nearby.startAdvertising(
      deviceName,
      _strategy,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
      serviceId: _serviceId,
    );
    _isAdvertising = started;
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

    final started = await _nearby.startDiscovery(
      _localDeviceName,
      _strategy,
      onEndpointFound: (String id, String name, String serviceId) {
        final device = DeviceModel(
          id: id,
          name: name,
          platform: DevicePlatform.android,
          channel: TransferChannel.wifiDirect,
          isConnected: false,
          lastSeen: DateTime.now(),
        );
        _discoveredDevices[id] = device;
        _devicesController.add(device);
      },
      onEndpointLost: (String? id) {
        if (id != null) {
          _discoveredDevices.remove(id);
        }
      },
      serviceId: _serviceId,
    );
    _isDiscovering = started;
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
      _localDeviceName,
      device.id,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
  }

  @override
  Future<void> disconnect(String endpointId) async {
    _guardPlatform();
    await _nearby.disconnectFromEndpoint(endpointId);
    _updateDeviceConnection(endpointId, false);
  }

  @override
  Future<void> acceptConnection(String endpointId) async {
    _guardPlatform();
    await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  @override
  Future<void> rejectConnection(String endpointId) async {
    _guardPlatform();
    await _nearby.rejectConnection(endpointId);
  }

  @override
  Future<void> sendText({
    required String endpointId,
    required String text,
  }) async {
    _guardPlatform();
    final bytes = Uint8List.fromList(text.codeUnits);
    await _nearby.sendBytesPayload(endpointId, bytes);
  }

  @override
  Future<void> sendFile({
    required String endpointId,
    required File file,
  }) async {
    _guardPlatform();
    final target = _discoveredDevices[endpointId] ??
        DeviceModel(
          id: endpointId,
          name: endpointId,
          platform: DevicePlatform.android,
          channel: TransferChannel.wifiDirect,
          isConnected: true,
          lastSeen: DateTime.now(),
        );

    final fileName = file.path.split(RegExp(r'[/\\]')).last;
    final sizeBytes = await file.length();
    final payloadId = await _nearby.sendFilePayload(endpointId, file.path);
    final metaBytes = Uint8List.fromList('$payloadId:$fileName'.codeUnits);
    await _nearby.sendBytesPayload(endpointId, metaBytes);

    final transfer = TransferModel(
      id: payloadId.toString(),
      peer: target,
      payloads: [
        PayloadModel(
          id: payloadId.toString(),
          kind: PayloadKind.file,
          direction: PayloadDirection.sent,
          name: fileName,
          path: file.path,
          sizeBytes: sizeBytes,
          createdAt: DateTime.now(),
        ),
      ],
      status: TransferStatus.transferring,
      bytesTransferred: 0,
      totalBytes: sizeBytes,
      startedAt: DateTime.now(),
    );
    _transfers[transfer.id] = transfer;
    _transfersController.add(transfer);
  }

  @override
  Future<void> cancelTransfer(String transferId) async {
    _guardPlatform();
    final numericId = int.tryParse(transferId);
    if (numericId != null) {
      await _nearby.cancelPayload(numericId);
    }
    _updateTransferStatus(transferId, TransferStatus.cancelled);
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    final device = _discoveredDevices[id] ??
        DeviceModel(
          id: id,
          name: info.endpointName,
          platform: DevicePlatform.android,
          channel: TransferChannel.wifiDirect,
          isConnected: false,
          lastSeen: DateTime.now(),
        );
    _discoveredDevices[id] = device;
    _connectionRequestsController.add(
      ConnectionRequest(
        endpointId: id,
        deviceName: info.endpointName,
        receivedAt: DateTime.now(),
      ),
    );
  }

  void _onConnectionResult(String id, Status status) {
    _updateDeviceConnection(id, status == Status.CONNECTED);
  }

  void _onDisconnected(String id) {
    _updateDeviceConnection(id, false);
  }

  void _updateDeviceConnection(String id, bool isConnected) {
    final existing = _discoveredDevices[id];
    if (existing != null) {
      final updated = existing.copyWith(
        isConnected: isConnected,
        lastSeen: DateTime.now(),
      );
      _discoveredDevices[id] = updated;
      _devicesController.add(updated);
    }
  }

  void _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final text = String.fromCharCodes(payload.bytes!);
      final colonIdx = text.indexOf(':');
      if (colonIdx > 0) {
        final maybeId = int.tryParse(text.substring(0, colonIdx));
        if (maybeId != null) {
          _pendingFileNames[maybeId] = text.substring(colonIdx + 1);
          await _finalizeFileIfReady(maybeId);
          return;
        }
      }

      _receivedPayloadsController.add(
        PayloadModel(
          id: payload.id.toString(),
          kind: PayloadKind.text,
          direction: PayloadDirection.received,
          text: text,
          sizeBytes: payload.bytes!.length,
          createdAt: DateTime.now(),
        ),
      );
    } else if (payload.type == PayloadType.FILE) {
      _receivedFilePayloads[payload.id] = payload;
    }
  }

  void _onPayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) async {
    final id = update.id.toString();
    final existing = _transfers[id];
    if (existing == null) return;

    var nextStatus = existing.status;
    if (update.status == PayloadStatus.SUCCESS) {
      nextStatus = TransferStatus.completed;
      await _finalizeFileIfReady(update.id);
    } else if (update.status == PayloadStatus.FAILURE) {
      nextStatus = TransferStatus.failed;
    } else if (update.status == PayloadStatus.CANCELED) {
      nextStatus = TransferStatus.cancelled;
    }

    final updated = existing.copyWith(
      bytesTransferred: update.bytesTransferred,
      totalBytes: update.totalBytes,
      status: nextStatus,
    );
    _transfers[id] = updated;
    _transfersController.add(updated);
  }

  Future<void> _finalizeFileIfReady(int payloadId) async {
    final payload = _receivedFilePayloads[payloadId];
    final fileName = _pendingFileNames[payloadId];
    if (payload == null || fileName == null || payload.uri == null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final destPath = '${dir.path}/$fileName';
      await _nearby.copyFileAndDeleteOriginal(payload.uri!, destPath);
      _receivedFilePayloads.remove(payloadId);
      _pendingFileNames.remove(payloadId);

      _receivedPayloadsController.add(
        PayloadModel(
          id: payloadId.toString(),
          kind: PayloadKind.file,
          direction: PayloadDirection.received,
          name: fileName,
          path: destPath,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Keep temp uri if move fails
    }
  }

  void _updateTransferStatus(String id, TransferStatus status) {
    final existing = _transfers[id];
    if (existing == null) return;
    final updated = existing.copyWith(status: status);
    _transfers[id] = updated;
    _transfersController.add(updated);
  }

  @override
  Future<void> dispose() async {
    await stopAdvertising();
    await stopDiscovery();
    await _devicesController.close();
    await _transfersController.close();
    await _connectionRequestsController.close();
    await _receivedPayloadsController.close();
  }
}
