import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/permissions.dart';
import '../core/preferences.dart';
import '../models/app_error.dart';
import '../models/device_model.dart';
import '../models/transfer_model.dart';
import '../services/transfer_service.dart';
import '../services/transfer_service_factory.dart';

/// Manages nearby device discovery, advertising, and connections.
///
/// The name race that made the other phone show "Throw" lives here: this class
/// used to advertise with whatever `_deviceName` held at that moment, which was
/// the default `'Throw Device'` until an async `DeviceInfo` lookup finished.
/// [startAdvertising] and [startDiscovery] now await [_nameReady] first.
class DeviceProvider extends ChangeNotifier {
  final TransferService _service;
  final AppPreferences _preferences;

  final Map<String, DeviceModel> _devicesMap = {};
  final List<ConnectionRequest> _pendingRequests = [];
  // Deliberately not 'Throw': in the other phone's list every install would
  // read "Throw" and the user could not tell their own two phones apart. The
  // platform name is filled in as soon as the OS answers, and this placeholder
  // only survives if that lookup fails.
  String _deviceName = _placeholderName();
  bool _nameResolved = false;
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  AppError? _error;

  StreamSubscription<DeviceModel>? _devicesSub;
  StreamSubscription<ConnectionRequest>? _requestsSub;
  bool _disposed = false;
  bool _autoStarted = false;

  /// Completes once [deviceName] is either the saved override or the OS name.
  final Completer<void> _nameReady = Completer<void>();

  static String _placeholderName() {
    if (Platform.isAndroid) return 'Android device';
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isLinux) return 'Linux PC';
    return 'Throw device';
  }

  DeviceProvider({TransferService? service, AppPreferences? preferences})
      : _service = service ?? TransferServiceFactory.instance,
        _preferences = preferences ?? AppPreferences.inMemory() {
    _devicesSub = _service.devices.listen((device) {
      final existing = _devicesMap[device.id];
      // Never let a nameless update undo a name we learned elsewhere.
      final merged = existing == null
          ? device
          : existing
              .withLearnedName(device.hasRealName ? device.name : null)
              .copyWith(
                isConnected: device.isConnected,
                channel: device.channel,
                platform: device.platform == DevicePlatform.unknown
                    ? existing.platform
                    : device.platform,
                lastSeen: device.lastSeen,
              );
      _devicesMap[device.id] = merged;
      notifyListeners();
    });
    _requestsSub = _service.connectionRequests.listen((req) {
      if (!_pendingRequests.any((r) => r.endpointId == req.endpointId)) {
        _pendingRequests.add(req);
        notifyListeners();
      }
    });
    unawaited(_resolveDeviceName());
  }

  Future<void> _resolveDeviceName() async {
    if (_disposed) return;
    // A name the user typed wins over whatever the OS reports.
    final saved = _preferences.deviceName;
    if (saved != null && saved.trim().isNotEmpty) {
      _deviceName = saved.trim();
    } else {
      try {
        final plugin = DeviceInfoPlugin();
        String? name;
        if (Platform.isAndroid) {
          final info = await plugin.androidInfo;
          final model = info.model.trim();
          final brand = info.brand.trim();
          name = model.isNotEmpty
              ? (brand.isNotEmpty &&
                      !model.toLowerCase().startsWith(brand.toLowerCase())
                  ? '$brand $model'
                  : model)
              : info.device;
        } else if (Platform.isWindows) {
          name = (await plugin.windowsInfo).computerName;
        } else if (Platform.isLinux) {
          final info = await plugin.linuxInfo;
          name = info.prettyName.isNotEmpty ? info.prettyName : info.name;
        } else if (Platform.isMacOS) {
          name = (await plugin.macOsInfo).computerName;
        }
        if (name != null && name.trim().isNotEmpty) {
          _deviceName = name.trim();
        }
      } catch (_) {
        // Keep the default; advertising still works, just less personal.
      }
    }

    _nameResolved = true;
    if (!_nameReady.isCompleted) _nameReady.complete();
    // The OS lookup can outlive the widget tree that owns this provider (a
    // test that disposes early, a screen popped mid-lookup). Notifying a
    // disposed ChangeNotifier throws.
    if (!_disposed) notifyListeners();
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

  /// True while the OS name is still being read — the UI can show the name as
  /// provisional rather than wrong.
  bool get isNameResolved => _nameResolved;

  /// Resolves to the name this install advertises, waiting for the OS lookup
  /// when necessary.
  Future<String> resolvedDeviceName() async {
    if (!_nameReady.isCompleted) {
      await _nameReady.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    }
    return _deviceName;
  }

  void setDeviceName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _deviceName) return;
    _deviceName = trimmed;
    notifyListeners();
    unawaited(_preferences.setDeviceName(trimmed));

    // If we are already visible, re-advertise under the new name so the other
    // phone does not keep showing the old one until the next discovery pass.
    if (_isAdvertising) {
      unawaited(_readvertise(trimmed));
    }
  }

  Future<void> _readvertise(String name) async {
    try {
      await _service.stopAdvertising();
      await _service.startAdvertising(deviceName: name);
    } catch (e) {
      _error = AppError.fromObject(e, fallback: AppErrorCode.discoveryFailed);
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Starts advertising and discovery together, once, at launch.
  ///
  /// A person who installs a sharing app expects it to be findable and to be
  /// looking — that is how AirDrop and LocalSend behave. Requiring a trip to
  /// Discover to flip two switches first is homework, and it was the reason a
  /// fresh install could not send anything.
  ///
  /// Never throws and never prompts twice: if the permission dialog is
  /// declined the error surfaces through [error] exactly as a manual attempt
  /// would, and the switches stay off in the UI.
  Future<void> autoStart() async {
    if (_autoStarted) return;
    _autoStarted = true;
    // Name first: whatever we advertise must be the real name, not the
    // placeholder. `resolvedDeviceName` waits for the OS lookup.
    await resolvedDeviceName();
    if (!_isAdvertising) await startAdvertising();
    // A failed advertise (permission declined) means discovery would fail the
    // same way; skip the second dialog.
    if (_error == null && !_isDiscovering) {
      await startDiscovery();
    }
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
      final name = await resolvedDeviceName();
      await _service.startAdvertising(deviceName: name);
      _isAdvertising = true;
    } catch (e) {
      _error = AppError.fromObject(e, fallback: AppErrorCode.discoveryFailed);
      _isAdvertising = false;
    }
    notifyListeners();
  }

  Future<void> stopAdvertising() async {
    try {
      await _service.stopAdvertising();
      _isAdvertising = false;
    } catch (e) {
      _error = AppError.fromObject(e, fallback: AppErrorCode.discoveryFailed);
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
      // Discovery does not imply advertising. They are two switches in the UI
      // and two calls here; the single "be findable and look" entry point is
      // [autoStart].
      await _service.startDiscovery();
      _isDiscovering = true;
    } catch (e) {
      _error = AppError.fromObject(e, fallback: AppErrorCode.discoveryFailed);
      _isDiscovering = false;
    }
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    try {
      await _service.stopDiscovery();
      _isDiscovering = false;
    } catch (e) {
      _error = AppError.fromObject(e, fallback: AppErrorCode.discoveryFailed);
    }
    notifyListeners();
  }

  Future<void> connect(DeviceModel device) async {
    _error = null;
    try {
      await _service.connect(device);
    } catch (e) {
      _error = AppError.fromObject(e, fallback: AppErrorCode.discoveryFailed);
      notifyListeners();
    }
  }

  /// Connect or drop, whichever the device's current state implies. One tap in
  /// the UI, one entry point here.
  Future<void> toggleConnection(DeviceModel device) =>
      device.isConnected ? disconnect(device) : connect(device);

  Future<void> disconnect(DeviceModel device) async {
    _error = null;
    try {
      await _service.disconnect(device.id);
    } catch (e) {
      _error = AppError.fromObject(e, fallback: AppErrorCode.discoveryFailed);
      notifyListeners();
    }
  }

  Future<void> acceptConnection(ConnectionRequest request) async {
    _pendingRequests.removeWhere((r) => r.endpointId == request.endpointId);
    notifyListeners();
    try {
      await _service.acceptConnection(request.endpointId);
    } catch (e) {
      _error = AppError.fromObject(e, fallback: AppErrorCode.discoveryFailed);
      notifyListeners();
    }
  }

  Future<void> rejectConnection(ConnectionRequest request) async {
    _pendingRequests.removeWhere((r) => r.endpointId == request.endpointId);
    notifyListeners();
    try {
      await _service.rejectConnection(request.endpointId);
    } catch (e) {
      _error = AppError.fromObject(e, fallback: AppErrorCode.discoveryFailed);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _devicesSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }
}
