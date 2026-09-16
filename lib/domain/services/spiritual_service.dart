import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../data/database/database_constants.dart';
import '../../data/database/encrypted_database.dart';
import '../models/spiritual_content_models.dart';

class SpiritualService {
  final EncryptedDatabase _database;

  SpiritualService({EncryptedDatabase? database})
      : _database = database ?? EncryptedDatabase();

  /// Canonical Agpeya Hours mapped to time-of-day and circadian risk multiplier.
  static const List<AgpeyaPrayerHour> agpeyaHours = <AgpeyaPrayerHour>[
    AgpeyaPrayerHour(
      hourId: 'prime_1st',
      name: '1st Hour (Prime - Morning)',
      arabicName: 'صلاة باكر',
      typicalStartHour: 5,
      typicalEndHour: 8,
      commemoration: 'The True Light rising, Resurrection of Christ, and dedication of the new day.',
      psalmReference: 'Psalm 5, 27, 63, 113',
      keyGospel: 'John 1:1-17 ("In the beginning was the Word, and the Word was with God...")',
      prayerText: 'O Lord, Light of the morning, illuminate my heart with Your divine knowledge. Cleanse my eyes from shameful sights and guard my mind against the deceit of the adversary.',
      baseCircadianRiskMultiplier: 1.0,
    ),
    AgpeyaPrayerHour(
      hourId: 'terce_3rd',
      name: '3rd Hour (Terce - Mid-Morning)',
      arabicName: 'صلاة الساعة الثالثة',
      typicalStartHour: 9,
      typicalEndHour: 11,
      commemoration: 'The descent of the Holy Spirit upon the Apostles at Pentecost.',
      psalmReference: 'Psalm 19, 20, 23, 24',
      keyGospel: 'John 14:26-31 ("The Holy Spirit, whom the Father will send in My name, will teach you all things...")',
      prayerText: 'Your Holy Spirit, O Lord, whom You sent upon Your holy disciples at the third hour, take not away from us, O Good One, but renew Him within us.',
      baseCircadianRiskMultiplier: 1.1,
    ),
    AgpeyaPrayerHour(
      hourId: 'sext_6th',
      name: '6th Hour (Sext - Midday)',
      arabicName: 'صلاة الساعة السادسة',
      typicalStartHour: 12,
      typicalEndHour: 14,
      commemoration: 'The Crucifixion of our Lord Jesus Christ on the Cross.',
      psalmReference: 'Psalm 54, 57, 61, 84',
      keyGospel: 'Matthew 5:1-16 (The Beatitudes)',
      prayerText: 'O You who on the sixth day and at the sixth hour nailed to the Cross the sin which Adam dared in paradise, tear asunder the handwriting of our sins, O Christ our God, and save us.',
      baseCircadianRiskMultiplier: 1.25,
    ),
    AgpeyaPrayerHour(
      hourId: 'none_9th',
      name: '9th Hour (None - Mid-Afternoon)',
      arabicName: 'صلاة الساعة التاسعة',
      typicalStartHour: 15,
      typicalEndHour: 17,
      commemoration: 'The Death of Christ on the Cross and the Salvation of the Repentant Thief.',
      psalmReference: 'Psalm 96, 99, 100, 116',
      keyGospel: 'Luke 23:39-49 ("Lord, remember me when You come into Your kingdom.")',
      prayerText: 'O You who tasted death in the flesh at the ninth hour for our sake, put to death our carnal senses and desires, O Christ our God, and deliver us.',
      baseCircadianRiskMultiplier: 1.35,
    ),
    AgpeyaPrayerHour(
      hourId: 'vespers_11th',
      name: '11th Hour (Vespers - Sunset)',
      arabicName: 'صلاة الغروب',
      typicalStartHour: 17,
      typicalEndHour: 19,
      commemoration: 'The taking down of Christ from the Cross and preparation for the night.',
      psalmReference: 'Psalm 117, 120, 121, 122',
      keyGospel: 'Luke 4:38-41 (Healing at Sunset)',
      prayerText: 'As the sun sets, O Christ our Master, let the light of Your face not depart from our souls. Grant us repentance and spiritual vigilance before the darkness covers the earth.',
      baseCircadianRiskMultiplier: 1.6,
    ),
    AgpeyaPrayerHour(
      hourId: 'compline_12th',
      name: '12th Hour (Compline - Nightfall)',
      arabicName: 'صلاة النوم',
      typicalStartHour: 20,
      typicalEndHour: 23,
      commemoration: 'The Burial of Christ, the end of life, and preparation for rest.',
      psalmReference: 'Psalm 129, 130, 131, 134',
      keyGospel: 'Luke 2:25-32 ("Lord, now let Your servant depart in peace...")',
      prayerText: 'Behold, I am about to stand before the Just Judge, terrified and trembling because of my many sins. But turn, O my soul, while you still have time on earth, and cry out: God have mercy on me!',
      baseCircadianRiskMultiplier: 1.9,
    ),
    AgpeyaPrayerHour(
      hourId: 'midnight_watch',
      name: 'Midnight Watch (Vigils)',
      arabicName: 'صلاة نصف الليل',
      typicalStartHour: 0,
      typicalEndHour: 4,
      commemoration: 'The Second Coming of Christ and the Parable of the Ten Virgins (Critical High-Risk Vulnerability Window).',
      psalmReference: 'Psalm 119 (Selected sections), Psalm 137',
      keyGospel: 'Matthew 25:1-13 ("Watch therefore, for you know neither the day nor the hour...")',
      prayerText: 'Behold, the Bridegroom comes at midnight, and blessed is that servant whom He finds watching; but unworthy is that servant whom He finds heedless. Arise, O my soul, and cry: Holy, Holy, Holy are You, O God!',
      baseCircadianRiskMultiplier: 2.4,
    ),
  ];

  /// Resolves the canonical Agpeya hour corresponding to the current time.
  AgpeyaPrayerHour getRecommendedAgpeyaHour([DateTime? now]) {
    final DateTime time = now ?? DateTime.now();
    final int currentHour = time.hour;

    for (final AgpeyaPrayerHour h in agpeyaHours) {
      if (h.isCurrentHour(currentHour)) {
        return h;
      }
    }
    return agpeyaHours.first;
  }

  /// Curated Patristic & Biblical Quote Bank tagged by psychological state.
  static const List<SpiritualQuote> quoteBank = <SpiritualQuote>[
    SpiritualQuote(
      id: 'quote_temptation_poemen',
      text: 'A man may seem to be silent, but if his heart is condemning others, he is babbling incessantly. But there may be another who talks from morning till night and yet remains silent, because he speaks nothing that is not beneficial.',
      source: 'Sayings of the Desert Fathers',
      author: 'Abba Poemen the Great',
      tags: <SpiritualQuoteTag>[SpiritualQuoteTag.temptation, SpiritualQuoteTag.anxiety],
      historicalContext: '4th Century Scetis ascetic counsel on inner stillness.',
    ),
    SpiritualQuote(
      id: 'quote_temptation_isaac',
      text: 'Do not be troubled when darkness falls upon your soul; it is through this darkness that divine light is prepared to shine. When temptations arise, flee to the Cross as a bird to its nest.',
      source: 'Ascetical Homilies (Homily 14)',
      author: 'St. Isaac the Syrian',
      tags: <SpiritualQuoteTag>[SpiritualQuoteTag.temptation, SpiritualQuoteTag.despair],
      historicalContext: '7th Century monastic Father on enduring spiritual storms.',
    ),
    SpiritualQuote(
      id: 'quote_despair_chrysostom',
      text: 'Despair is the mother of all sins. It is not sin that destroys a man, but remaining in sin without hope of God’s boundless mercy. For the mercy of God exceeds the sea of our misdeeds as a drop of water compared to the ocean.',
      source: 'Homilies on Repentance (Homily 3)',
      author: 'St. John Chrysostom',
      tags: <SpiritualQuoteTag>[SpiritualQuoteTag.despair, SpiritualQuoteTag.repentance],
      historicalContext: 'Patriarch of Constantinople on overcoming crippling guilt.',
    ),
    SpiritualQuote(
      id: 'quote_temptation_anthony',
      text: 'Whoever has not experienced temptation cannot enter into the Kingdom of Heaven. Without temptations no one can be saved. The furnace tests the potter’s vessels, and the test of temptation cleanses the soul.',
      source: 'Sayings of the Desert Fathers',
      author: 'St. Anthony the Great',
      tags: <SpiritualQuoteTag>[SpiritualQuoteTag.temptation],
      historicalContext: 'Father of Monasticism in the Eastern Desert of Egypt.',
    ),
    SpiritualQuote(
      id: 'quote_repentance_moses',
      text: 'If a man does not bear in mind that he is a sinner, God will not hear his prayer. For true humility is to consider all men superior to oneself and to seek mercy with tears without despair.',
      source: 'Sayings of the Desert Fathers',
      author: 'St. Moses the Strong (the Ethiopian)',
      tags: <SpiritualQuoteTag>[SpiritualQuoteTag.repentance, SpiritualQuoteTag.temptation],
      historicalContext: 'Former bandit who attained transcendent sanctity in Nitria.',
    ),
    SpiritualQuote(
      id: 'quote_gratitude_paul',
      text: 'Rejoice always, pray without ceasing, in everything give thanks; for this is the will of God in Christ Jesus for you. Do not quench the Spirit.',
      source: '1 Thessalonians 5:16-19',
      author: 'Holy Apostle Paul',
      tags: <SpiritualQuoteTag>[SpiritualQuoteTag.gratitude],
      historicalContext: 'Apostolic epistle on continuous interior thanksgiving.',
    ),
    SpiritualQuote(
      id: 'quote_anxiety_peter',
      text: 'Cast all your anxiety on Him, because He cares for you. Be sober, be vigilant; because your adversary the devil walks about like a roaring lion, seeking whom he may devour. Resist him, steadfast in the faith.',
      source: '1 Peter 5:7-9',
      author: 'Holy Apostle Peter',
      tags: <SpiritualQuoteTag>[SpiritualQuoteTag.anxiety, SpiritualQuoteTag.temptation],
      historicalContext: 'Apostolic counsel on vigilance without anxiety.',
    ),
    SpiritualQuote(
      id: 'quote_despair_psalm_42',
      text: 'Why are you cast down, O my soul? And why are you disquieted within me? Hope in God, for I shall yet praise Him, the help of my countenance and my God.',
      source: 'Psalm 42:11',
      author: 'Prophet David',
      tags: <SpiritualQuoteTag>[SpiritualQuoteTag.despair, SpiritualQuoteTag.anxiety, SpiritualQuoteTag.repentance],
      historicalContext: 'Davidic psalm during acute trial.',
    ),
  ];

  List<SpiritualQuote> getQuotesForTag(SpiritualQuoteTag tag) {
    return quoteBank.where((SpiritualQuote q) => q.tags.contains(tag)).toList();
  }

  /// Persists a completed Nightly Examen session into SQLCipher database.
  Future<void> saveNightlyExamen(NightlyExamenEntry entry) async {
    final Database db = await _database.database;
    final int now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((Transaction txn) async {
      // 1. Ensure user exists
      await txn.insert(
        DatabaseConstants.tableUsers,
        <String, dynamic>{
          'id': entry.userId,
          'username': 'Vault User (${entry.userId})',
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // 2. Insert into spiritual log
      await txn.insert(
        DatabaseConstants.tableSpiritualLog,
        <String, dynamic>{
          'id': entry.id,
          'user_id': entry.userId,
          'content_id': 'nightly_examen',
          'duration_seconds': 300,
          'reflections': jsonEncode(entry.toJson()),
          'completed_at': entry.createdAt,
        },
      );
    });
  }

  /// Retrieves recent nightly examen logs for the user.
  Future<List<NightlyExamenEntry>> getRecentExamenEntries(String userId, {int limit = 7}) async {
    final Database db = await _database.database;
    final List<Map<String, dynamic>> rows = await db.query(
      DatabaseConstants.tableSpiritualLog,
      where: 'user_id = ? AND content_id = ?',
      whereArgs: <Object>[userId, 'nightly_examen'],
      orderBy: 'completed_at DESC',
      limit: limit,
    );

    final List<NightlyExamenEntry> entries = <NightlyExamenEntry>[];
    for (final Map<String, dynamic> row in rows) {
      try {
        final String? rawReflections = row['reflections'] as String?;
        if (rawReflections != null) {
          final Map<String, dynamic> parsed = jsonDecode(rawReflections) as Map<String, dynamic>;
          entries.add(NightlyExamenEntry.fromJson(parsed));
        }
      } catch (_) {}
    }
    return entries;
  }
}
