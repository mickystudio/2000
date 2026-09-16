import 'package:flutter_test/flutter_test.dart';
import '../../lib/domain/escalation/escalation_tier_evaluator.dart';
import '../../lib/domain/models/daily_vulnerability_record.dart';
import '../../lib/domain/models/escalation_tier_result.dart';
import '../../lib/domain/models/stroop_test_result.dart';

void main() {
  group('EscalationTierEvaluator Unit Tests', () {
    group('Tier 1: Pre-fall Warning (VulnerabilityIndex > 70% for 3 consecutive days with zero slips)', () {
      final DateTime day1 = DateTime(2026, 6, 1);
      final DateTime day2 = DateTime(2026, 6, 2);
      final DateTime day3 = DateTime(2026, 6, 3);

      test('Triggers Tier 1 when 3 consecutive days have score > 70% and zero slips', () {
        final List<DailyVulnerabilityRecord> records = <DailyVulnerabilityRecord>[
          DailyVulnerabilityRecord(date: day1, vulnerabilityIndexScore: 72.5, slipCount: 0),
          DailyVulnerabilityRecord(date: day2, vulnerabilityIndexScore: 81.0, slipCount: 0),
          DailyVulnerabilityRecord(date: day3, vulnerabilityIndexScore: 75.0, slipCount: 0),
        ];

        final Tier1Result result = EscalationTierEvaluator.evaluateTier1(records);

        expect(result.isTriggered, isTrue);
        expect(result.consecutiveHighVulnerabilityDays, equals(3));
        expect(result.diagnosticReason, contains('Pre-fall warning'));
      });

      test('Does not trigger Tier 1 if any day has score <= 70%', () {
        final List<DailyVulnerabilityRecord> records = <DailyVulnerabilityRecord>[
          DailyVulnerabilityRecord(date: day1, vulnerabilityIndexScore: 75.0, slipCount: 0),
          DailyVulnerabilityRecord(date: day2, vulnerabilityIndexScore: 68.0, slipCount: 0), // below 70%
          DailyVulnerabilityRecord(date: day3, vulnerabilityIndexScore: 78.0, slipCount: 0),
        ];

        final Tier1Result result = EscalationTierEvaluator.evaluateTier1(records);
        expect(result.isTriggered, isFalse);
      });

      test('Does not trigger Tier 1 if any day has one or more slips', () {
        final List<DailyVulnerabilityRecord> records = <DailyVulnerabilityRecord>[
          DailyVulnerabilityRecord(date: day1, vulnerabilityIndexScore: 75.0, slipCount: 0),
          DailyVulnerabilityRecord(date: day2, vulnerabilityIndexScore: 82.0, slipCount: 1), // slip occurred
          DailyVulnerabilityRecord(date: day3, vulnerabilityIndexScore: 78.0, slipCount: 0),
        ];

        final Tier1Result result = EscalationTierEvaluator.evaluateTier1(records);
        expect(result.isTriggered, isFalse);
      });

      test('Does not trigger Tier 1 if days are not consecutive', () {
        final List<DailyVulnerabilityRecord> nonConsecutiveRecords = <DailyVulnerabilityRecord>[
          DailyVulnerabilityRecord(date: DateTime(2026, 6, 1), vulnerabilityIndexScore: 75.0, slipCount: 0),
          DailyVulnerabilityRecord(date: DateTime(2026, 6, 3), vulnerabilityIndexScore: 82.0, slipCount: 0), // Gap on June 2
          DailyVulnerabilityRecord(date: DateTime(2026, 6, 4), vulnerabilityIndexScore: 78.0, slipCount: 0),
        ];

        final Tier1Result result = EscalationTierEvaluator.evaluateTier1(nonConsecutiveRecords);
        expect(result.isTriggered, isFalse);
      });
    });

    group('Tier 2: Human Escalation (Craving intensity stays >= 8/10 after 90s Stroop test)', () {
      test('Triggers Tier 2 when craving intensity stays >= 8/10 after 90s or more', () {
        const StroopTestResult testResult90s = StroopTestResult(
          durationSeconds: 90,
          initialCravingIntensity: 9.0,
          postTestCravingIntensity: 8.0,
        );

        final Tier2Result result90s = EscalationTierEvaluator.evaluateTier2(testResult90s);
        expect(result90s.isTriggered, isTrue);
        expect(result90s.postCravingIntensity, equals(8.0));

        const StroopTestResult testResult120s = StroopTestResult(
          durationSeconds: 120,
          initialCravingIntensity: 10.0,
          postTestCravingIntensity: 8.5,
        );

        final Tier2Result result120s = EscalationTierEvaluator.evaluateTier2(testResult120s);
        expect(result120s.isTriggered, isTrue);
        expect(result120s.diagnosticReason, contains('Human escalation triggered'));
      });

      test('Does not trigger Tier 2 if craving drops below 8/10 after 90s', () {
        const StroopTestResult relievedResult = StroopTestResult(
          durationSeconds: 90,
          initialCravingIntensity: 9.0,
          postTestCravingIntensity: 7.5, // Reduced below 8
        );

        final Tier2Result result = EscalationTierEvaluator.evaluateTier2(relievedResult);
        expect(result.isTriggered, isFalse);
      });

      test('Does not trigger Tier 2 if Stroop duration was under 90s even if craving is high', () {
        const StroopTestResult shortDurationResult = StroopTestResult(
          durationSeconds: 60, // Under 90s
          initialCravingIntensity: 9.0,
          postTestCravingIntensity: 9.0,
        );

        final Tier2Result result = EscalationTierEvaluator.evaluateTier2(shortDurationResult);
        expect(result.isTriggered, isFalse);
      });
    });

    group('Tier 3: Clinical Warning & Lock (3 relapses within rolling 30-day window)', () {
      final DateTime now = DateTime(2026, 6, 15, 12, 0, 0);

      test('Triggers Tier 3 and locks self-guided mode when 3 or more relapses occur within 30 days', () {
        final List<DateTime> relapses = <DateTime>[
          now.subtract(const Duration(days: 25)),
          now.subtract(const Duration(days: 14)),
          now.subtract(const Duration(days: 2)),
        ];

        final Tier3Result result = EscalationTierEvaluator.evaluateTier3(
          relapseTimestamps: relapses,
          currentTimestamp: now,
        );

        expect(result.isTriggered, isTrue);
        expect(result.lockSelfGuidedMode, isTrue);
        expect(result.relapsesInWindow, equals(3));
        expect(result.diagnosticReason, contains('Self-guided mode locked'));
      });

      test('Does not trigger Tier 3 when fewer than 3 relapses occur in the 30-day window', () {
        final List<DateTime> twoRelapses = <DateTime>[
          now.subtract(const Duration(days: 20)),
          now.subtract(const Duration(days: 5)),
        ];

        final Tier3Result result = EscalationTierEvaluator.evaluateTier3(
          relapseTimestamps: twoRelapses,
          currentTimestamp: now,
        );

        expect(result.isTriggered, isFalse);
        expect(result.lockSelfGuidedMode, isFalse);
        expect(result.relapsesInWindow, equals(2));
      });

      test('Excludes relapses older than 30 days from rolling window calculation', () {
        final List<DateTime> relapsesWithExpiredEvent = <DateTime>[
          now.subtract(const Duration(days: 45)), // Outside 30-day window
          now.subtract(const Duration(days: 31)), // Outside 30-day window
          now.subtract(const Duration(days: 20)), // Inside
          now.subtract(const Duration(days: 5)),  // Inside
        ];

        final Tier3Result result = EscalationTierEvaluator.evaluateTier3(
          relapseTimestamps: relapsesWithExpiredEvent,
          currentTimestamp: now,
        );

        expect(result.isTriggered, isFalse);
        expect(result.lockSelfGuidedMode, isFalse);
        expect(result.relapsesInWindow, equals(2));
      });
    });

    test('Consolidated evaluateAll returns accurate full escalation profile', () {
      final DateTime now = DateTime(2026, 6, 15, 12, 0, 0);

      final List<DailyVulnerabilityRecord> history = <DailyVulnerabilityRecord>[
        DailyVulnerabilityRecord(date: now.subtract(const Duration(days: 2)), vulnerabilityIndexScore: 75.0, slipCount: 0),
        DailyVulnerabilityRecord(date: now.subtract(const Duration(days: 1)), vulnerabilityIndexScore: 80.0, slipCount: 0),
        DailyVulnerabilityRecord(date: now, vulnerabilityIndexScore: 78.0, slipCount: 0),
      ];

      const StroopTestResult stroop = StroopTestResult(
        durationSeconds: 95,
        initialCravingIntensity: 9.0,
        postTestCravingIntensity: 8.5,
      );

      final List<DateTime> relapses = <DateTime>[
        now.subtract(const Duration(days: 20)),
        now.subtract(const Duration(days: 10)),
        now.subtract(const Duration(days: 1)),
      ];

      final EscalationEvaluationSummary summary = EscalationTierEvaluator.evaluateAll(
        vulnerabilityHistory: history,
        stroopResult: stroop,
        relapseTimestamps: relapses,
        currentTimestamp: now,
      );

      expect(summary.tier1.isTriggered, isTrue);
      expect(summary.tier2?.isTriggered, isTrue);
      expect(summary.tier3.isTriggered, isTrue);
      expect(summary.requiresAnyEscalation, isTrue);
      expect(summary.isSelfGuidedModeLocked, isTrue);
    });
  });
}
