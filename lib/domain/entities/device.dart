/// Domain entity representing a device connected to the router.
///
/// This is a plain Dart class — no Flutter, no HTTP, no JSON.
/// It is the single source of truth for what a "device" means in this app.
class Device {
  const Device({
    required this.mac,
    required this.ip,
    this.hostname,
    this.isBlocked = false,
    this.leaseExpires,
    this.signalStrength,
  });

  /// MAC address in uppercase colon notation, e.g. "AA:BB:CC:DD:EE:FF"
  /// Used as the stable unique identifier across sessions.
  final String mac;

  /// Current IP address assigned by DHCP.
  final String ip;

  /// Hostname reported by the device in its DHCP request (may be null).
  final String? hostname;

  /// Whether the router is actively blocking this device via MAC filter.
  final bool isBlocked;

  /// DHCP lease expiry (null if not available from firmware).
  final DateTime? leaseExpires;

  /// Wi-Fi signal strength in dBm (null for wired or unavailable).
  final int? signalStrength;

  /// Human-readable display name: hostname if available, otherwise MAC.
  String get displayName => hostname?.isNotEmpty == true ? hostname! : mac;

  Device copyWith({
    String? mac,
    String? ip,
    String? hostname,
    bool? isBlocked,
    DateTime? leaseExpires,
    int? signalStrength,
  }) {
    return Device(
      mac: mac ?? this.mac,
      ip: ip ?? this.ip,
      hostname: hostname ?? this.hostname,
      isBlocked: isBlocked ?? this.isBlocked,
      leaseExpires: leaseExpires ?? this.leaseExpires,
      signalStrength: signalStrength ?? this.signalStrength,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Device && other.mac == mac);

  @override
  int get hashCode => mac.hashCode;

  @override
  String toString() => 'Device(mac: $mac, ip: $ip, hostname: $hostname, '
      'blocked: $isBlocked)';
}
