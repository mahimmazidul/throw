import 'device_model.dart';
import 'payload_model.dart';

/// Lifecycle of a transfer or connection attempt.
enum TransferStatus {
  pending,
  connecting,
  transferring,
  completed,
  failed,
  cancelled,
  rejected,
}

/// Which way the bytes are moving.
///
/// The UI needs this to say "Receiving from" instead of "Sending to", and to
/// word the receipt correctly. It used to be inferred from the payload, which
/// broke the moment a payload listed both directions.
enum TransferDirection { sending, receiving }

/// One transfer session: everything being sent or received in an exchange.
class TransferModel {
  const TransferModel({
    required this.id,
    required this.peer,
    required this.payloads,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.speedBytesPerSecond = 0,
    this.direction = TransferDirection.sending,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.error,
    this.savedPath,
  });

  /// Transport-level id (Nearby payload id, …).
  final String id;

  final DeviceModel peer;

  final List<PayloadModel> payloads;

  final int bytesTransferred;

  final int totalBytes;

  /// Measured rate in bytes/second; 0 until the first usable sample.
  final double speedBytesPerSecond;

  final TransferDirection direction;

  final TransferStatus status;

  final DateTime startedAt;

  final DateTime? endedAt;

  /// Human-readable failure reason — shown in the UI, never a stack trace.
  final String? error;

  /// Where a received file ended up on disk, once known. This is what the
  /// receipt reads from; a completed transfer without it can still say
  /// "saved" but not "where", and the UI says exactly that.
  final String? savedPath;

  bool get isSending => direction == TransferDirection.sending;
  bool get isReceiving => direction == TransferDirection.receiving;

  /// 0.0–1.0; falls back to indeterminate progress before totals arrive.
  double get progress => totalBytes > 0
      ? (bytesTransferred / totalBytes).clamp(0.0, 1.0)
      : 0.0;

  /// Bytes still to move.
  int get remainingBytes =>
      totalBytes > bytesTransferred ? totalBytes - bytesTransferred : 0;

  /// True while the transfer still owns resources.
  bool get isActive =>
      status == TransferStatus.pending ||
      status == TransferStatus.connecting ||
      status == TransferStatus.transferring;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  /// What the row is called: the file name, the text, or a generic label.
  String get title {
    if (payloads.isEmpty) return 'Transfer';
    final first = payloads.first;
    final name = first.name;
    if (first.kind == PayloadKind.file && name != null && name.isNotEmpty) {
      return name;
    }
    if (payloads.length > 1) return '${payloads.length} items';
    return first.label.isEmpty ? 'Transfer' : first.label;
  }

  int get payloadCount => payloads.length;

  TransferModel copyWith({
    String? id,
    DeviceModel? peer,
    List<PayloadModel>? payloads,
    int? bytesTransferred,
    int? totalBytes,
    double? speedBytesPerSecond,
    TransferDirection? direction,
    TransferStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    String? error,
    String? savedPath,
  }) {
    return TransferModel(
      id: id ?? this.id,
      peer: peer ?? this.peer,
      payloads: payloads ?? this.payloads,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      error: error ?? this.error,
      savedPath: savedPath ?? this.savedPath,
    );
  }

  @override
  bool operator ==(Object other) => other is TransferModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TransferModel($id, ${status.name}, $progress)';
}

/// An inbound connection waiting for a human decision.
///
/// `deviceName` can be empty when a transport never learned one (BLE has no
/// name on the receiving side before a HELLO). [displayName] covers that.
class ConnectionRequest {
  const ConnectionRequest({
    required this.endpointId,
    required this.deviceName,
    required this.receivedAt,
  });

  final String endpointId;

  final String deviceName;

  final DateTime receivedAt;

  String get displayName {
    if (deviceName.trim().isEmpty) {
      return DeviceModel(
        id: endpointId,
        name: '',
        platform: DevicePlatform.unknown,
        channel: TransferChannel.bluetooth,
        lastSeen: receivedAt,
      ).displayName;
    }
    return DeviceModel(
      id: endpointId,
      name: deviceName,
      platform: DevicePlatform.unknown,
      channel: TransferChannel.bluetooth,
      lastSeen: receivedAt,
    ).displayName;
  }

  @override
  bool operator ==(Object other) =>
      other is ConnectionRequest && other.endpointId == endpointId;

  @override
  int get hashCode => endpointId.hashCode;
}
