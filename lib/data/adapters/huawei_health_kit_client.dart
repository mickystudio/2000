import 'package:flutter/services.dart';
import '../../domain/models/biometric_sample.dart';

/// Native client interacting with Huawei Health Kit (HMS Health Kit SDK).
///
/// Communication runs across a dedicated Flutter platform MethodChannel:
/// `com.example.hms/health`
///
/// Handles:
/// 1. SDK Availability check (`isHealthKitAvailable`)
/// 2. OAuth Scope Authorization (`requestAuthorization`)
/// 3. Sleep data query (`querySleepData`: total duration, deep sleep, REM sleep)
/// 4. Daily step count query (`queryDailySteps`)
class HuaweiHealthKitClient {
  static const String channelName = 'com.example.hms/health';
  static const MethodChannel _channel = MethodChannel(channelName);

  final MethodChannel channel;

  HuaweiHealthKitClient({MethodChannel? channel}) : channel = channel ?? _channel;

  /// Verifies if Huawei Mobile Services (HMS Core) and Health Kit are available on this device.
  Future<bool> isAvailable() async {
    try {
      final dynamic result = await channel.invokeMethod<dynamic>('isHealthKitAvailable');
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Requests user authorization for Huawei Health Kit data types:
  /// - `com.huawei.health.sleep`
  /// - `com.huawei.health.step`
  Future<bool> requestAuthorization() async {
    try {
      final dynamic result = await channel.invokeMethod<dynamic>('requestAuthorization', <String, dynamic>{
        'scopes': <String>[
          'https://www.huawei.com/healthkit/sleep.read',
          'https://www.huawei.com/healthkit/step.read',
        ],
      });
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if Huawei Health Kit authorization has already been granted.
  Future<bool> hasAuthorization() async {
    try {
      final dynamic result = await channel.invokeMethod<dynamic>('hasAuthorization');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Fetches latest sleep staging and step count telemetry from HMS Health Kit.
  Future<BiometricSample?> fetchLatestBiometrics({DateTime? queryTime}) async {
    final DateTime now = queryTime ?? DateTime.now();
    try {
      final dynamic raw = await channel.invokeMethod<dynamic>('getLatestBiometrics', <String, dynamic>{
        'timestamp': now.millisecondsSinceEpoch,
      });

      if (raw == null || raw is! Map) {
        return null;
      }

      final Map<dynamic, dynamic> map = raw;

      final double totalSleep = (map['total_sleep_hours'] as num?)?.toDouble() ?? 0.0;
      final double? deepSleep = (map['deep_sleep_hours'] as num?)?.toDouble();
      final double? remSleep = (map['rem_sleep_hours'] as num?)?.toDouble();
      final int steps = (map['step_count'] as num?)?.toInt() ?? 0;
      final int timestampMs = (map['recorded_at_ms'] as num?)?.toInt() ?? now.millisecondsSinceEpoch;

      return BiometricSample(
        totalSleepHours: totalSleep.clamp(0.0, 24.0),
        deepSleepHours: deepSleep != null ? deepSleep.clamp(0.0, 24.0) : null,
        remSleepHours: remSleep != null ? remSleep.clamp(0.0, 24.0) : null,
        stepCount: steps < 0 ? 0 : steps,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(timestampMs),
        source: BiometricDataSource.huaweiHealthKit,
        metadata: <String, dynamic>{
          'provider': 'HMS_HEALTH_KIT_SDK',
          'raw_response': map,
        },
      );
    } catch (_) {
      return null;
    }
  }
}
