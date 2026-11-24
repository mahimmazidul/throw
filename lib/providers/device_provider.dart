import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/device_model.dart';
import '../services/transfer_service.dart';
import '../services/transfer_service_factory.dart';

/// Manages nearby device discovery, advertising, and connections.
class DeviceProvider extends ChangeNotifier {
  final TransferService _service;

  List<DeviceModel> _devices = const [];
  final List<DeviceModel> _pendingRequests = [];
  String _deviceName = AppConstants.defaultDeviceName;
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  String? _error;

  StreamSubscription<List<DeviceModel>>? _devicesSub;
  StreamSubscription<DeviceModel>? _requestsSub;

  DeviceProvider({TransferService? service})
      : _service = service ?? TransferServiceFactory.instance {
    _devicesSub = _service.discoveredDevices.listen((list) {
      _devices = List.unmodifiable(list);
      notifyListeners();
    });
    _requestsSub = _service.connectionRequests.listen((device) {
      if (!_pendingRequests.any((d) => d.id == device.id)) {
        _pendingRequests.add(device);
        notifyListeners();
      }
    });
  }

  List<DeviceModel> get devices => _devices;
  List<DeviceModel> get connectedDevices =>
      _devices.where((d) => d.isConnected).toList(growable: false);
  List<DeviceModel> get pendingRequests => List.unmodifiable(_pendingRequests);
  String get deviceName => _deviceName;
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  String? get error => _error;

  void setDeviceName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _deviceName) return;
    _deviceName = trimmed;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> startAdvertising() async {
    _error = null;
    try {
      await _service.startAdvertising(_deviceName);
      _isAdvertising = _service.isAdvertising;
    } catch (e) {
      _error = e.toString();
      _isAdvertising = false;
    }
    notifyListeners();
  }

  Future<void> stopAdvertising() async {
    try {
      await _service.stopAdvertising();
      _isAdvertising = _service.isAdvertising;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> startDiscovery() async {
    _error = null;
    try {
      await _service.startDiscovery();
      _isDiscovering = _service.isDiscovering;
    } catch (e) {
      _error = e.toString();
      _isDiscovering = false;
    }
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    try {
      await _service.stopDiscovery();
      _isDiscovering = _service.isDiscovering;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> connect(DeviceModel device) async {
    _error = null;
    try {
      await _service.connect(device);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> disconnect(DeviceModel device) async {
    _error = null;
    try {
      await _service.disconnect(device);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> acceptConnection(DeviceModel device) async {
    _pendingRequests.removeWhere((d) => d.id == device.id);
    notifyListeners();
    try {
      await _service.acceptConnection(device);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> rejectConnection(DeviceModel device) async {
    _pendingRequests.removeWhere((d) => d.id == device.id);
    notifyListeners();
    try {
      await _service.rejectConnection(device);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }
}
