/// Objective post-mortem clinical inputs recorded following a setback event.
///
/// Under domain requirements, event classification is computed ONLY from these objective inputs.
/// The user must NEVER manually pick the label (slip vs relapse).
class PostMortemInput {
  /// Total duration of the setback episode in minutes.
  final int durationMinutes;

  /// Repetition count of the behavioral lapse within the same session.
  final int repetitionCount;

  /// Clinical escalation flag indicating progression into higher-risk materials or behaviors.
  final bool escalationFlag;

  /// Exact timestamp of the event episode.
  final DateTime timestamp;

  const PostMortemInput({
    required this.durationMinutes,
    required this.repetitionCount,
    required this.escalationFlag,
    required this.timestamp,
  }) : assert(durationMinutes >= 1, 'durationMinutes must be at least 1 minute for a recorded setback'),
       assert(repetitionCount >= 1, 'repetitionCount must be at least 1');

  /// Computes an objective composite severity metric from post-mortem inputs.
  ///
  /// Anti-gaming & physiological consistency:
  ///   Behavioral repetitions require cognitive/behavioral cycle time. If a user inputs
  ///   an abnormally compressed duration (e.g. 1 minute for 4 repetitions), the effective
  ///   duration is floored to at least 2 minutes per repetition (minimum physiological cycle).
  ///
  /// Formula:
  ///   effectiveDuration = max(durationMinutes, repetitionCount * 2)
  ///   objectiveSeverity = effectiveDuration * 1.0 + (repetitionCount * 15.0) + (escalationFlag ? 50.0 : 0.0)
  double computeObjectiveSeverity() {
    final int physiologicalMinimum = repetitionCount * 2;
    final int effectiveDuration = durationMinutes < physiologicalMinimum ? physiologicalMinimum : durationMinutes;
    return effectiveDuration + (repetitionCount * 15.0) + (escalationFlag ? 50.0 : 0.0);
  }

  @override
  String toString() =>
      'PostMortemInput(duration: ${durationMinutes}m, reps: $repetitionCount, '
      'escalation: $escalationFlag, timestamp: ${timestamp.toIso8601String()})';
}
