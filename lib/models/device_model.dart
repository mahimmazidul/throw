/// Where a discovered device lives and how a transfer to it will move.
enum DevicePlatform {
  android,
  windows,
  linux,
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
      platform: DevicePlatform.values.byName(json['platform'] as String),
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
