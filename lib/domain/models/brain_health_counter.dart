/// Domain entity representing the active Brain Health Counter.
class BrainHealthCounter {
  final String id;
  final String userId;
  final double currentScore;
  final double peakScore;
  final DateTime lastDecayAt;
  final DateTime updatedAt;

  const BrainHealthCounter({
    required this.id,
    required this.userId,
    required this.currentScore,
    required this.peakScore,
    required this.lastDecayAt,
    required this.updatedAt,
  }) : assert(currentScore >= 0.0, 'currentScore cannot be negative'),
       assert(peakScore >= currentScore, 'peakScore must be >= currentScore');

  BrainHealthCounter copyWith({
    String? id,
    String? userId,
    double? currentScore,
    double? peakScore,
    DateTime? lastDecayAt,
    DateTime? updatedAt,
  }) {
    return BrainHealthCounter(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      currentScore: currentScore ?? this.currentScore,
      peakScore: peakScore ?? this.peakScore,
      lastDecayAt: lastDecayAt ?? this.lastDecayAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'BrainHealthCounter(id: $id, score: $currentScore, peak: $peakScore, updated: $updatedAt)';
}
