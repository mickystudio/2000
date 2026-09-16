/// Status of Tier 1 escalation evaluation (Pre-fall Warning).
class Tier1Result {
  final bool isTriggered;
  final int consecutiveHighVulnerabilityDays;
  final String diagnosticReason;

  const Tier1Result({
    required this.isTriggered,
    required this.consecutiveHighVulnerabilityDays,
    required this.diagnosticReason,
  });

  @override
  String toString() =>
      'Tier1Result(triggered=$isTriggered, days=$consecutiveHighVulnerabilityDays, reason="$diagnosticReason")';
}

/// Status of Tier 2 escalation evaluation (Human Escalation).
class Tier2Result {
  final bool isTriggered;
  final double postCravingIntensity;
  final int testDurationSeconds;
  final String diagnosticReason;

  const Tier2Result({
    required this.isTriggered,
    required this.postCravingIntensity,
    required this.testDurationSeconds,
    required this.diagnosticReason,
  });

  @override
  String toString() =>
      'Tier2Result(triggered=$isTriggered, craving=$postCravingIntensity/10, duration=${testDurationSeconds}s)';
}

/// Status of Tier 3 escalation evaluation (Clinical Warning & Lock).
class Tier3Result {
  final bool isTriggered;
  final bool lockSelfGuidedMode;
  final int relapsesInWindow;
  final String diagnosticReason;

  const Tier3Result({
    required this.isTriggered,
    required this.lockSelfGuidedMode,
    required this.relapsesInWindow,
    required this.diagnosticReason,
  });

  @override
  String toString() =>
      'Tier3Result(triggered=$isTriggered, lockSelfGuidedMode=$lockSelfGuidedMode, '
      'relapses=$relapsesInWindow, reason="$diagnosticReason")';
}

/// Consolidated outcome of evaluating all therapeutic escalation tiers.
class EscalationEvaluationSummary {
  final Tier1Result tier1;
  final Tier2Result? tier2;
  final Tier3Result tier3;
  final DateTime evaluatedAt;

  const EscalationEvaluationSummary({
    required this.tier1,
    this.tier2,
    required this.tier3,
    required this.evaluatedAt,
  });

  bool get requiresAnyEscalation =>
      tier1.isTriggered || (tier2?.isTriggered ?? false) || tier3.isTriggered;

  bool get isSelfGuidedModeLocked => tier3.lockSelfGuidedMode;
}
