/// Objective behavioral event classification calculated strictly from post-mortem metrics.
///
/// Under the therapeutic domain engine specifications, users NEVER manually pick this label.
enum EventClassification {
  /// Isolated behavioral lapse with limited temporal scope and low escalation.
  slip,

  /// Sustained behavioral regression characterized by prolonged duration, multiple repetitions, or escalation.
  relapse;

  bool get isSlip => this == EventClassification.slip;
  bool get isRelapse => this == EventClassification.relapse;

  String get displayName => isSlip ? 'Slip' : 'Relapse';
}
