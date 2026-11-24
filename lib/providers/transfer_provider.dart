import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/device_model.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';
import '../services/transfer_service.dart';
import '../services/transfer_service_factory.dart';

/// Manages active and completed file/text transfers.
class TransferProvider extends ChangeNotifier {
  final TransferService _service;

  final Map<String, TransferModel> _transfersMap = {};
  final List<PayloadModel> _receivedPayloads = [];
  String? _error;

  StreamSubscription<TransferModel>? _transfersSub;
  StreamSubscription<PayloadModel>? _payloadsSub;

  TransferProvider({TransferService? service})
      : _service = service ?? TransferServiceFactory.instance {
    _transfersSub = _service.transfers.listen((transfer) {
      _transfersMap[transfer.id] = transfer;
      notifyListeners();
    });
    _payloadsSub = _service.receivedPayloads.listen((payload) {
      _receivedPayloads.add(payload);
      notifyListeners();
    });
  }

  List<TransferModel> get transfers => List.unmodifiable(_transfersMap.values);
  List<TransferModel> get activeTransfers =>
      _transfersMap.values.where((t) => t.isActive).toList(growable: false);
  List<PayloadModel> get receivedPayloads =>
      List.unmodifiable(_receivedPayloads);
  String? get error => _error;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> sendText(DeviceModel target, String text) async {
    if (text.trim().isEmpty) return;
    _error = null;
    try {
      await _service.sendText(endpointId: target.id, text: text);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendFile(
    DeviceModel target, {
    required String filePath,
    required String fileName,
    required int sizeBytes,
  }) async {
    _error = null;
    try {
      await _service.sendFile(endpointId: target.id, file: File(filePath));
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> cancelTransfer(TransferModel transfer) async {
    _error = null;
    try {
      await _service.cancelTransfer(transfer.id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _transfersSub?.cancel();
    _payloadsSub?.cancel();
    super.dispose();
  }
}
