import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/device_model.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';
import '../services/transfer_service.dart';
import '../services/transfer_service_factory.dart';

/// Manages active and completed file/text transfers.
class TransferProvider extends ChangeNotifier {
  final TransferService _service;

  List<TransferModel> _transfers = const [];
  final List<TransferModel> _incomingQueue = [];
  String? _error;

  StreamSubscription<List<TransferModel>>? _transfersSub;
  StreamSubscription<TransferModel>? _incomingSub;

  TransferProvider({TransferService? service})
      : _service = service ?? TransferServiceFactory.instance {
    _transfersSub = _service.transfers.listen((list) {
      _transfers = List.unmodifiable(list);
      notifyListeners();
    });
    _incomingSub = _service.incomingTransfers.listen((transfer) {
      _incomingQueue.add(transfer);
      notifyListeners();
    });
  }

  List<TransferModel> get transfers => _transfers;
  List<TransferModel> get activeTransfers => _transfers
      .where((t) => t.isActive)
      .toList(growable: false);
  List<TransferModel> get incomingQueue => List.unmodifiable(_incomingQueue);
  String? get error => _error;

  void dismissIncoming(String transferId) {
    _incomingQueue.removeWhere((t) => t.id == transferId);
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<TransferModel?> sendText(DeviceModel target, String text) async {
    if (text.trim().isEmpty) return null;
    return sendPayload(
      target,
      PayloadModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: PayloadType.text,
        text: text,
        sizeBytes: text.length,
      ),
    );
  }

  Future<TransferModel?> sendFile(
    DeviceModel target, {
    required String filePath,
    required String fileName,
    required int sizeBytes,
  }) async {
    return sendPayload(
      target,
      PayloadModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: PayloadType.file,
        filePath: filePath,
        fileName: fileName,
        sizeBytes: sizeBytes,
      ),
    );
  }

  Future<TransferModel?> sendPayload(
    DeviceModel target,
    PayloadModel payload,
  ) async {
    _error = null;
    try {
      return await _service.sendPayload(target, payload);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> cancelTransfer(TransferModel transfer) async {
    _error = null;
    try {
      await _service.cancelTransfer(transfer);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _transfersSub?.cancel();
    _incomingSub?.cancel();
    super.dispose();
  }
}
