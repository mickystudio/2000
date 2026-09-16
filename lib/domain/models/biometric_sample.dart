/// Source origin of biometric sleep and physical activity samples.
enum BiometricDataSource {
  huaweiHealthKit,
  manualEntry,
  cachedStorage,
}

/// Unified biometric reading combining sleep architecture and daily steps.
///
/// Domain models remain strictly agnostic to whether readings came from HMS Health Kit or manual entry.
class BiometricSample {
  final double totalSleepHours;
  final double? deepSleepHours;
  final double? remSleepHours;
  final int stepCount;
  final DateTime recordedAt;
  final BiometricDataSource source;
  final Map<String, dynamic>? metadata;

  const BiometricSample({
    required this.totalSleepHours,
    this.deepSleepHours,
    this.remSleepHours,
    required this.stepCount,
    required this.recordedAt,
    required this.source,
    this.metadata,
  }) : assert(totalSleepHours >= 0.0 && totalSleepHours <= 24.0, 'Sleep hours must be in [0, 24]'),
       assert(stepCount >= 0, 'Step count must be non-negative');

  /// Determines if this biometric reading is clinically stale (> 20 hours since recording).
  bool isStale({DateTime? now}) {
    final DateTime current = now ?? DateTime.now();
    return current.difference(recordedAt) > const Duration(hours: 20);
  }

  /// Calculates normalized SleepDeprivationScore (0.0 to 100.0).
  ///
  /// Clinical reference baseline: 8.0 hours is optimal (score 0.0).
  /// < 4.0 hours yields severe deprivation score (100.0).
  double computeSleepDeprivationScore() {
    if (totalSleepHours >= 8.0) return 0.0;
    if (totalSleepHours <= 4.0) return 100.0;
    final double deficit = (8.0 - totalSleepHours) / 4.0;
    return double.parse((deficit * 100.0).clamp(0.0, 100.0).toStringAsFixed(2));
  }

  /// Calculates normalized REM Deficit Score (0.0 to 100.0).
  ///
  /// Clinical reference: ~1.5 - 2.0 hours (20-25% of 8h) is normal REM sleep.
  /// If REM data is absent (e.g. basic step tracker or manual entry without sleep staging),
  /// returns null to gracefully trigger domain re-normalization.
  double? computeRemDeficitScore() {
    if (remSleepHours == null) return null;
    const double targetRemHours = 1.8;
    if (remSleepHours! >= targetRemHours) return 0.0;
    if (remSleepHours! <= 0.3) return 100.0;
    final double deficit = (targetRemHours - remSleepHours!) / (targetRemHours - 0.3);
    return double.parse((deficit * 100.0).clamp(0.0, 100.0).toStringAsFixed(2));
  }

  /// Calculates normalized SedentaryScore (0.0 to 100.0).
  ///
  /// Reference: 10,000 steps = optimal active day (score 0.0).
  /// < 1,500 steps = extreme sedentary state (score 100.0).
  double computeSedentaryScore() {
    if (stepCount >= 10000) return 0.0;
    if (stepCount <= 1500) return 100.0;
    final double deficit = (10000.0 - stepCount) / (10000.0 - 1500.0);
    return double.parse((deficit * 100.0).clamp(0.0, 100.0).toStringAsFixed(2));
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'total_sleep_hours': totalSleepHours,
      'deep_sleep_hours': deepSleepHours,
      'rem_sleep_hours': remSleepHours,
      'step_count': stepCount,
      'recorded_at': recordedAt.toIso8601String(),
      'source': source.name,
      'metadata': metadata,
    };
  }

  factory BiometricSample.fromMap(Map<String, dynamic> map) {
    return BiometricSample(
      totalSleepHours: (map['total_sleep_hours'] as num).toDouble(),
      deepSleepHours: (map['deep_sleep_hours'] as num?)?.toDouble(),
      remSleepHours: (map['rem_sleep_hours'] as num?)?.toDouble(),
      stepCount: (map['step_count'] as num).toInt(),
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      source: BiometricDataSource.values.firstWhere(
        (BiometricDataSource s) => s.name == map['source'],
        orElse: () => BiometricDataSource.manualEntry,
      ),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}
