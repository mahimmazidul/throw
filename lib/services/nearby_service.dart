import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import '../core/constants.dart';
import '../core/permissions.dart';
import '../models/device_model.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';
import 'transfer_service.dart';

/// Android transfer path: WiFi Direct via Google Nearby Connections.
///
/// Both ends advertise/discover [AppConstants.androidServiceId] with
/// [Strategy.P2P_CLUSTER] so Throw installs find each other and nothing
/// else does. Text travels as BYTES payloads, files as FILE payloads.
class NearbyService implements TransferService {
  NearbyService();

  final _devices = StreamController<DeviceModel>.broadcast();
  final _transfers = StreamController<TransferModel>.broadcast();
  final _requests = StreamController<ConnectionRequest>.broadcast();
  final _received = StreamController<PayloadModel>.broadcast();

  final _peers = <String, DeviceModel>{};
  final _pendingRequests = <String, ConnectionRequest>{};

  /// Drafts for outgoing payloads, queued per endpoint so two quick sends
  /// don't overwrite each other before the transport reports an id.
  final _outgoingDrafts = <String, List<_PayloadDraft>>{};

  /// In-flight sessions keyed by transport payload id.
  final _sessions = <String, _Session>{};

  /// Received FILE payloads held until the transport reports completion.
  final _incomingFiles = <String, PayloadModel>{};

  bool _advertising = false;
  bool _discovering = false;
  bool _disposed = false;

  @override
  Stream<DeviceModel> get devices => _devices.stream;

  @override
  Stream<TransferModel> get transfers => _transfers.stream;

  @override
  Stream<ConnectionRequest> get connectionRequests => _requests.stream;

  @override
  Stream<PayloadModel> get receivedPayloads => _received.stream;

  @override
  Future<void> startAdvertising({required String deviceName}) async {
    if (_advertising || _disposed) return;
    await _requirePermission();
    try {
      // Nearby advertises the system device name; deviceName is accepted
      // for interface parity with the desktop service.
      await Nearby().startAdvertising(
        AppConstants.androidServiceId,
        _connectionCallback,
        _payloadCallback,
        strategy: Strategy.P2P_CLUSTER,
      );
      _advertising = true;
    } catch (e) {
      throw TransferException('Could not start advertising', cause: e);
    }
  }

  @override
  Future<void> stopAdvertising() async {
    if (!_advertising) return;
    try {
      await Nearby().stopAdvertising();
    } catch (_) {
      // Already stopped — nothing to do.
    }
    _advertising = false;
  }

  @override
  Future<void> startDiscovery() async {
    if (_discovering || _disposed) return;
    await _requirePermission();
    try {
      await Nearby().startDiscovery(
        AppConstants.androidServiceId,
        _onEndpointFound,
        _onEndpointLost,
        strategy: Strategy.P2P_CLUSTER,
      );
      _discovering = true;
    } catch (e) {
      throw TransferException('Could not start discovery', cause: e);
    }
  }

  @override
  Future<void> stopDiscovery() async {
    if (!_discovering) return;
    try {
      await Nearby().stopDiscovery();
    } catch (_) {
      // Already stopped — nothing to do.
    }
    _discovering = false;
  }

  @override
  Future<void> connect(DeviceModel device) async {
    await _requirePermission();
    try {
      await Nearby().requestConnection(
        device.name,
        device.id,
        _connectionCallback,
      );
    } catch (e) {
      throw TransferException('Could not connect to ${device.name}',
          cause: e);
    }
  }

  @override
  Future<void> disconnect(String endpointId) async {
    try {
      await Nearby().disconnectFromEndpoint(endpointId);
    } catch (e) {
      throw TransferException('Disconnect failed', cause: e);
    }
    _publishPeer(endpointId, isConnected: false);
  }

  @override
  Future<void> acceptConnection(String endpointId) async {
    _pendingRequests.remove(endpointId);
    try {
      await Nearby().acceptConnection(endpointId, _payloadCallback);
    } catch (e) {
      throw TransferException('Accept failed', cause: e);
    }
  }

  @override
  Future<void> rejectConnection(String endpointId) async {
    _pendingRequests.remove(endpointId);
    try {
      await Nearby().rejectConnection(endpointId);
    } catch (e) {
      throw TransferException('Reject failed', cause: e);
    }
  }

  @override
  Future<void> sendText({required String endpointId, required String text}) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    _queueDraft(endpointId, _PayloadDraft(kind: PayloadKind.text, totalBytes: bytes.length));
    try {
      await Nearby().sendBytes(endpointId, bytes);
    } catch (e) {
      _dropLastDraft(endpointId);
      throw TransferException('Sending text failed', cause: e);
    }
  }

  @override
  Future<void> sendFile({required String endpointId, required File file}) async {
    if (!await file.exists()) {
      throw const TransferException('File no longer exists');
    }
    final size = await file.length();
    _queueDraft(
      endpointId,
      _PayloadDraft(
        kind: PayloadKind.file,
        name: file.uri.pathSegments.last,
        totalBytes: size,
      ),
    );
    try {
      await Nearby().sendFile(endpointId, file);
    } catch (e) {
      _dropLastDraft(endpointId);
      throw TransferException('Sending file failed', cause: e);
    }
  }

  @override
  Future<void> cancelTransfer(String transferId) async {
    final session = _sessions[transferId];
    try {
      await Nearby().cancelPayload(transferId);
    } catch (e) {
      throw TransferException('Cancel failed', cause: e);
    }
    if (session != null) {
      _publishSession(
        session,
        status: TransferStatus.cancelled,
        error: null,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopDiscovery();
    await stopAdvertising();
    await _devices.close();
    await _transfers.close();
    await _requests.close();
    await _received.close();
  }

  // ── Internals ────────────────────────────────────────────────────

  Future<void> _requirePermission() async {
    final granted = await Permissions.ensureNearbyAccess();
    if (!granted) {
      throw const TransferException('Nearby device permission denied');
    }
  }

  void _onEndpointFound(String endpointId, String endpointName) {
    final device = DeviceModel(
      id: endpointId,
      name: endpointName.isEmpty ? endpointId : endpointName,
      platform: DevicePlatform.android,
      channel: TransferChannel.wifiDirect,
      lastSeen: DateTime.now(),
    );
    _peers[endpointId] = device;
    _devices.add(device);
  }

  void _onEndpointLost(String endpointId) {
    final peer = _peers[endpointId];
    if (peer == null) return;
    final updated = peer.copyWith(
      isConnected: false,
      lastSeen: DateTime.now(),
    );
    _peers[endpointId] = updated;
    _devices.add(updated);
  }

  void _publishPeer(String endpointId, {required bool isConnected}) {
    final peer = _peers[endpointId];
    if (peer == null) return;
    final updated = peer.copyWith(
      isConnected: isConnected,
      lastSeen: DateTime.now(),
    );
    _peers[endpointId] = updated;
    _devices.add(updated);
  }

  late final ConnectionLifecycleCallback _connectionCallback =
      ConnectionLifecycleCallback(
    onConnectionInitiated: (endpointId, endpointName) {
      final request = ConnectionRequest(
        endpointId: endpointId,
        deviceName: endpointName.isEmpty ? endpointId : endpointName,
        receivedAt: DateTime.now(),
      );
      _pendingRequests[endpointId] = request;
      _requests.add(request);
    },
    onConnectionResult: (endpointId, status) {
      _pendingRequests.remove(endpointId);
      if (status == Status.SUCCESS) {
        _publishPeer(endpointId, isConnected: true);
        return;
      }
      // Surface the failure so the UI can show it — nothing fails silently.
      final peer = _peers[endpointId];
      if (peer != null) {
        _transfers.add(TransferModel(
          id: 'conn-$endpointId-${DateTime.now().microsecondsSinceEpoch}',
          peer: peer,
          payloads: const [],
          status: status == Status.REJECTED
              ? TransferStatus.rejected
              : TransferStatus.failed,
          startedAt: DateTime.now(),
          endedAt: DateTime.now(),
          error: status == Status.REJECTED ? 'rejected' : 'connection failed',
        ));
      }
    },
    onDisconnected: (endpointId) {
      _publishPeer(endpointId, isConnected: false);
      for (final session in _sessions.values.toList()) {
        if (session.endpointId == endpointId && session.model.isActive) {
          _publishSession(
            session,
            status: TransferStatus.failed,
            error: 'disconnected',
          );
        }
      }
    },
  );

  late final PayloadCallback _payloadCallback = PayloadCallback(
    onPayloadReceived: _onPayloadReceived,
    onPayloadTransferUpdate: _onPayloadTransferUpdate,
  );

  void _onPayloadReceived(String endpointId, Payload payload) {
    final peer = _peers[endpointId] ??
        DeviceModel(
          id: endpointId,
          name: endpointId,
          platform: DevicePlatform.android,
          channel: TransferChannel.wifiDirect,
          lastSeen: DateTime.now(),
        );

    if (payload.type == PayloadType.BYTES) {
      final text = utf8.decode(payload.bytes ?? const [], allowMalformed: true);
      final isClipboard = text.startsWith(_clipboardMarker);
      final body = isClipboard ? text.substring(_clipboardMarker.length) : text;
      _received.add(PayloadModel(
        id: 'rx-${payload.hashCode}-${DateTime.now().microsecondsSinceEpoch}',
        kind: isClipboard ? PayloadKind.clipboard : PayloadKind.text,
        direction: PayloadDirection.received,
        text: body,
        createdAt: DateTime.now(),
      ));
      return;
    }

    if (payload.type == PayloadType.FILE) {
      final path = payload.filePath;
      final name = path == null ? 'file' : path.split(Platform.pathSeparator).last;
      final model = PayloadModel(
        id: 'rx-${payload.hashCode}',
        kind: PayloadKind.file,
        direction: PayloadDirection.received,
        name: name,
        path: path,
        createdAt: DateTime.now(),
      );
      // Hold until SUCCESS: the bytes may still be on their way.
      _incomingFiles['${payload.id}'] = model;
      _startSession(
        payloadId: '${payload.id}',
        endpointId: endpointId,
        peer: peer,
        draft: _PayloadDraft(
          kind: PayloadKind.file,
          name: name,
          totalBytes: payload.totalBytes ?? 0,
        ),
        direction: PayloadDirection.received,
      );
    }
  }

  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    final payloadId = '${update.payloadId}';
    final session = _sessions[payloadId];

    if (update.status == PayloadStatus.SUCCESS) {
      final incoming = _incomingFiles.remove(payloadId);
      if (incoming != null) {
        _received.add(incoming);
      }
      if (session != null) {
        _publishSession(
          session,
          status: TransferStatus.completed,
          bytes: update.totalBytes ?? session.model.totalBytes,
        );
      }
      return;
    }

    if (update.status == PayloadStatus.FAILURE) {
      if (session != null) {
        _publishSession(session, status: TransferStatus.failed, error: 'transfer failed');
      }
      return;
    }

    if (update.status == PayloadStatus.CANCELED) {
      if (session != null) {
        _publishSession(session, status: TransferStatus.cancelled);
      }
      return;
    }

    // IN_PROGRESS: seed the session from a queued draft on first sight.
    if (session == null) {
      final draft = _popDraft(endpointId);
      if (draft == null) return;
      _startSession(
        payloadId: payloadId,
        endpointId: endpointId,
        peer: _peers[endpointId] ??
            DeviceModel(
              id: endpointId,
              name: endpointId,
              platform: DevicePlatform.android,
              channel: TransferChannel.wifiDirect,
              lastSeen: DateTime.now(),
            ),
        draft: draft,
        direction: PayloadDirection.sent,
      );
    }
    final current = _sessions[payloadId];
    if (current == null) return;
    _publishSession(
      current,
      status: TransferStatus.transferring,
      bytes: update.bytesTransferred,
      total: update.totalBytes,
    );
  }

  void _startSession({
    required String payloadId,
    required String endpointId,
    required DeviceModel peer,
    required _PayloadDraft draft,
    required PayloadDirection direction,
  }) {
    final payload = PayloadModel(
      id: payloadId,
      kind: draft.kind,
      direction: direction,
      name: draft.name,
      sizeBytes: draft.totalBytes,
      createdAt: DateTime.now(),
    );
    final model = TransferModel(
      id: payloadId,
      peer: peer,
      payloads: [payload],
      totalBytes: draft.totalBytes,
      status: TransferStatus.transferring,
      startedAt: DateTime.now(),
    );
    _sessions[payloadId] = _Session(endpointId: endpointId, model: model);
    _transfers.add(model);
  }

  void _publishSession(
    _Session session, {
    required TransferStatus status,
    int? bytes,
    int? total,
    String? error,
  }) {
    final model = session.model.copyWith(
      status: status,
      bytesTransferred: bytes,
      totalBytes: total,
      error: error,
      endedAt: status == TransferStatus.transferring ? null : DateTime.now(),
    );
    session.model = model;
    _transfers.add(model);
    if (!model.isActive) {
      _sessions.remove(model.id);
    }
  }

  void _queueDraft(String endpointId, _PayloadDraft draft) {
    _outgoingDrafts.putIfAbsent(endpointId, () => []).add(draft);
  }

  void _dropLastDraft(String endpointId) {
    final queue = _outgoingDrafts[endpointId];
    if (queue != null && queue.isNotEmpty) queue.removeLast();
  }

  _PayloadDraft? _popDraft(String endpointId) {
    final queue = _outgoingDrafts[endpointId];
    if (queue == null || queue.isEmpty) return null;
    return queue.removeAt(0);
  }

  /// Clipboard payloads ride the text channel with a marker prefix so the
  /// receiver can tell "copy this" apart from "read this".
  static const _clipboardMarker = 'throw-clipboard:';
}

class _PayloadDraft {
  _PayloadDraft({
    required this.kind,
    this.name,
    required this.totalBytes,
  });

  final PayloadKind kind;
  final String? name;
  final int totalBytes;
}

class _Session {
  _Session({required this.endpointId, required this.model});

  final String endpointId;
  TransferModel model;
}
