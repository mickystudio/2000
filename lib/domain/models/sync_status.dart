/// The unified synchronization state of the biometric pipeline.
///
/// States:
/// - [connected]: Real-time or recent (< 20 hours old) biometric stream from Huawei Health Kit SDK.
/// - [degraded]: Huawei Health Kit is connected or available but telemetry has not updated in > 20 hours (stale).
/// - [manual]: Huawei Health Kit is unavailable, unauthorized, or user explicitly provided manual input.
enum SyncStatus {
  connected,
  degraded,
  manual,
}

extension SyncStatusX on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.connected:
        return 'CONNECTED (HMS Health Kit)';
      case SyncStatus.degraded:
        return 'DEGRADED (Stale Telemetry > 20h)';
      case SyncStatus.manual:
        return 'MANUAL (Fallback Data Entry)';
    }
  }

  bool get isConnected => this == SyncStatus.connected;
  bool get isDegraded => this == SyncStatus.degraded;
  bool get isManual => this == SyncStatus.manual;
}
