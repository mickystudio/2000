import 'dart:convert';

/// 3-tier clinical mood/energy tier for morning self-assessment.
///
/// Tiers:
/// - [low]: High psychometric vulnerability / low energy / high craving risk (numeric baseline ~85.0).
/// - [neutral]: Moderate stability / normal baseline energy (numeric baseline ~50.0).
/// - [resilient]: High mental clarity / robust executive control / low craving risk (numeric baseline ~15.0).
enum MorningAssessmentTier {
  low,
  neutral,
  resilient,
}

extension MorningAssessmentTierX on MorningAssessmentTier {
  String get label {
    switch (this) {
      case MorningAssessmentTier.low:
        return 'Low Energy / High Stress';
      case MorningAssessmentTier.neutral:
        return 'Balanced / Steady';
      case MorningAssessmentTier.resilient:
        return 'High Clarity / Resilient';
    }
  }

  /// Converts tier to standardized SelfReportScore (0.0 to 100.0) where higher = greater vulnerability.
  double get defaultVulnerabilityScore {
    switch (this) {
      case MorningAssessmentTier.low:
        return 85.0;
      case MorningAssessmentTier.neutral:
        return 50.0;
      case MorningAssessmentTier.resilient:
        return 15.0;
    }
  }
}

/// Morning self-assessment model persisted directly to `daily_checkins` in SQLCipher.
class MorningCheckIn {
  /// Documented clinical neutral baseline fallback (50.0).
  ///
  /// When a user has not yet recorded a morning check-in for the day, or skips assessment,
  /// the system MUST fall back to this documented neutral midpoint (50.0).
  /// Under no circumstance does the system silently output 0.0, which would falsely indicate
  /// complete immunity or zero vulnerability.
  static const double defaultNeutralScore = 50.0;

  final String id;
  final String userId;
  final String checkinDate; // YYYY-MM-DD
  final MorningAssessmentTier tier;
  final double selfReportScore; // 0.0 to 100.0
  final double resilienceRating; // 0.0 to 10.0
  final String? notes;
  final DateTime createdAt;

  const MorningCheckIn({
    required this.id,
    required this.userId,
    required this.checkinDate,
    required this.tier,
    required this.selfReportScore,
    required this.resilienceRating,
    this.notes,
    required this.createdAt,
  }) : assert(selfReportScore >= 0.0 && selfReportScore <= 100.0, 'selfReportScore must be [0, 100]'),
       assert(resilienceRating >= 0.0 && resilienceRating <= 10.0, 'resilienceRating must be [0, 10]');

  /// Creates a check-in directly from a single-tap 3-tier choice.
  factory MorningCheckIn.fromTierTap({
    required String id,
    required String userId,
    required MorningAssessmentTier tier,
    DateTime? timestamp,
    String? notes,
  }) {
    final DateTime now = timestamp ?? DateTime.now();
    final String dateStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final double selfReportScore = tier.defaultVulnerabilityScore;
    final double resilience = (100.0 - selfReportScore) / 10.0;

    return MorningCheckIn(
      id: id,
      userId: userId,
      checkinDate: dateStr,
      tier: tier,
      selfReportScore: selfReportScore,
      resilienceRating: double.parse(resilience.toStringAsFixed(2)),
      notes: notes,
      createdAt: now,
    );
  }

  Map<String, dynamic> toDatabaseRow() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'checkin_date': checkinDate,
      'mood_score': selfReportScore,
      'resilience_rating': resilienceRating,
      'notes': jsonEncode(<String, dynamic>{
        'tier': tier.name,
        'user_notes': notes,
      }),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory MorningCheckIn.fromDatabaseRow(Map<String, dynamic> row) {
    MorningAssessmentTier parsedTier = MorningAssessmentTier.neutral;
    String? userNotes;

    final dynamic rawNotes = row['notes'];
    if (rawNotes is String && rawNotes.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(rawNotes);
        if (decoded is Map<String, dynamic>) {
          final String? tierName = decoded['tier'] as String?;
          if (tierName != null) {
            parsedTier = MorningAssessmentTier.values.firstWhere(
              (MorningAssessmentTier t) => t.name == tierName,
              orElse: () => MorningAssessmentTier.neutral,
            );
          }
          userNotes = decoded['user_notes'] as String?;
        } else {
          userNotes = rawNotes;
        }
      } catch (_) {
        userNotes = rawNotes;
      }
    }

    return MorningCheckIn(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      checkinDate: row['checkin_date'] as String,
      tier: parsedTier,
      selfReportScore: (row['mood_score'] as num).toDouble(),
      resilienceRating: (row['resilience_rating'] as num).toDouble(),
      notes: userNotes,
      createdAt: DateTime.fromMillisecondsSinceEpoch((row['created_at'] as num).toInt()),
    );
  }
}
