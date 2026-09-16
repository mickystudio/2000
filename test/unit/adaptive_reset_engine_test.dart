import 'package:flutter_test/flutter_test.dart';
import '../../lib/domain/engine/adaptive_reset_engine.dart';
import '../../lib/domain/models/brain_health_counter.dart';
import '../../lib/domain/models/event_classification.dart';
import '../../lib/domain/models/post_mortem_input.dart';
import '../../lib/domain/models/vulnerability_index.dart';

void main() {
  group('AdaptiveResetEngine Unit Tests', () {
    const AdaptiveResetEngine engine = AdaptiveResetEngine(
      baseSlipPercent: 5.0,
      baseRelapsePercent: 25.0,
      baseClassificationThreshold: 50.0,
      rollingWindowDuration: Duration(days: 30),
    );

    const VulnerabilityIndex neutralVulnerability = VulnerabilityIndex(
      score: 50.0,
      isDegradedMode: false,
      activeWeights: <String, double>{'w4SelfReport': 1.0},
    );

    const String testHash = 'test_reproducible_daily_hash_2026';

    test('Non-linear loss doubling sequence for n=1..7 slips with strict [0.0, 100.0] clamping', () {
      // BasePercent = 5.0
      // n=1 -> 5.0 * 2^0 = 5.0
      // n=2 -> 5.0 * 2^1 = 10.0
      // n=3 -> 5.0 * 2^2 = 20.0
      // n=4 -> 5.0 * 2^3 = 40.0
      // n=5 -> 5.0 * 2^4 = 80.0
      // n=6 -> 5.0 * 2^5 = 160.0 -> strictly clamped at 100.0% max loss
      // n=7 -> 5.0 * 2^6 = 320.0 -> strictly clamped at 100.0% max loss
      expect(engine.calculateNonLinearSlipLoss(1), equals(5.0));
      expect(engine.calculateNonLinearSlipLoss(2), equals(10.0));
      expect(engine.calculateNonLinearSlipLoss(3), equals(20.0));
      expect(engine.calculateNonLinearSlipLoss(4), equals(40.0));
      expect(engine.calculateNonLinearSlipLoss(5), equals(80.0));
      expect(engine.calculateNonLinearSlipLoss(6), equals(100.0));
      expect(engine.calculateNonLinearSlipLoss(7), equals(100.0));

      // Cannot produce negative values
      expect(engine.calculateNonLinearSlipLoss(0), equals(0.0));
      expect(engine.calculateNonLinearSlipLoss(-1), equals(0.0));
    });

    test('Rolling window boundary: day 29 (included), day 30 (included), day 31 (excluded) per-event', () {
      final DateTime now = DateTime(2026, 6, 15, 12, 0, 0);

      // Event 29 days prior (within rolling 30-day window)
      final HistoricalEvent slipAtDay29 = HistoricalEvent(
        id: 'hist_29',
        classification: EventClassification.slip,
        timestamp: now.subtract(const Duration(days: 29)),
      );

      // Event exactly 30 days prior (boundary inside rolling 30-day window)
      final HistoricalEvent slipAtDay30 = HistoricalEvent(
        id: 'hist_30',
        classification: EventClassification.slip,
        timestamp: now.subtract(const Duration(days: 30)),
      );

      // Event 31 days prior (outside rolling 30-day window)
      final HistoricalEvent slipAtDay31 = HistoricalEvent(
        id: 'hist_31',
        classification: EventClassification.slip,
        timestamp: now.subtract(const Duration(days: 31)),
      );

      final List<HistoricalEvent> historyAll = <HistoricalEvent>[
        slipAtDay29,
        slipAtDay30,
        slipAtDay31,
      ];

      final List<HistoricalEvent> slipsInWindow = engine.getSlipsInRollingWindow(
        historicalEvents: historyAll,
        eventTimestamp: now,
      );

      // Day 29 and Day 30 MUST be included in the 30-day rolling window
      // Day 31 MUST be excluded
      expect(slipsInWindow.contains(slipAtDay29), isTrue);
      expect(slipsInWindow.contains(slipAtDay30), isTrue);
      expect(slipsInWindow.contains(slipAtDay31), isFalse);
      expect(slipsInWindow.length, equals(2));

      final BrainHealthCounter initialCounter = BrainHealthCounter(
        id: 'counter_01',
        userId: 'user_01',
        currentScore: 100.0,
        peakScore: 100.0,
        lastDecayAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      final PostMortemInput newSlipInput = PostMortemInput(
        durationMinutes: 5,
        repetitionCount: 1,
        escalationFlag: false,
        timestamp: now,
      );

      // When day 29 and 30 slips are in the window, new slip is the 3rd slip (n=3) -> Loss = 20.0
      final BrainHealthDecayResult resultWithActiveSlips = engine.processPostMortem(
        currentCounter: initialCounter,
        postMortem: newSlipInput,
        historicalEvents: historyAll,
        currentVulnerability: neutralVulnerability,
        dailyDataHash: testHash,
      );

      expect(resultWithActiveSlips.slipsInRollingWindow, equals(3));
      expect(resultWithActiveSlips.loss, equals(20.0));
      expect(resultWithActiveSlips.updatedCounter.currentScore, equals(80.0));

      // With only day 31 event (which expired outside window), new slip is n=1 -> Loss = 5.0
      final BrainHealthDecayResult resultOnlyDay31 = engine.processPostMortem(
        currentCounter: initialCounter,
        postMortem: newSlipInput,
        historicalEvents: <HistoricalEvent>[slipAtDay31],
        currentVulnerability: neutralVulnerability,
        dailyDataHash: testHash,
      );

      expect(resultOnlyDay31.slipsInRollingWindow, equals(1));
      expect(resultOnlyDay31.loss, equals(5.0));
      expect(resultOnlyDay31.updatedCounter.currentScore, equals(95.0));
    });

    test('Anti-gaming: PostMortemInput enforces minimum 1 minute and physiological duration for multiple repetitions', () {
      final DateTime now = DateTime(2026, 6, 15, 12, 0, 0);

      // User claims 4 repetitions in only 1 minute (physiologically impossible)
      final PostMortemInput gamedInput = PostMortemInput(
        durationMinutes: 1,
        repetitionCount: 4,
        escalationFlag: false,
        timestamp: now,
      );

      // Effective duration should be floored to repetitionCount * 2 = 8 minutes
      // Objective severity = 8 + (4 * 15.0) + 0 = 8 + 60 = 68.0
      expect(gamedInput.computeObjectiveSeverity(), equals(68.0));
    });

    test('Event classification computed ONLY from objective post-mortem inputs (user never manually picks label)', () {
      final DateTime now = DateTime(2026, 6, 15, 14, 0, 0);

      // 1. Brief session with no escalation -> classified as slip
      final PostMortemInput briefSession = PostMortemInput(
        durationMinutes: 5,
        repetitionCount: 1,
        escalationFlag: false,
        timestamp: now,
      );
      final EventClassification classificationBrief = engine.classifyEvent(
        postMortem: briefSession,
        vulnerabilityIndex: neutralVulnerability,
        dailyDataHash: testHash,
      );
      expect(classificationBrief, equals(EventClassification.slip));

      // 2. Explicit clinical escalation flag -> strictly forces relapse
      final PostMortemInput escalatedSession = PostMortemInput(
        durationMinutes: 5,
        repetitionCount: 1,
        escalationFlag: true,
        timestamp: now,
      );
      final EventClassification classificationEscalated = engine.classifyEvent(
        postMortem: escalatedSession,
        vulnerabilityIndex: neutralVulnerability,
        dailyDataHash: testHash,
      );
      expect(classificationEscalated, equals(EventClassification.relapse));

      // 3. Extended high-repetition session exceeding severity threshold -> classified as relapse
      final PostMortemInput severeSession = PostMortemInput(
        durationMinutes: 60,
        repetitionCount: 4,
        escalationFlag: false,
        timestamp: now,
      );
      final EventClassification classificationSevere = engine.classifyEvent(
        postMortem: severeSession,
        vulnerabilityIndex: neutralVulnerability,
        dailyDataHash: testHash,
      );
      expect(classificationSevere, equals(EventClassification.relapse));
    });

    test('Dynamic threshold scales inversely with VulnerabilityIndex', () {
      const VulnerabilityIndex highVulnerability = VulnerabilityIndex(
        score: 90.0,
        isDegradedMode: false,
        activeWeights: <String, double>{},
      );

      const VulnerabilityIndex lowVulnerability = VulnerabilityIndex(
        score: 10.0,
        isDegradedMode: false,
        activeWeights: <String, double>{},
      );

      final double thresholdHighVuln = engine.calculateDynamicThreshold(
        vulnerabilityIndex: highVulnerability,
        dailyDataHash: testHash,
      );

      final double thresholdLowVuln = engine.calculateDynamicThreshold(
        vulnerabilityIndex: lowVulnerability,
        dailyDataHash: testHash,
      );

      // Higher vulnerability results in a LOWER threshold (easier to relapse)
      // Lower vulnerability results in a HIGHER threshold (greater protective barrier)
      expect(thresholdHighVuln, lessThan(thresholdLowVuln));
    });

    test('Every brain_health_counter change generates an immutable decay_log row (never bare scalar mutation)', () {
      final DateTime now = DateTime(2026, 6, 15, 16, 0, 0);

      final BrainHealthCounter counter = BrainHealthCounter(
        id: 'bhc_100',
        userId: 'user_vault_99',
        currentScore: 80.0,
        peakScore: 100.0,
        lastDecayAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      );

      final PostMortemInput postMortem = PostMortemInput(
        durationMinutes: 10,
        repetitionCount: 1,
        escalationFlag: false,
        timestamp: now,
      );

      final BrainHealthDecayResult result = engine.processPostMortem(
        currentCounter: counter,
        postMortem: postMortem,
        historicalEvents: <HistoricalEvent>[],
        currentVulnerability: neutralVulnerability,
        dailyDataHash: testHash,
        causalEventId: 'evt_cause_123',
      );

      // Verify counter was modified with exact decay
      expect(result.updatedCounter.currentScore, equals(75.0)); // 80 - 5.0
      expect(result.loss, equals(5.0));

      // Verify mandatory decay_log entry was produced with all required fields
      expect(result.decayLog.counterId, equals(counter.id));
      expect(result.decayLog.userId, equals(counter.userId));
      expect(result.decayLog.eventId, equals('evt_cause_123'));
      expect(result.decayLog.previousScore, equals(80.0));
      expect(result.decayLog.resultingValue, equals(75.0));
      expect(result.decayLog.amount, equals(-5.0));
      expect(result.decayLog.cause, contains('ADAPTIVE_RESET'));
      expect(result.decayLog.timestamp, equals(now));
      expect(result.decayLog.cryptographicHash, isNotEmpty);
      expect(result.decayLog.metadata, isNotNull);
    });
  });
}
