import 'dart:math' as math;
import '../models/brain_health_counter.dart';
import '../models/decay_log_entry.dart';
import '../models/event_classification.dart';
import '../models/post_mortem_input.dart';
import '../models/vulnerability_index.dart';
import 'jitter_generator.dart';

/// Historical event model for tracking past slips and relapses in window calculations.
class HistoricalEvent {
  final String id;
  final EventClassification classification;
  final DateTime timestamp;

  const HistoricalEvent({
    required this.id,
    required this.classification,
    required this.timestamp,
  });
}

/// Output payload from processing a post-mortem setback through the Adaptive Reset Engine.
class BrainHealthDecayResult {
  final BrainHealthCounter updatedCounter;
  final DecayLogEntry decayLog;
  final EventClassification classification;
  final double loss;
  final int slipsInRollingWindow;
  final double dynamicThreshold;
  final double appliedJitter;
  final double objectiveSeverity;

  const BrainHealthDecayResult({
    required this.updatedCounter,
    required this.decayLog,
    required this.classification,
    required this.loss,
    required this.slipsInRollingWindow,
    required this.dynamicThreshold,
    required this.appliedJitter,
    required this.objectiveSeverity,
  });
}

/// Abstract contract enforcing persistence whenever the counter is updated.
/// Guarantees that the counter is NEVER mutated as a bare scalar without writing a decay_log entry.
abstract class DecayLogWriter {
  Future<void> persistDecay({
    required BrainHealthCounter updatedCounter,
    required DecayLogEntry decayLog,
  });
}

/// Core domain engine implementing adaptive reset dynamics, non-linear decay,
/// rolling 30-day windows, and deterministic cryptographic jitter.
class AdaptiveResetEngine {
  /// Base percentage lost on initial slip (n=1).
  final double baseSlipPercent;

  /// Base percentage lost on a relapse event.
  final double baseRelapsePercent;

  /// Base threshold separating slip vs relapse before scaling and jitter.
  final double baseClassificationThreshold;

  /// Duration of the rolling window for setback accumulation.
  final Duration rollingWindowDuration;

  const AdaptiveResetEngine({
    this.baseSlipPercent = 5.0,
    this.baseRelapsePercent = 25.0,
    this.baseClassificationThreshold = 50.0,
    this.rollingWindowDuration = const Duration(days: 30),
  });

  /// Classifies a setback event into [EventClassification.slip] vs [EventClassification.relapse]
  /// computed ONLY from objective post-mortem inputs, scaled inversely by [vulnerabilityIndex],
  /// modulated by deterministic ±10% jitter derived from [dailyDataHash].
  ///
  /// The user NEVER manually picks the label.
  EventClassification classifyEvent({
    required PostMortemInput postMortem,
    required VulnerabilityIndex vulnerabilityIndex,
    required String dailyDataHash,
  }) {
    // Explicit clinical escalation flag forces relapse classification
    if (postMortem.escalationFlag) {
      return EventClassification.relapse;
    }

    final double dynamicThreshold = calculateDynamicThreshold(
      vulnerabilityIndex: vulnerabilityIndex,
      dailyDataHash: dailyDataHash,
    );

    final double objectiveSeverity = postMortem.computeObjectiveSeverity();

    if (objectiveSeverity >= dynamicThreshold) {
      return EventClassification.relapse;
    }

    return EventClassification.slip;
  }

  /// Calculates dynamic threshold separating slip/relapse.
  ///
  /// Formula:
  ///   inverseVulnerabilityScale = 1.0 / (0.5 + 0.5 * vulnerabilityRatio)
  ///   jitter = computeJitter(dailyDataHash)  [-0.10, +0.10]
  ///   threshold = baseClassificationThreshold * inverseVulnerabilityScale * (1.0 + jitter)
  ///
  /// Higher vulnerability -> lower threshold (easier to relapse).
  /// Lower vulnerability -> higher threshold (greater buffer before relapse).
  double calculateDynamicThreshold({
    required VulnerabilityIndex vulnerabilityIndex,
    required String dailyDataHash,
  }) {
    final double vulnerabilityRatio = vulnerabilityIndex.ratio.clamp(0.0, 1.0);
    final double inverseVulnerabilityScale = 1.0 / (0.5 + 0.5 * vulnerabilityRatio);
    final double jitter = JitterGenerator.computeJitter(dailyDataHash);

    final double scaledThreshold = (baseClassificationThreshold * inverseVulnerabilityScale) * (1.0 + jitter);
    return double.parse(scaledThreshold.toStringAsFixed(4));
  }

  /// Calculates non-linear decay loss for slips.
  ///
  /// Mathematical specification:
  ///   Loss = BasePercent * 2^(n-1)
  /// where n = count of slips within a ROLLING 30-day window computed from
  /// each event's own timestamp backward (not a fixed calendar month reset).
  ///
  /// Sequences:
  ///   n=1 -> BasePercent * 2^0 = BasePercent * 1 (e.g. 5.0%)
  ///   n=2 -> BasePercent * 2^1 = BasePercent * 2 (e.g. 10.0%)
  ///   n=3 -> BasePercent * 2^2 = BasePercent * 4 (e.g. 20.0%)
  ///   n=4 -> BasePercent * 2^3 = BasePercent * 8 (e.g. 40.0%)
  ///   n=5 -> BasePercent * 2^4 = BasePercent * 16 (e.g. 80.0%)
  ///   n>=6 -> Clamped strictly at 100.0% max loss.
  ///
  /// Clamping contract:
  ///   Loss is strictly clamped to [0.0, 100.0] to prevent negative or >100% decay.
  double calculateNonLinearSlipLoss(int slipCountInRollingWindow) {
    if (slipCountInRollingWindow < 1) return 0.0;
    final double rawLoss = baseSlipPercent * math.pow(2, slipCountInRollingWindow - 1);
    final double clampedLoss = rawLoss.clamp(0.0, 100.0);
    return double.parse(clampedLoss.toStringAsFixed(4));
  }

  /// Filters prior events that fall strictly inside the rolling 30-day window
  /// computed backward from [eventTimestamp].
  ///
  /// Boundary specification:
  ///   Window is [eventTimestamp - 30 days, eventTimestamp].
  ///   An event exactly at day 30 (timestamp - 30 days) is INCLUDED.
  ///   An event at day 31 (timestamp - 31 days) is EXCLUDED.
  List<HistoricalEvent> getSlipsInRollingWindow({
    required List<HistoricalEvent> historicalEvents,
    required DateTime eventTimestamp,
  }) {
    final DateTime windowStart = eventTimestamp.subtract(rollingWindowDuration);

    return historicalEvents.where((HistoricalEvent event) {
      if (event.classification != EventClassification.slip) return false;

      // Event must be within [eventTimestamp - 30 days, eventTimestamp]
      final bool isAfterOrAtStart =
          event.timestamp.isAfter(windowStart) || event.timestamp.isAtSameMomentAs(windowStart);
      final bool isBeforeOrAtEnd =
          event.timestamp.isBefore(eventTimestamp) || event.timestamp.isAtSameMomentAs(eventTimestamp);

      return isAfterOrAtStart && isBeforeOrAtEnd;
    }).toList();
  }

  /// Processes an objective post-mortem setback, updates the counter, and builds the immutable decay log.
  ///
  /// Guarantees:
  /// 1. Classification computed solely from objective post-mortem inputs.
  /// 2. Non-linear decay evaluated against the rolling 30-day history.
  /// 3. Every counter modification writes one row to decay_log (cause, amount, resulting_value, timestamp).
  ///    The counter is NEVER mutated as a bare scalar without a log entry.
  BrainHealthDecayResult processPostMortem({
    required BrainHealthCounter currentCounter,
    required PostMortemInput postMortem,
    required List<HistoricalEvent> historicalEvents,
    required VulnerabilityIndex currentVulnerability,
    required String dailyDataHash,
    String? causalEventId,
  }) {
    // 1. Objective Classification
    final EventClassification classification = classifyEvent(
      postMortem: postMortem,
      vulnerabilityIndex: currentVulnerability,
      dailyDataHash: dailyDataHash,
    );

    final double dynamicThreshold = calculateDynamicThreshold(
      vulnerabilityIndex: currentVulnerability,
      dailyDataHash: dailyDataHash,
    );
    final double jitter = JitterGenerator.computeJitter(dailyDataHash);
    final double severity = postMortem.computeObjectiveSeverity();

    // 2. Compute Slips in Rolling Window
    final List<HistoricalEvent> priorSlipsInWindow = getSlipsInRollingWindow(
      historicalEvents: historicalEvents,
      eventTimestamp: postMortem.timestamp,
    );

    final double loss;
    final int slipsInWindow;

    if (classification == EventClassification.slip) {
      // Include the current slip
      slipsInWindow = priorSlipsInWindow.length + 1;
      loss = calculateNonLinearSlipLoss(slipsInWindow);
    } else {
      slipsInWindow = priorSlipsInWindow.length;
      loss = baseRelapsePercent.clamp(0.0, 100.0);
    }

    // 3. Compute Resulting Counter Value (strictly clamped to [0.0, 100.0])
    final double previousScore = currentCounter.currentScore.clamp(0.0, 100.0);
    final double newScore = (previousScore - loss).clamp(0.0, 100.0);
    final double roundedNewScore = double.parse(newScore.toStringAsFixed(4));

    final BrainHealthCounter updatedCounter = currentCounter.copyWith(
      currentScore: roundedNewScore,
      lastDecayAt: postMortem.timestamp,
      updatedAt: postMortem.timestamp,
    );

    // 4. Generate Mandatory Decay Log Entry
    final String logId = 'dcl_${postMortem.timestamp.millisecondsSinceEpoch}_${classification.name}';
    final String cause = 'ADAPTIVE_RESET_${classification.name.toUpperCase()}';

    final DecayLogEntry decayLog = DecayLogEntry(
      id: logId,
      counterId: currentCounter.id,
      userId: currentCounter.userId,
      eventId: causalEventId,
      previousScore: previousScore,
      resultingValue: roundedNewScore,
      amount: -loss,
      cause: cause,
      timestamp: postMortem.timestamp,
      metadata: <String, dynamic>{
        'classification': classification.name,
        'objective_severity': severity,
        'dynamic_threshold': dynamicThreshold,
        'jitter': jitter,
        'rolling_slips_count': slipsInWindow,
        'vulnerability_score': currentVulnerability.score,
        'is_degraded_vulnerability': currentVulnerability.isDegradedMode,
      },
    );

    return BrainHealthDecayResult(
      updatedCounter: updatedCounter,
      decayLog: decayLog,
      classification: classification,
      loss: loss,
      slipsInRollingWindow: slipsInWindow,
      dynamicThreshold: dynamicThreshold,
      appliedJitter: jitter,
      objectiveSeverity: severity,
    );
  }
}
