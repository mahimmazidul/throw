import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import '../core/constants.dart';
import '../core/incoming_store.dart';
import '../core/transfer_stats.dart';
import '../models/device_model.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';
import 'transfer_service.dart';

/// Android transfer implementation backed by Google Nearby Connections
/// (WiFi Direct + Bluetooth LE). Only instantiated when [Platform.isAndroid].
///
/// The wire format carries the sender's name in a small JSON metadata blob
/// (`THROW_META:{…}`) instead of the previous `THROW_FILE_META:<id>:<name>`
/// string. Two consequences:
///
///  * the receiving phone shows "Mahim's Pixel", not "Throw", because the name
///    travels with the payload rather than depending on advertisement;
///  * a file name containing ':' (legal on Android) no longer breaks the parse.
class NearbyService implements TransferService {
  NearbyService({IncomingStore? store}) : _store = store ?? IncomingStore();

  final IncomingStore _store;

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
  final Map<String, TransferRateTracker> _rateTrackers = {};

  /// Metadata announced before a file payload, keyed by payload id.
  final Map<int, _IncomingMeta> _pendingMeta = {};

  /// File payloads whose bytes are still on disk in the Nearby cache.
  final Map<int, Payload> _receivedFilePayloads = {};

  String _localDeviceName = 'Throw';

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
  String get localDeviceName => _localDeviceName;

  void _guardPlatform() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('NearbyService is only supported on Android.');
    }
  }

  @override
  Future<void> startAdvertising({required String deviceName}) async {
    _guardPlatform();
    if (deviceName.trim().isNotEmpty) _localDeviceName = deviceName.trim();
    if (_isAdvertising) return;

    final started = await _nearby.startAdvertising(
      _localDeviceName,
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
          isConnected: _discoveredDevices[id]?.isConnected ?? false,
          lastSeen: DateTime.now(),
        );
        _upsertDevice(device);
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
    // BUG FIX: `text.codeUnits` truncates every code unit to one byte, so any
    // non-ASCII character (Bangla, emoji) arrived mangled. UTF-8 is what
    // String.fromCharCodes on the other side expects for ASCII and what the
    // metadata declares for everything else.
    final bytes = Uint8List.fromList(utf8.encode(text));
    await _nearby.sendBytesPayload(endpointId, bytes);
  }

  @override
  Future<void> sendFile({
    required String endpointId,
    required File file,
    String? displayName,
    int? sizeBytes,
  }) async {
    _guardPlatform();
    final target = _peerFor(endpointId);
    final fileName = displayName ?? file.path.split(RegExp(r'[/\\]')).last;
    final size = sizeBytes ?? await file.length();

    final payloadId = await _nearby.sendFilePayload(endpointId, file.path);
    final meta = Uint8List.fromList(
      utf8.encode(
        'THROW_META:${jsonEncode({
          'id': payloadId,
          'name': fileName,
          'size': size,
          'from': _localDeviceName,
        })}',
      ),
    );
    await _nearby.sendBytesPayload(endpointId, meta);

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
          sizeBytes: size,
          createdAt: DateTime.now(),
        ),
      ],
      status: TransferStatus.transferring,
      bytesTransferred: 0,
      totalBytes: size,
      direction: TransferDirection.sending,
      startedAt: DateTime.now(),
    );
    _transfers[transfer.id] = transfer;
    _rateTrackers[transfer.id] = TransferRateTracker();
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
    _upsertDevice(device);
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
      _upsertDevice(existing.copyWith(
        isConnected: isConnected,
        lastSeen: DateTime.now(),
      ));
    }
  }

  void _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final text = utf8.decode(payload.bytes!, allowMalformed: true);
      const metaPrefix = 'THROW_META:';
      if (text.startsWith(metaPrefix)) {
        final _IncomingMeta? meta = _parseMeta(
          text.substring(metaPrefix.length),
          fallbackId: payload.id,
        );
        if (meta != null) {
          _pendingMeta[meta.payloadId] = meta;
          _learnName(endpointId, meta.from);
          await _finalizeFileIfReady(meta.payloadId);
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
      await _finalizeFileIfReady(payload.id);
    }
  }

  /// Parses the metadata blob. Returns null for anything that is not ours, so
  /// a plain text message that happens to start with the prefix is not eaten.
  _IncomingMeta? _parseMeta(String body, {required int fallbackId}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final id = decoded['id'] as int? ?? fallbackId;
      final name = decoded['name'] as String?;
      if (name == null || name.isEmpty) return null;
      return _IncomingMeta(
        payloadId: id,
        fileName: name,
        sizeBytes: (decoded['size'] as int?) ?? 0,
        from: decoded['from'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  void _learnName(String endpointId, String? name) {
    if (name == null || name.trim().isEmpty) return;
    final existing = _discoveredDevices[endpointId];
    if (existing == null) {
      _upsertDevice(DeviceModel(
        id: endpointId,
        name: name,
        platform: DevicePlatform.android,
        channel: TransferChannel.wifiDirect,
        isConnected: true,
        lastSeen: DateTime.now(),
      ));
    } else {
      _upsertDevice(existing.withLearnedName(name).copyWith(
            isConnected: true,
            lastSeen: DateTime.now(),
          ));
    }
  }

  void _onPayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) async {
    final id = update.id.toString();
    var existing = _transfers[id];
    if (existing == null) {
      // Incoming transfer we have not been told about yet (metadata can arrive
      // after the first update). Create it so progress has somewhere to go.
      final meta = _pendingMeta[update.id];
      final payload = _receivedFilePayloads[update.id];
      if (meta != null || payload != null) {
        existing = _ensureIncomingTransfer(endpointId, update.id);
      }
    }
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

    final tracker = _rateTrackers.putIfAbsent(id, TransferRateTracker.new)
      ..sample(update.bytesTransferred);

    final updated = existing.copyWith(
      bytesTransferred: update.bytesTransferred,
      totalBytes: update.totalBytes > 0 ? update.totalBytes : existing.totalBytes,
      speedBytesPerSecond: tracker.bytesPerSecond,
      status: nextStatus,
    );
    _transfers[id] = updated;
    _transfersController.add(updated);
  }

  /// Moves the finished Nearby cache file into the shared Incoming folder.
  ///
  /// This is the step that answers "saved where": the old code copied into
  /// `getApplicationDocumentsDirectory()`, which on Android is inside the
  /// app's private data directory — invisible to the user.
  Future<void> _finalizeFileIfReady(int payloadId) async {
    final payload = _receivedFilePayloads[payloadId];
    final meta = _pendingMeta[payloadId];
    if (payload == null || payload.uri == null) return;

    // The real name only ever comes from our metadata blob; `Payload` has
    // no name field.
    final fileName = meta?.fileName ?? 'received_file';

    try {
      final path = await _store.pathFor(fileName);
      await _nearby.copyFileAndDeleteOriginal(payload.uri!, path);

      _receivedFilePayloads.remove(payloadId);
      _pendingMeta.remove(payloadId);
      final id = payloadId.toString();
      _rateTrackers.remove(id);

      final existing = _transfers[id];
      if (existing != null) {
        _transfers[id] = existing.copyWith(
          status: TransferStatus.completed,
          bytesTransferred: existing.totalBytes > 0
              ? existing.totalBytes
              : _sizeOf(path),
          speedBytesPerSecond: estimateRate(
            existing.totalBytes > 0 ? existing.totalBytes : _sizeOf(path),
            existing.duration,
          ),
          endedAt: DateTime.now(),
          savedPath: path,
        );
        _transfersController.add(_transfers[id]!);
      }

      _receivedPayloadsController.add(
        PayloadModel(
          id: id,
          kind: PayloadKind.file,
          direction: PayloadDirection.received,
          name: fileName,
          path: path,
          sizeBytes: existing?.totalBytes ?? _sizeOf(path),
          createdAt: DateTime.now(),
          senderName: meta?.from,
        ),
      );
    } catch (e) {
      // The file is still in the Nearby cache and, depending on the OEM,
      // readable. Report the fallback path rather than nothing.
      _pendingMeta.remove(payloadId);
      _receivedFilePayloads.remove(payloadId);
      _fail(payloadId.toString(), e);
    }
  }

  int _sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  TransferModel _ensureIncomingTransfer(String endpointId, int payloadId) {
    final id = payloadId.toString();
    final existing = _transfers[id];
    if (existing != null) return existing;

    final meta = _pendingMeta[payloadId];
    final transfer = TransferModel(
      id: id,
      peer: _peerFor(endpointId, senderName: meta?.from),
      payloads: [
        PayloadModel(
          id: id,
          kind: PayloadKind.file,
          direction: PayloadDirection.received,
          name: meta?.fileName,
          sizeBytes: meta?.sizeBytes ?? 0,
          createdAt: DateTime.now(),
          senderName: meta?.from,
        ),
      ],
      status: TransferStatus.transferring,
      totalBytes: meta?.sizeBytes ?? 0,
      direction: TransferDirection.receiving,
      startedAt: DateTime.now(),
    );
    _transfers[id] = transfer;
    _rateTrackers[id] = TransferRateTracker();
    _transfersController.add(transfer);
    return transfer;
  }

  DeviceModel _peerFor(String endpointId, {String? senderName}) {
    final known = _discoveredDevices[endpointId];
    if (known != null) {
      return senderName == null ? known : known.withLearnedName(senderName);
    }
    return DeviceModel(
      id: endpointId,
      name: senderName ?? '',
      platform: DevicePlatform.android,
      channel: TransferChannel.wifiDirect,
      isConnected: true,
      lastSeen: DateTime.now(),
    );
  }

  void _updateTransferStatus(String id, TransferStatus status) {
    final existing = _transfers[id];
    if (existing == null) return;
    _rateTrackers.remove(id);
    _transfers[id] = existing.copyWith(
      status: status,
      speedBytesPerSecond: estimateRate(
        existing.bytesTransferred,
        existing.duration,
      ),
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
    await _devicesController.close();
    await _transfersController.close();
    await _connectionRequestsController.close();
    await _receivedPayloadsController.close();
  }
}

class _IncomingMeta {
  const _IncomingMeta({
    required this.payloadId,
    required this.fileName,
    required this.sizeBytes,
    this.from,
  });

  final int payloadId;
  final String fileName;
  final int sizeBytes;
  final String? from;
}
