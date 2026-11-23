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

/// One transfer session: everything being sent or received in an exchange.
class TransferModel {
  const TransferModel({
    required this.id,
    required this.peer,
    required this.payloads,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.error,
  });

  /// Transport-level id (Nearby payload id, …).
  final String id;

  final DeviceModel peer;

  final List<PayloadModel> payloads;

  final int bytesTransferred;

  final int totalBytes;

  final TransferStatus status;

  final DateTime startedAt;

  final DateTime? endedAt;

  /// Human-readable failure reason — shown in the UI, never a stack trace.
  final String? error;

  /// 0.0–1.0; falls back to indeterminate progress before totals arrive.
  double get progress =>
      totalBytes > 0 ? (bytesTransferred / totalBytes).clamp(0.0, 1.0) : 0.0;

  /// True while the transfer still owns resources.
  bool get isActive =>
      status == TransferStatus.pending ||
      status == TransferStatus.connecting ||
      status == TransferStatus.transferring;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  TransferModel copyWith({
    String? id,
    DeviceModel? peer,
    List<PayloadModel>? payloads,
    int? bytesTransferred,
    int? totalBytes,
    TransferStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    String? error,
  }) {
    return TransferModel(
      id: id ?? this.id,
      peer: peer ?? this.peer,
      payloads: payloads ?? this.payloads,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) => other is TransferModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TransferModel($id, ${status.name}, $progress)';
}

/// An inbound connection waiting for a human decision (bottom sheet).
class ConnectionRequest {
  const ConnectionRequest({
    required this.endpointId,
    required this.deviceName,
    required this.receivedAt,
  });

  final String endpointId;

  final String deviceName;

  final DateTime receivedAt;

  @override
  bool operator ==(Object other) =>
      other is ConnectionRequest && other.endpointId == endpointId;

  @override
  int get hashCode => endpointId.hashCode;
}
