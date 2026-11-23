import 'dart:io';

import 'nearby_service.dart';
import 'transfer_service.dart';

/// Builds the [TransferService] for the current platform.
///
/// Android talks WiFi Direct through [NearbyService]. Windows and Linux
/// will talk Bluetooth once the desktop service lands — that branch stays
/// guarded until Commit 17 so the app fails loudly instead of picking a
/// half-wired path.
TransferService createTransferService() {
  if (Platform.isAndroid) {
    return NearbyService();
  }
  throw const TransferException(
    'Desktop transfer service is not wired up yet',
  );
}
