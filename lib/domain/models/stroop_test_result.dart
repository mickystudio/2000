/// Result of an acute distress intervention via cognitive Stroop test.
class StroopTestResult {
  /// Total duration the user engaged in the Stroop test in seconds.
  final int durationSeconds;

  /// Baseline craving intensity prior to commencing the test (0.0 to 10.0 scale).
  final double initialCravingIntensity;

  /// Craving intensity recorded immediately upon completion or checkpoint (0.0 to 10.0 scale).
  final double postTestCravingIntensity;

  const StroopTestResult({
    required this.durationSeconds,
    required this.initialCravingIntensity,
    required this.postTestCravingIntensity,
  }) : assert(durationSeconds >= 0, 'durationSeconds cannot be negative'),
       assert(initialCravingIntensity >= 0.0 && initialCravingIntensity <= 10.0,
            'initialCravingIntensity must be within [0.0, 10.0]'),
       assert(postTestCravingIntensity >= 0.0 && postTestCravingIntensity <= 10.0,
            'postTestCravingIntensity must be within [0.0, 10.0]');

  @override
  String toString() =>
      'StroopTestResult(duration: ${durationSeconds}s, '
      'pre: $initialCravingIntensity/10, post: $postTestCravingIntensity/10)';
}
