import '../../data/database/database_constants.dart';
import '../../data/database/encrypted_database.dart';
import '../models/daily_vulnerability_record.dart';
import '../models/escalation_tier_result.dart';
import '../models/stroop_test_result.dart';

/// Domain evaluator for clinical and therapeutic escalation tiers.
///
/// Evaluates clinical states both deterministically via pure functions
/// and directly against persistent SQLCipher storage on launch.
class EscalationTierEvaluator {
  const EscalationTierEvaluator();

  /// Tier 1: VulnerabilityIndex > 70% for 3 consecutive days with zero slips -> pre-fall warning flag.
  ///
  /// Evaluates trailing consecutive records to detect acute pre-lapse vulnerability.
  static Tier1Result evaluateTier1(List<DailyVulnerabilityRecord> history) {
    if (history.length < 3) {
      return const Tier1Result(
        isTriggered: false,
        consecutiveHighVulnerabilityDays: 0,
        diagnosticReason: 'Insufficient history (fewer than 3 daily records).',
      );
    }

    // Sort chronologically ascending
    final List<DailyVulnerabilityRecord> sorted = List<DailyVulnerabilityRecord>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Evaluate the trailing 3 records (or slide backwards from most recent)
    int consecutiveHighDays = 0;
    bool triggered = false;

    // Check sliding window of 3 consecutive entries
    for (int i = 0; i <= sorted.length - 3; i++) {
      final List<DailyVulnerabilityRecord> window = sorted.sublist(i, i + 3);
      final bool allAbove70 = window.every((r) => r.vulnerabilityIndexScore > 70.0);
      final bool zeroSlips = window.every((r) => r.slipCount == 0);

      // Verify dates are consecutive days
      final bool areConsecutive = _areConsecutiveDays(window.map((r) => r.date).toList());

      if (allAbove70 && zeroSlips && areConsecutive) {
        triggered = true;
        consecutiveHighDays = 3;
        break;
      }
    }

    if (triggered) {
      return Tier1Result(
        isTriggered: true,
        consecutiveHighVulnerabilityDays: consecutiveHighDays,
        diagnosticReason:
            'Pre-fall warning: VulnerabilityIndex exceeded 70% for 3 consecutive days with zero slips.',
      );
    }

    return const Tier1Result(
      isTriggered: false,
      consecutiveHighVulnerabilityDays: 0,
      diagnosticReason: 'Threshold criteria not met for Tier 1 pre-fall warning.',
    );
  }

  /// Tier 2: craving intensity stays >= 8/10 after 90s of Stroop test -> human-escalation flag.
  ///
  /// Evaluates acute neurocognitive intervention response.
  static Tier2Result evaluateTier2(StroopTestResult result) {
    final bool durationConditionMet = result.durationSeconds >= 90;
    final bool intensityConditionMet = result.postTestCravingIntensity >= 8.0;

    if (durationConditionMet && intensityConditionMet) {
      return Tier2Result(
        isTriggered: true,
        postCravingIntensity: result.postTestCravingIntensity,
        testDurationSeconds: result.durationSeconds,
        diagnosticReason:
            'Human escalation triggered: craving intensity remained at ${result.postTestCravingIntensity}/10 '
            'after ${result.durationSeconds}s Stroop test (>= 90s). Immediate clinical/peer outreach advised.',
      );
    }

    return Tier2Result(
      isTriggered: false,
      postCravingIntensity: result.postTestCravingIntensity,
      testDurationSeconds: result.durationSeconds,
      diagnosticReason: 'Criteria not met for Tier 2 human escalation.',
    );
  }

  /// Tier 3: 3 relapses within rolling 30-day window -> clinical-warning flag, locks self-guided mode.
  ///
  /// Pure function checking whether relapse frequency within [currentTimestamp - 30 days, currentTimestamp]
  /// meets or exceeds 3 events.
  static Tier3Result evaluateTier3({
    required List<DateTime> relapseTimestamps,
    required DateTime currentTimestamp,
    Duration rollingWindow = const Duration(days: 30),
  }) {
    final DateTime windowStart = currentTimestamp.subtract(rollingWindow);

    final List<DateTime> relapsesInWindow = relapseTimestamps.where((DateTime timestamp) {
      final bool isAfterOrAtStart = timestamp.isAfter(windowStart) || timestamp.isAtSameMomentAs(windowStart);
      final bool isBeforeOrAtCurrent = timestamp.isBefore(currentTimestamp) || timestamp.isAtSameMomentAs(currentTimestamp);
      return isAfterOrAtStart && isBeforeOrAtCurrent;
    }).toList();

    final int count = relapsesInWindow.length;
    final bool triggered = count >= 3;

    if (triggered) {
      return Tier3Result(
        isTriggered: true,
        lockSelfGuidedMode: true,
        relapsesInWindow: count,
        diagnosticReason:
            'Clinical warning triggered: $count relapses recorded within rolling 30-day window (threshold: 3). '
            'Self-guided mode locked. Professional consultation required.',
      );
    }

    return Tier3Result(
      isTriggered: false,
      lockSelfGuidedMode: false,
      relapsesInWindow: count,
      diagnosticReason:
          'Sub-threshold: $count relapses within rolling 30-day window (threshold: 3). Self-guided mode remains active.',
    );
  }

  /// Instance method evaluating Tier 3 condition directly from persistent SQLCipher database.
  ///
  /// This ensures that Tier 3 lockdown state is always read from persistent disk storage
  /// on every app launch and cannot be bypassed by force-closing the app.
  Future<Tier3Result> evaluateTier3FromDatabase(
    EncryptedDatabase database,
    String userId, {
    DateTime? now,
  }) async {
    final DateTime currentTimestamp = now ?? DateTime.now();
    final DateTime windowStart = currentTimestamp.subtract(const Duration(days: 30));
    final int windowStartMs = windowStart.millisecondsSinceEpoch;
    final int currentMs = currentTimestamp.millisecondsSinceEpoch;

    final db = await database.database;

    // 1. Query decay log for explicit relapse causes
    final List<Map<String, dynamic>> decayRows = await db.query(
      DatabaseConstants.tableDecayLog,
      where: 'user_id = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: <Object>[userId, windowStartMs, currentMs],
      orderBy: 'timestamp DESC',
    );

    // 2. Query SOS sessions for relapse outcomes
    final List<Map<String, dynamic>> sosRows = await db.query(
      DatabaseConstants.tableSosSessions,
      where: 'user_id = ? AND started_at >= ? AND started_at <= ?',
      whereArgs: <Object>[userId, windowStartMs, currentMs],
      orderBy: 'started_at DESC',
    );

    // 3. Query events table for relapse events
    final List<Map<String, dynamic>> eventRows = await db.query(
      DatabaseConstants.tableEvents,
      where: 'user_id = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: <Object>[userId, windowStartMs, currentMs],
      orderBy: 'timestamp DESC',
    );

    final List<DateTime> relapseTimestamps = <DateTime>[];

    for (final Map<String, dynamic> row in decayRows) {
      final String cause = (row['cause'] as String? ?? '').toUpperCase();
      if (cause.contains('RELAPSE') || cause.contains('SLIP') || cause.contains('LAPSE')) {
        relapseTimestamps.add(DateTime.fromMillisecondsSinceEpoch((row['timestamp'] as num).toInt()));
      }
    }

    for (final Map<String, dynamic> row in sosRows) {
      final String outcome = (row['outcome_state'] as String? ?? '').toUpperCase();
      if (outcome.contains('RELAPSE') || outcome.contains('SLIP')) {
        relapseTimestamps.add(DateTime.fromMillisecondsSinceEpoch((row['started_at'] as num).toInt()));
      }
    }

    for (final Map<String, dynamic> row in eventRows) {
      final String eventType = (row['event_type'] as String? ?? '').toUpperCase();
      if (eventType.contains('RELAPSE') || eventType.contains('SLIP')) {
        relapseTimestamps.add(DateTime.fromMillisecondsSinceEpoch((row['timestamp'] as num).toInt()));
      }
    }

    return evaluateTier3(
      relapseTimestamps: relapseTimestamps,
      currentTimestamp: currentTimestamp,
    );
  }

  /// Instance method evaluating Tier 2 from Stroop test result
  Tier2Result evaluateTier2Instance(StroopTestResult result) => evaluateTier2(result);

  /// Instance method evaluating Tier 1 from vulnerability records
  Tier1Result evaluateTier1Instance(List<DailyVulnerabilityRecord> history) => evaluateTier1(history);

  /// Evaluates all tiers in a consolidated pure assessment.
  static EscalationEvaluationSummary evaluateAll({
    required List<DailyVulnerabilityRecord> vulnerabilityHistory,
    StroopTestResult? stroopResult,
    required List<DateTime> relapseTimestamps,
    required DateTime currentTimestamp,
  }) {
    final Tier1Result t1 = evaluateTier1(vulnerabilityHistory);
    final Tier2Result? t2 = stroopResult != null ? evaluateTier2(stroopResult) : null;
    final Tier3Result t3 = evaluateTier3(
      relapseTimestamps: relapseTimestamps,
      currentTimestamp: currentTimestamp,
    );

    return EscalationEvaluationSummary(
      tier1: t1,
      tier2: t2,
      tier3: t3,
      evaluatedAt: currentTimestamp,
    );
  }

  static bool _areConsecutiveDays(List<DateTime> dates) {
    for (int i = 0; i < dates.length - 1; i++) {
      final DateTime d1 = DateTime(dates[i].year, dates[i].month, dates[i].day);
      final DateTime d2 = DateTime(dates[i + 1].year, dates[i + 1].month, dates[i + 1].day);
      if (d2.difference(d1).inDays != 1) {
        return false;
      }
    }
    return true;
  }
}
