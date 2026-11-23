import 'dart:io';

import '../models/device_model.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';

/// Anything that can move bytes between two Throw installs.
///
/// Implementations: [NearbyService] on Android (WiFi Direct) and the
/// Bluetooth service on desktop. The factory in
/// `transfer_service_factory.dart` picks one at runtime.
abstract class TransferService {
  /// Devices discovered so far; emits updates as they appear, change, and
  /// drop out of range.
  Stream<DeviceModel> get devices;

  /// Transfer sessions as they progress — one emission per state change.
  Stream<TransferModel> get transfers;

  /// Inbound connection attempts waiting for accept/reject.
  Stream<ConnectionRequest> get connectionRequests;

  /// Payloads that arrived and are ready for the user (files are complete
  /// and readable on disk when they appear here).
  Stream<PayloadModel> get receivedPayloads;

  /// Advertises this install so nearby Throw users can find it.
  Future<void> startAdvertising({required String deviceName});

  Future<void> stopAdvertising();

  /// Starts looking for other Throw installs.
  Future<void> startDiscovery();

  Future<void> stopDiscovery();

  /// Opens a connection to a discovered device.
  Future<void> connect(DeviceModel device);

  Future<void> disconnect(String endpointId);

  /// Approves a pending inbound connection (from [connectionRequests]).
  Future<void> acceptConnection(String endpointId);

  /// Declines a pending inbound connection.
  Future<void> rejectConnection(String endpointId);

  /// Sends UTF-8 text to a connected peer.
  Future<void> sendText({required String endpointId, required String text});

  /// Streams a file to a connected peer.
  Future<void> sendFile({required String endpointId, required File file});

  /// Aborts an in-flight transfer by its [TransferModel.id].
  Future<void> cancelTransfer(String transferId);

  /// Releases controllers and stops advertising/discovery. Safe to call
  /// more than once.
  Future<void> dispose();
}

/// Transport-level failure with a message meant for the UI.
class TransferException implements Exception {
  const TransferException(this.message, {this.cause});

  final String message;

  final Object? cause;

  @override
  String toString() =>
      cause == null ? message : '$message (${cause.runtimeType})';
}
