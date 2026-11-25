import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';

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
class DeviceProvider extends ChangeNotifier with WidgetsBindingObserver {
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

  /// Fires while a scan is meant to be running, to re-arm one that has died.
  ///
  /// Android stops WiFi Direct discovery on its own — when the app is
  /// backgrounded, when another app takes the radio, when a connection tears
  /// down the group. The plugin reports only endpoints coming and going, never
  /// that discovery itself stopped, so without this the app would sit claiming
  /// to scan indefinitely and the user had to toggle the switch to recover.
  Timer? _discoveryWatchdog;
  bool _observingLifecycle = false;
  static const Duration _watchdogPeriod = Duration(seconds: 20);

  /// Completes once [deviceName] is either the saved override or the OS name.
  final Completer<void> _nameReady = Completer<void>();

  static String _placeholderName() {
    if (Platform.isAndroid) return 'Android device';
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isLinux) return 'Linux PC';
    return 'Throw device';
  }

  /// True when a Flutter binding has been initialised.
  static bool _bindingExists() {
    try {
      WidgetsBinding.instance;
      return true;
    } on FlutterError {
      return false;
    }
  }

  DeviceProvider({
    TransferService? service,
    AppPreferences? preferences,
    bool observeLifecycle = true,
  })  : _service = service ?? TransferServiceFactory.instance,
        _preferences = preferences ?? AppPreferences.inMemory() {
    // Reading `WidgetsBinding.instance` throws when no binding has been
    // initialised, and a provider that cannot be constructed outside a running
    // app is a provider that cannot be unit-tested. Checking the private
    // `BindingBase.debugBindingType()` is the supported way to ask "is there a
    // binding?" without throwing; tests and pure-Dart callers simply skip
    // lifecycle observation, which has no meaning for them anyway.
    if (observeLifecycle && _bindingExists()) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
    _devicesSub = _service.devices.listen((incoming) {
      var device = incoming;
      // Identity is the *device*, not the endpoint.
      //
      // An endpoint id is a WiFi Direct P2P address, and one phone can advertise
      // on more than one — a second network interface, a stale session that was
      // never torn down, or the peer re-advertising after its group formed. The
      // map is keyed by id, so each of those became a separate row and the same
      // phone appeared two or three times in Discover, each with its own
      // "Connect" button.
      //
      // Matching on the advertised name collapses them. The name is what the
      // user identifies a phone by anyway, and it is what the other device
      // advertises; if two genuinely different devices share a name, showing one
      // row is still better than showing both as twins, and connecting still
      // targets the id held in the row.
      final previous = _sameNameAs(device);
      if (previous != null && previous.id != device.id) {
        // The new endpoint wins: it is the one that reported in most recently,
        // so its P2P address is the live one. Its connection state and any name
        // learned for it come along — dropping them silently disconnected a row
        // the user was already sending to.
        _devicesMap.remove(previous.id);
        device = device.copyWith(
          isConnected: previous.isConnected || device.isConnected,
        );
      }

      final existing = _devicesMap[device.id];
      final merged = existing == null
          ? device
          : existing
              .withLearnedName(device.hasRealName ? device.name : null)
              .copyWith(
                isConnected: device.isConnected || existing.isConnected,
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
        // Deliberately no `.timeout()` here. It was tried, and it put a real
        // three-second timer into every launch: widget tests never advance the
        // clock, so the timer was still pending when the tree was disposed and
        // the framework failed them. The waiting that actually matters is
        // handled in `resolvedDeviceName`, which no longer waits for a lookup
        // that has not started.
        _deviceName = await _lookupOsName();
      } on Object {
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

  /// Reads this device's name from the OS, or returns [_deviceName] when the
  /// platform cannot answer.
  Future<String> _lookupOsName() async {
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
        return name.trim();
      }
    } catch (_) {
      // Fall through to the current value.
    }
    return _deviceName;
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
    // Nothing to wait for once the lookup has finished, and nothing to wait for
    // before it has started. The old version awaited the completer whenever it
    // was pending, which meant a caller that ran before `_resolveDeviceName`
    // had been scheduled waited the full three-second timeout for no reason —
    // three seconds of dead air on the first advertise, and an unelapsed timer
    // in any test that started a provider without a platform behind it.
    if (!_nameResolved && !_nameReady.isCompleted) {
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

  /// Stops advertising. Same reasoning as [stopDiscovery]: the switch is off
  /// because the user switched it off, and a native complaint about tearing
  /// down the radio is not something they can act on. Leaving `_isAdvertising`
  /// true on failure showed a "visible" switch over an invisible device.
  Future<void> stopAdvertising() async {
    try {
      await _service.stopAdvertising();
    } on Object {
      // Swallowed on purpose; see above.
    } finally {
      _isAdvertising = false;
      if (_error?.code == AppErrorCode.discoveryFailed) _error = null;
    }
    notifyListeners();
  }

  /// Re-arms discovery whenever the flag says it should be running.
  ///
  /// A periodic no-op rather than a health check: `startDiscovery` is
  /// idempotent at the plugin level (a second start while already scanning is
  /// rejected and ignored), so calling it on a healthy scan costs nothing,
  /// while calling it after the OS killed the scan is exactly the recovery the
  /// user used to perform by hand.
  void _startWatchdog() {
    _discoveryWatchdog?.cancel();
    // A repeating timer keeps the whole process awake and, in a test, keeps the
    // fake clock from ever going quiet — a leak that shows up as "a Timer is
    // still pending even after the widget tree was disposed" long after the
    // provider was forgotten. A self-rescheduling one-shot stops the moment it
    // is no longer wanted, whether that is because the provider was disposed,
    // the scan was switched off, or the isolate is shutting down.
    _discoveryWatchdog = Timer(_watchdogPeriod, _watchdogTick);
  }

  void _watchdogTick() {
    if (_disposed || !_isDiscovering) return;
    unawaited(() async {
      try {
        await _service.startDiscovery();
      } on Object {
        // A watchdog restart is not a user action; it must never raise a
        // banner. The next deliberate attempt reports failures properly.
      }
    }());
    // Re-arm, unless something stopped the scan in the meantime.
    if (!_disposed && _isDiscovering) {
      _discoveryWatchdog = Timer(_watchdogPeriod, _watchdogTick);
    }
  }

  void _stopWatchdog() {
    _discoveryWatchdog?.cancel();
    _discoveryWatchdog = null;
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
      _startWatchdog();
    } catch (e) {
      _error = AppError.fromObject(e, fallback: AppErrorCode.discoveryFailed);
      _isDiscovering = false;
      _stopWatchdog();
    }
    notifyListeners();
  }

  /// Stops scanning.
  ///
  /// The flag is cleared in `finally`, and a native failure is **not** reported
  /// as a scan failure. Both halves of that are fixes for the same screenshot:
  /// a failed `stopDiscovery` used to leave `_isDiscovering` true while setting
  /// `_error` to `discoveryFailed`, so Discover showed "Scanning... keep Throw
  /// open" and a red "Scanning for devices failed" banner at the same time,
  /// with the switch visibly off. The user asked to stop; the scan is over
  /// either way. What the native call thinks about it is not the user's
  /// problem, and the next [startDiscovery] will surface a real fault if one
  /// exists.
  Future<void> stopDiscovery() async {
    try {
      await _service.stopDiscovery();
    } on Object {
      // Intentionally swallowed: see above. Stopping cannot fail in a way the
      // user can act on.
    } finally {
      _isDiscovering = false;
      _stopWatchdog();
      // A stale discovery error must not outlive the scan it described.
      if (_error?.code == AppErrorCode.discoveryFailed) _error = null;
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

  /// The already-known device advertising under [device]'s name, if any.
  ///
  /// Names are compared case-insensitively and trimmed, because the name comes
  /// from the peer and two endpoints for the same phone can disagree on case.
  /// A nameless announcement never matches: that is how several anonymous peers
  /// would otherwise collapse into one row.
  DeviceModel? _sameNameAs(DeviceModel device) {
    if (!device.hasRealName) return null;
    final key = device.name.trim().toLowerCase();
    for (final known in _devicesMap.values) {
      if (known.hasRealName && known.name.trim().toLowerCase() == key) {
        return known;
      }
    }
    return null;
  }

  /// Resumes scanning when the app comes back to the foreground.
  ///
  /// Android tears down WiFi Direct discovery when the app is backgrounded, and
  /// the `nearby_connections` plugin has no callback for it — `DiscoveryCallback`
  /// only reports endpoints appearing and disappearing, never that discovery
  /// itself died. So the provider went on believing it was scanning while the
  /// radio was doing nothing, and the screen sat on "Scanning... keep Throw
  /// open" forever, finding nothing. Users read that as the app being broken,
  /// and switching the toggle off and on again was the only cure.
  ///
  /// Restarting on resume is what the platform expects an app to do, and it is
  /// invisible when discovery was healthy: `startDiscovery` is guarded by
  /// `_isDiscovering`, so this only acts when the flag says we *should* be
  /// scanning. Discovery that the user switched off stays off.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_restartIfStale());
    }
  }

  /// Re-arms discovery and advertising after the OS may have stopped them.
  ///
  /// The service is asked to start again rather than trusted to still be
  /// running: a duplicate start on the native side is rejected harmlessly by
  /// the plugin, while a missing one is the bug being fixed.
  Future<void> _restartIfStale() async {
    if (_isAdvertising) {
      try {
        // `_deviceName`, not `resolvedDeviceName()`. The name was resolved
        // before the first advertise, and the resolver waits up to three
        // seconds for a lookup that has already happened — a resume would have
        // stalled three seconds before re-arming the radio, and left a pending
        // timer behind. By the time anything is advertising, the name is known.
        await _service.startAdvertising(deviceName: _deviceName);
      } on Object {
        // A restart that fails is not a new user-facing error; the next
        // explicit action will report properly.
      }
    }
    if (_isDiscovering) {
      try {
        await _service.startDiscovery();
      } on Object {
        // See above.
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopWatchdog();
    if (_observingLifecycle) WidgetsBinding.instance.removeObserver(this);
    _devicesSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }
}
