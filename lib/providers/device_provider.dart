import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/permissions.dart';
import '../models/app_error.dart';
import '../models/device_model.dart';
import '../models/transfer_model.dart';
import '../services/transfer_service.dart';
import '../services/transfer_service_factory.dart';

/// Manages nearby device discovery, advertising, and connections.
class DeviceProvider extends ChangeNotifier {
  final TransferService _service;

  final Map<String, DeviceModel> _devicesMap = {};
  final List<ConnectionRequest> _pendingRequests = [];
  String _deviceName = 'Throw Device';
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  AppError? _error;

  StreamSubscription<DeviceModel>? _devicesSub;
  StreamSubscription<ConnectionRequest>? _requestsSub;

  DeviceProvider({TransferService? service})
      : _service = service ?? TransferServiceFactory.instance {
    _devicesSub = _service.devices.listen((device) {
      _devicesMap[device.id] = device;
      notifyListeners();
    });
    _requestsSub = _service.connectionRequests.listen((req) {
      if (!_pendingRequests.any((r) => r.endpointId == req.endpointId)) {
        _pendingRequests.add(req);
        notifyListeners();
      }
    });
    unawaited(_initializeDeviceName());
  }

  Future<void> _initializeDeviceName() async {
    try {
      final plugin = DeviceInfoPlugin();
      String? name;
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final model = info.model.trim();
        final brand = info.brand.trim();
        name = model.isNotEmpty ? (brand.isNotEmpty && !model.toLowerCase().startsWith(brand.toLowerCase()) ? '$brand $model' : model) : info.device;
      } else if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        name = info.computerName;
      } else if (Platform.isLinux) {
        final info = await plugin.linuxInfo;
        name = info.prettyName.isNotEmpty ? info.prettyName : info.name;
      } else if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        name = info.computerName;
      }
      if (name != null && name.trim().isNotEmpty) {
        _deviceName = name.trim();
        notifyListeners();
      }
    } catch (_) {
      // Keep default name.
    }
  }

  List<DeviceModel> get devices => List.unmodifiable(_devicesMap.values);
  List<DeviceModel> get connectedDevices =>
      _devicesMap.values.where((d) => d.isConnected).toList(growable: false);
  List<ConnectionRequest> get pendingRequests =>
      List.unmodifiable(_pendingRequests);
  String get deviceName => _deviceName;
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  AppError? get error => _error;

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
    final granted = await Permissions.ensureNearbyAccess();
    if (!granted) {
      _error = await Permissions.isPermanentlyDenied()
          ? const AppError(AppErrorCode.permissionBlocked)
          : const AppError(AppErrorCode.permissionDenied);
      _isAdvertising = false;
      notifyListeners();
      return;
    }
    try {
      await _service.startAdvertising(deviceName: _deviceName);
      _isAdvertising = true;
    } catch (e) {
      _error = AppError.fromObject(e);
      _isAdvertising = false;
    }
    notifyListeners();
  }

  Future<void> stopAdvertising() async {
    try {
      await _service.stopAdvertising();
      _isAdvertising = false;
    } catch (e) {
      _error = AppError.fromObject(e);
    }
    notifyListeners();
  }

  Future<void> startDiscovery() async {
    _error = null;
    final granted = await Permissions.ensureNearbyAccess();
    if (!granted) {
      _error = await Permissions.isPermanentlyDenied()
          ? const AppError(AppErrorCode.permissionBlocked)
          : const AppError(AppErrorCode.permissionDenied);
      _isDiscovering = false;
      notifyListeners();
      return;
    }
    try {
      await _service.startDiscovery();
      _isDiscovering = true;
    } catch (e) {
      _error = AppError.fromObject(e);
      _isDiscovering = false;
    }
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    try {
      await _service.stopDiscovery();
      _isDiscovering = false;
    } catch (e) {
      _error = AppError.fromObject(e);
    }
    notifyListeners();
  }

  Future<void> connect(DeviceModel device) async {
    _error = null;
    try {
      await _service.connect(device);
    } catch (e) {
      _error = AppError.fromObject(e);
      notifyListeners();
    }
  }

  Future<void> disconnect(DeviceModel device) async {
    _error = null;
    try {
      await _service.disconnect(device.id);
    } catch (e) {
      _error = AppError.fromObject(e);
      notifyListeners();
    }
  }

  Future<void> acceptConnection(ConnectionRequest request) async {
    _pendingRequests.removeWhere((r) => r.endpointId == request.endpointId);
    notifyListeners();
    try {
      await _service.acceptConnection(request.endpointId);
    } catch (e) {
      _error = AppError.fromObject(e);
      notifyListeners();
    }
  }

  Future<void> rejectConnection(ConnectionRequest request) async {
    _pendingRequests.removeWhere((r) => r.endpointId == request.endpointId);
    notifyListeners();
    try {
      await _service.rejectConnection(request.endpointId);
    } catch (e) {
      _error = AppError.fromObject(e);
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
