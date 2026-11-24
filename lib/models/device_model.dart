import 'dart:io';

/// Where a discovered device lives and how a transfer to it will move.
enum DevicePlatform {
  android,
  windows,
  linux,
  unknown;

  /// Human label for a peer we know little about.
  String get label => switch (this) {
        DevicePlatform.android => 'Android',
        DevicePlatform.windows => 'Windows',
        DevicePlatform.linux => 'Linux',
        DevicePlatform.unknown => 'Unknown',
      };

  static DevicePlatform parse(String? value) => switch (value) {
        'android' => DevicePlatform.android,
        'windows' => DevicePlatform.windows,
        'linux' => DevicePlatform.linux,
        _ => DevicePlatform.unknown,
      };

  static DevicePlatform ofThisMachine() {
    if (Platform.isAndroid) return DevicePlatform.android;
    if (Platform.isWindows) return DevicePlatform.windows;
    if (Platform.isLinux) return DevicePlatform.linux;
    return DevicePlatform.unknown;
  }
}

/// The transport used to reach a device — drives the speed label in the UI.
enum TransferChannel {
  /// Android ↔ Android: WiFi Direct, ~250 Mbps.
  wifiDirect,

  /// Anything involving a desktop: Bluetooth, ~3 Mbps.
  bluetooth,
}

/// A device Throw can talk to.
class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.name,
    required this.platform,
    required this.channel,
    this.isConnected = false,
    required this.lastSeen,
  });

  /// Platform address of the peer (Nearby endpoint id, BLE address, …).
  final String id;

  /// Name shown to the human (system device name).
  final String name;

  final DevicePlatform platform;

  final TransferChannel channel;

  /// Whether a connection to this peer is currently live.
  final bool isConnected;

  /// Last time discovery or a connection callback saw this device.
  final DateTime lastSeen;

  /// Approximate throughput promised to the user for this channel.
  int get speedMbps => switch (channel) {
        TransferChannel.wifiDirect => 250,
        TransferChannel.bluetooth => 3,
      };

  /// True when [name] is still whatever the transport reported before a real
  /// name arrived — a raw endpoint UUID, an empty string, or the generic
  /// placeholder. These are exactly the cases that used to surface as a 36
  /// character UUID in the transfer list.
  bool get hasRealName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == id) return false;
    // A UUID or MAC-shaped string is an address, not a name.
    if (RegExp(r'^[0-9A-Fa-f:\-]{8,}$').hasMatch(trimmed)) return false;
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return !uuid.hasMatch(trimmed);
  }

  /// What to render for this peer. Never a bare UUID.
  ///
  /// `nearbyNameToken` is a short, recognisable tail of the address
  /// ("A1B2") so two unnamed devices are still distinguishable.
  String get displayName {
    if (hasRealName) return name.trim();
    return 'Nearby device · $nearbyNameToken';
  }

  /// Last four hex characters of the id, uppercased, or '????' when the id has
  /// no hex tail to show.
  String get nearbyNameToken {
    final hex = RegExp(r'[0-9a-fA-F]').allMatches(id).map((m) => m[0]).join();
    if (hex.length < 4) return '????';
    return hex.substring(hex.length - 4).toUpperCase();
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    DevicePlatform? platform,
    TransferChannel? channel,
    bool? isConnected,
    DateTime? lastSeen,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      channel: channel ?? this.channel,
      isConnected: isConnected ?? this.isConnected,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Keeps the real name if one has been learned and [name] is only a
  /// placeholder: transports emit events out of order and a late discovery
  /// event must not undo a HELLO.
  DeviceModel withLearnedName(String? learned) {
    if (learned == null || learned.trim().isEmpty) return this;
    if (hasRealName && !learned.trim().startsWith('Nearby device')) return this;
    return copyWith(name: learned.trim());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'platform': platform.name,
        'channel': channel.name,
        'isConnected': isConnected,
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: DevicePlatform.values.byName(
        json['platform'] as String? ?? 'unknown',
      ),
      channel: TransferChannel.values.byName(json['channel'] as String),
      isConnected: json['isConnected'] as bool? ?? false,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
    );
  }

  @override
  bool operator ==(Object other) => other is DeviceModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DeviceModel($id, $name, ${channel.name})';
}
