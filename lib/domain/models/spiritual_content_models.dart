enum SpiritualQuoteTag {
  temptation,
  despair,
  gratitude,
  anxiety,
  repentance;

  String get displayName {
    switch (this) {
      case SpiritualQuoteTag.temptation:
        return 'Temptation & Warfare';
      case SpiritualQuoteTag.despair:
        return 'Despair & Darkness';
      case SpiritualQuoteTag.gratitude:
        return 'Gratitude & Joy';
      case SpiritualQuoteTag.anxiety:
        return 'Anxiety & Restlessness';
      case SpiritualQuoteTag.repentance:
        return 'Repentance & Mercy';
    }
  }
}

class SpiritualQuote {
  final String id;
  final String text;
  final String source;
  final String author;
  final List<SpiritualQuoteTag> tags;
  final String? historicalContext;

  const SpiritualQuote({
    required this.id,
    required this.text,
    required this.source,
    required this.author,
    required this.tags,
    this.historicalContext,
  });
}

class AgpeyaPrayerHour {
  final String hourId;
  final String name;
  final String arabicName;
  final int typicalStartHour; // 0-23
  final int typicalEndHour;
  final String commemoration;
  final String psalmReference;
  final String keyGospel;
  final String prayerText;
  final double baseCircadianRiskMultiplier;

  const AgpeyaPrayerHour({
    required this.hourId,
    required this.name,
    required this.arabicName,
    required this.typicalStartHour,
    required this.typicalEndHour,
    required this.commemoration,
    required this.psalmReference,
    required this.keyGospel,
    required this.prayerText,
    required this.baseCircadianRiskMultiplier,
  });

  bool isCurrentHour(int currentHourOfDay) {
    if (typicalStartHour <= typicalEndHour) {
      return currentHourOfDay >= typicalStartHour && currentHourOfDay <= typicalEndHour;
    } else {
      // Wraps around midnight (e.g., 23 to 3)
      return currentHourOfDay >= typicalStartHour || currentHourOfDay <= typicalEndHour;
    }
  }
}

class NightlyExamenEntry {
  final String id;
  final String userId;
  final DateTime date;
  final List<String> gratitudeItems; // 3 specific mercies
  final String logismoiReflection; // Examination of invading thoughts/triggers
  final String prayerOfRepentance;
  final String tomorrowCommitment;
  final int createdAt;

  const NightlyExamenEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.gratitudeItems,
    required this.logismoiReflection,
    required this.prayerOfRepentance,
    required this.tomorrowCommitment,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'date': date.toIso8601String(),
        'gratitude_items': gratitudeItems,
        'logismoi_reflection': logismoiReflection,
        'prayer_of_repentance': prayerOfRepentance,
        'tomorrow_commitment': tomorrowCommitment,
        'created_at': createdAt,
      };

  factory NightlyExamenEntry.fromJson(Map<String, dynamic> json) {
    return NightlyExamenEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      gratitudeItems: List<String>.from(json['gratitude_items'] as List),
      logismoiReflection: json['logismoi_reflection'] as String? ?? '',
      prayerOfRepentance: json['prayer_of_repentance'] as String? ?? '',
      tomorrowCommitment: json['tomorrow_commitment'] as String? ?? '',
      createdAt: (json['created_at'] as num).toInt(),
    );
  }
}
