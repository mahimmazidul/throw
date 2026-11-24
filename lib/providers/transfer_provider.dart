import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/temp_files.dart';
import '../models/app_error.dart';
import '../models/device_model.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';
import '../services/transfer_service.dart';
import '../services/transfer_service_factory.dart';

/// Manages active and completed file/text transfers.
///
/// Sending to several devices at once is handled here rather than in the
/// service: every target gets its own `sendFile`/`sendText` call, so each one
/// has independent progress and failure. One unreachable phone must not stop
/// the file going to the other two, and the UI shows which failed.
class TransferProvider extends ChangeNotifier {
  final TransferService _service;
  final TempFileRegistry _tempFiles;

  final Map<String, TransferModel> _transfersMap = {};
  final List<PayloadModel> _receivedPayloads = [];
  AppError? _error;

  /// Cache copies currently being read, with the number of live sends using
  /// each. Sending one file to three devices must not let the first device to
  /// fail delete the bytes the other two are still streaming, so a copy is
  /// only deleted when its count reaches zero.
  final Map<String, int> _leases = {};

  StreamSubscription<TransferModel>? _transfersSub;
  StreamSubscription<PayloadModel>? _payloadsSub;

  TransferProvider({TransferService? service, TempFileRegistry? tempFiles})
      : _service = service ?? TransferServiceFactory.instance,
        _tempFiles = tempFiles ?? TempFileRegistry() {
    _transfersSub = _service.transfers.listen((transfer) {
      _transfersMap[transfer.id] = transfer;
      notifyListeners();
    });
    _payloadsSub = _service.receivedPayloads.listen((payload) {
      // A retried or replayed payload id must not duplicate the receipt.
      if (_receivedPayloads.any((p) => p.id == payload.id)) return;
      _receivedPayloads.add(payload);
      notifyListeners();
    });
  }

  List<TransferModel> get transfers => List.unmodifiable(_transfersMap.values);
  List<TransferModel> get activeTransfers =>
      _transfersMap.values.where((t) => t.isActive).toList(growable: false);

  /// Completed exchanges, newest first — what "Recent" means to a person.
  List<TransferModel> get finishedTransfers {
    final list =
        _transfersMap.values.where((t) => !t.isActive).toList(growable: false);
    list.sort((a, b) => (b.endedAt ?? b.startedAt)
        .compareTo(a.endedAt ?? a.startedAt));
    return list;
  }

  List<PayloadModel> get receivedPayloads => List.unmodifiable(_receivedPayloads);

  /// Newest receipt first.
  PayloadModel? get latestReceipt =>
      _receivedPayloads.isEmpty ? null : _receivedPayloads.last;

  AppError? get error => _error;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Sends [text] to one device.
  Future<bool> sendText(DeviceModel target, String text) async {
    if (text.trim().isEmpty) return false;
    return _sendOne(target, () async {
      await _service.sendText(endpointId: target.id, text: text);
    });
  }

  /// Sends [text] to every device in [targets]. Returns how many succeeded.
  Future<int> sendTextTo(List<DeviceModel> targets, String text) =>
      _fanOut(targets, (target) => sendText(target, text));

  /// Sends one file to one device.
  Future<bool> sendFile(
    DeviceModel target, {
    required String filePath,
    required String fileName,
    required int sizeBytes,
  }) {
    return _sendOne(target, () async {
      final leased = await _lease(filePath);
      try {
        await _service.sendFile(
          endpointId: target.id,
          file: File(filePath),
          displayName: fileName,
          sizeBytes: sizeBytes,
        );
      } finally {
        // Terminal whatever happened: the bytes were either all sent, or the
        // transfer failed and the copy is dead weight. Failure used to leak the
        // whole file; this is the line that stops it.
        if (leased) await _unlease(filePath);
      }
    });
  }

  /// Sends one file to every target. Each device gets its own transfer row;
  /// a failure on one is recorded on that row and does not abort the others.
  Future<int> sendFileTo(
    List<DeviceModel> targets, {
    required String filePath,
    required String fileName,
    required int sizeBytes,
  }) =>
      _fanOut(
        targets,
        (target) => sendFile(
          target,
          filePath: filePath,
          fileName: fileName,
          sizeBytes: sizeBytes,
        ),
      );

  /// Sends several files to every target, in order, reporting how many
  /// device×file pairs succeeded.
  Future<int> sendFilesTo(
    List<DeviceModel> targets, {
    required List<({String path, String name, int size})> files,
  }) async {
    var sent = 0;
    for (final file in files) {
      sent += await sendFileTo(
        targets,
        filePath: file.path,
        fileName: file.name,
        sizeBytes: file.size,
      );
    }
    return sent;
  }

  Future<int> _fanOut(
    List<DeviceModel> targets,
    Future<bool> Function(DeviceModel) send,
  ) async {
    if (targets.isEmpty) return 0;
    final results = await Future.wait(targets.map(send));
    return results.where((ok) => ok).length;
  }

  /// Takes ownership of a cache copy and counts one live send against it.
  /// Returns false for a path the user owns, which is never deleted.
  Future<bool> _lease(String path) async {
    if (!await _tempFiles.takeOwnership(path)) return false;
    _leases[path] = (_leases[path] ?? 0) + 1;
    return true;
  }

  /// Ends one send's claim on [path]; deletes the copy when nobody else needs
  /// it.
  Future<void> _unlease(String path) async {
    final remaining = (_leases[path] ?? 1) - 1;
    if (remaining > 0) {
      _leases[path] = remaining;
      return;
    }
    _leases.remove(path);
    await _tempFiles.releaseAll([path]);
  }

  Future<bool> _sendOne(
    DeviceModel target,
    Future<void> Function() action,
  ) async {
    _error = null;
    try {
      await action();
      return true;
    } catch (e) {
      // No "unknown" bucket here: if a send failed, it failed while sending.
      _error = AppError.fromObject(e, fallback: AppErrorCode.transferFailed);
      notifyListeners();
      return false;
    }
  }

  Future<void> cancelTransfer(TransferModel transfer) async {
    _error = null;
    try {
      await _service.cancelTransfer(transfer.id);
    } catch (e) {
      // No "unknown" bucket here: if a send failed, it failed while sending.
      _error = AppError.fromObject(e, fallback: AppErrorCode.transferFailed);
      notifyListeners();
    }
  }

  /// Clears the locally held history for finished rows. The files themselves
  /// are untouched — this list is a log, not the storage.
  void clearHistory() {
    _transfersMap.removeWhere((_, t) => !t.isActive);
    notifyListeners();
  }

  @override
  void dispose() {
    // Rows are gone; nothing can be mid-send once this provider is disposed.
    final stranded = _leases.keys.toList();
    _leases.clear();
    if (stranded.isNotEmpty) unawaited(_tempFiles.releaseAll(stranded));
    _transfersSub?.cancel();
    _payloadsSub?.cancel();
    super.dispose();
  }
}
