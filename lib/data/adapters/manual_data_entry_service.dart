import 'dart:convert';
import 'dart:developer' as developer;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../domain/models/biometric_sample.dart';
import '../../domain/models/morning_check_in.dart';
import '../database/database_constants.dart';
import '../database/encrypted_database.dart';

/// Service managing fallback data entry for sleep and step counts,
/// persisting manual entries securely into the encrypted SQLCipher database.
class ManualDataEntryService {
  final EncryptedDatabase database;

  ManualDataEntryService({EncryptedDatabase? database})
      : database = database ?? EncryptedDatabase();

  /// Saves a manual biometric report entered by the user.
  /// Persisted as a dedicated structured event in `events`.
  Future<BiometricSample> recordManualBiometrics({
    required String userId,
    required double totalSleepHours,
    required int stepCount,
    double? deepSleepHours,
    double? remSleepHours,
    DateTime? timestamp,
  }) async {
    final DateTime now = timestamp ?? DateTime.now();

    final BiometricSample sample = BiometricSample(
      totalSleepHours: totalSleepHours.clamp(0.0, 24.0),
      deepSleepHours: deepSleepHours?.clamp(0.0, 24.0),
      remSleepHours: remSleepHours?.clamp(0.0, 24.0),
      stepCount: stepCount < 0 ? 0 : stepCount,
      recordedAt: now,
      source: BiometricDataSource.manualEntry,
      metadata: const <String, dynamic>{
        'input_mode': 'MANUAL_FALLBACK_FORM',
      },
    );

    final Database db = await database.database;
    final int nowMs = now.millisecondsSinceEpoch;
    final String eventId = 'bio_manual_${nowMs}_${sample.stepCount}';

    await db.transaction((Transaction txn) async {
      // Ensure user exists
      final List<Map<String, dynamic>> userCheck = await txn.query(
        DatabaseConstants.tableUsers,
        where: 'id = ?',
        whereArgs: <Object>[userId],
        limit: 1,
      );
      if (userCheck.isEmpty) {
        await txn.insert(DatabaseConstants.tableUsers, <String, dynamic>{
          'id': userId,
          'username': 'Vault User ($userId)',
          'email': null,
          'created_at': nowMs,
          'updated_at': nowMs,
          'metadata': null,
        });
      }

      // Record in events table
      await txn.insert(DatabaseConstants.tableEvents, <String, dynamic>{
        'id': eventId,
        'user_id': userId,
        'event_type': 'BIOMETRIC_MANUAL_ENTRY',
        'severity': 'LOW',
        'payload': jsonEncode(sample.toMap()),
        'timestamp': nowMs,
      });
    });

    developer.log(
      'Recorded manual biometric sample for $userId: ${sample.totalSleepHours}h sleep, ${sample.stepCount} steps',
      name: 'ManualDataEntryService',
    );

    return sample;
  }

  /// Retrieves the most recent manual biometric entry from `events`.
  Future<BiometricSample?> getLatestManualBiometricSample({required String userId}) async {
    final Database db = await database.database;
    final List<Map<String, dynamic>> rows = await db.query(
      DatabaseConstants.tableEvents,
      where: 'user_id = ? AND event_type = ?',
      whereArgs: <Object>[userId, 'BIOMETRIC_MANUAL_ENTRY'],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;

    try {
      final String payloadStr = rows.first['payload'] as String;
      final Map<String, dynamic> payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      return BiometricSample.fromMap(payload);
    } catch (e) {
      developer.log('Error decoding manual biometric entry: $e', name: 'ManualDataEntryService');
      return null;
    }
  }

  /// Persists a Morning Self-Assessment Check-in into `daily_checkins`.
  Future<MorningCheckIn> saveMorningCheckIn(MorningCheckIn checkIn) async {
    final Database db = await database.database;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((Transaction txn) async {
      // Ensure user exists
      final List<Map<String, dynamic>> userCheck = await txn.query(
        DatabaseConstants.tableUsers,
        where: 'id = ?',
        whereArgs: <Object>[checkIn.userId],
        limit: 1,
      );
      if (userCheck.isEmpty) {
        await txn.insert(DatabaseConstants.tableUsers, <String, dynamic>{
          'id': checkIn.userId,
          'username': 'Vault User (${checkIn.userId})',
          'email': null,
          'created_at': nowMs,
          'updated_at': nowMs,
          'metadata': null,
        });
      }

      // Upsert into daily_checkins (one entry per user per date)
      final List<Map<String, dynamic>> existing = await txn.query(
        DatabaseConstants.tableDailyCheckins,
        where: 'user_id = ? AND checkin_date = ?',
        whereArgs: <Object>[checkIn.userId, checkIn.checkinDate],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        await txn.update(
          DatabaseConstants.tableDailyCheckins,
          checkIn.toDatabaseRow(),
          where: 'id = ?',
          whereArgs: <Object>[existing.first['id'] as String],
        );
      } else {
        await txn.insert(
          DatabaseConstants.tableDailyCheckins,
          checkIn.toDatabaseRow(),
        );
      }
    });

    developer.log(
      'Saved morning check-in for date ${checkIn.checkinDate}: tier=${checkIn.tier.name}, score=${checkIn.selfReportScore}',
      name: 'ManualDataEntryService',
    );

    return checkIn;
  }

  /// Fetches the latest morning check-in from `daily_checkins`.
  Future<MorningCheckIn?> getLatestMorningCheckIn({required String userId}) async {
    final Database db = await database.database;
    final List<Map<String, dynamic>> rows = await db.query(
      DatabaseConstants.tableDailyCheckins,
      where: 'user_id = ?',
      whereArgs: <Object>[userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return MorningCheckIn.fromDatabaseRow(rows.first);
  }
}
