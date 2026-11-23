import 'dart:io';

import 'transfer_service.dart';

/// Builds the [TransferService] for the current platform.
///
/// Android talks WiFi Direct through the Nearby service; Windows and Linux
/// talk Bluetooth. Branches stay guarded until each concrete service lands
/// so the app fails loudly instead of picking a half-wired path.
TransferService createTransferService() {
  if (Platform.isAndroid) {
    throw const TransferException(
      'Android transfer service is not wired up yet',
    );
  }
  throw const TransferException(
    'Desktop transfer service is not wired up yet',
  );
}
