import 'dart:convert';

enum SecurityPosture {
  trusted,
  monitored,
  clearAndMonitor,
  pendingWipe
}

class SecureSyncDevice {
  final String deviceId;        // Unique cryptographically derived fingerprint (e.g., from local TLS keys)
  final String deviceName;      // Friendly identifier
  final String lastKnownIp;     // Fallback local routing IP
  final int lastKnownPort;      // Target network interface port
  final DateTime? lastSyncedAt;
  final SecurityPosture posture;

  SecureSyncDevice({
    required this.deviceId,
    required this.deviceName,
    required this.lastKnownIp,
    required this.lastKnownPort,
    this.lastSyncedAt,
    this.posture = SecurityPosture.trusted,
  });

  SecureSyncDevice copyWith({
    String? deviceName,
    String? lastKnownIp,
    int? lastKnownPort,
    DateTime? lastSyncedAt,
    SecurityPosture? posture,
  }) {
    return SecureSyncDevice(
      deviceId: this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      lastKnownIp: lastKnownIp ?? this.lastKnownIp,
      lastKnownPort: lastKnownPort ?? this.lastKnownPort,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      posture: posture ?? this.posture,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': deviceId,
      'name': deviceName,
      'ip': lastKnownIp,
      'port': lastKnownPort,
      'last_sync': lastSyncedAt?.toIso8601String(),
      'posture': posture.index,
    };
  }

  factory SecureSyncDevice.fromMap(Map<String, dynamic> map) {
    return SecureSyncDevice(
      deviceId: map['id'] as String,
      deviceName: map['name'] as String,
      lastKnownIp: map['ip'] as String,
      lastKnownPort: map['port'] as int,
      lastSyncedAt: map['last_sync'] != null ? DateTime.parse(map['last_sync'] as String) : null,
      posture: SecurityPosture.values[map['posture'] as int? ?? 0],
    );
  }
}
