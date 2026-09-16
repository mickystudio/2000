import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../core/security/master_key_storage.dart';
import 'database_constants.dart';

class EncryptedDatabase {
  static final EncryptedDatabase _instance = EncryptedDatabase._internal(
    MasterKeyStorage(),
  );

  final MasterKeyStorage _masterKeyStorage;
  Database? _db;

  factory EncryptedDatabase({MasterKeyStorage? masterKeyStorage}) {
    if (masterKeyStorage != null) {
      return EncryptedDatabase._internal(masterKeyStorage);
    }
    return _instance;
  }

  EncryptedDatabase._internal(this._masterKeyStorage);

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initializeDatabase();
    return _db!;
  }

  Future<String> getDatabasePath() async {
    final String databasesPath = await getDatabasesPath();
    return p.join(databasesPath, DatabaseConstants.databaseFileName);
  }

  Future<Database> _initializeDatabase() async {
    final String dbPath = await getDatabasePath();
    final String masterKey = await _masterKeyStorage.getOrCreateMasterKey();

    developer.log('Initializing SQLCipher database at: $dbPath', name: 'EncryptedDatabase');

    final Database database = await openDatabase(
      dbPath,
      password: masterKey,
      version: DatabaseConstants.databaseVersion,
      onConfigure: (Database db) async {
        await db.rawQuery('PRAGMA cipher_compatibility = 4;');
        await db.rawQuery('PRAGMA kdf_iter = 256000;');
        await db.rawQuery('PRAGMA cipher_memory_security = ON;');
        await db.rawQuery('PRAGMA foreign_keys = ON;');
      },
      onCreate: (Database db, int version) async {
        developer.log('Creating database schema version $version', name: 'EncryptedDatabase');
        await db.execute(DatabaseConstants.createTableUsers);
        await db.execute(DatabaseConstants.createTableDailyCheckins);
        await db.execute(DatabaseConstants.createTableEvents);
        await db.execute(DatabaseConstants.createTableBrainHealthCounter);
        await db.execute(DatabaseConstants.createTableDecayLog);
        await db.execute(DatabaseConstants.createTableSpiritualContent);
        await db.execute(DatabaseConstants.createTableSpiritualLog);
        await db.execute(DatabaseConstants.createTableSosSessions);

        for (final String indexSql in DatabaseConstants.createIndices) {
          await db.execute(indexSql);
        }

        await db.execute(DatabaseConstants.createDecayTrigger);
        developer.log('Schema, indices, and triggers instantiated successfully', name: 'EncryptedDatabase');
      },
    );

    return database;
  }

  Future<void> updateBrainHealthCounter({
    required String userId,
    required double newScore,
    required String cause,
    String? eventId,
    Map<String, dynamic>? metadata,
  }) async {
    final Database db = await database;
    final int now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((Transaction txn) async {
      // Ensure user exists for foreign key constraints
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
          'created_at': now,
          'updated_at': now,
          'metadata': null,
        });
      }

      // If an eventId is not supplied, create a causal event record to link the decay modification
      String causalEventId = eventId ?? '';
      if (causalEventId.isEmpty) {
        causalEventId = _generateUuid('evt');
        await txn.insert(DatabaseConstants.tableEvents, <String, dynamic>{
          'id': causalEventId,
          'user_id': userId,
          'event_type': 'BRAIN_HEALTH_DECAY_TRIGGER',
          'severity': 'MEDIUM',
          'payload': jsonEncode(<String, dynamic>{
            'cause': cause,
            'target_score': newScore,
            'metadata': metadata,
          }),
          'timestamp': now,
        });
      }

      final List<Map<String, dynamic>> existing = await txn.query(
        DatabaseConstants.tableBrainHealthCounter,
        where: 'user_id = ?',
        whereArgs: <Object>[userId],
        limit: 1,
      );

      final String counterId;
      final double previousScore;
      final double peakScore;

      if (existing.isEmpty) {
        counterId = _generateUuid('bhc');
        previousScore = 0.0;
        peakScore = newScore;

        await txn.insert(DatabaseConstants.tableBrainHealthCounter, <String, dynamic>{
          'id': counterId,
          'user_id': userId,
          'current_score': newScore,
          'peak_score': peakScore,
          'last_decay_at': now,
          'updated_at': now,
        });
      } else {
        counterId = existing.first['id'] as String;
        previousScore = (existing.first['current_score'] as num).toDouble();
        final double currentPeak = (existing.first['peak_score'] as num).toDouble();
        peakScore = newScore > currentPeak ? newScore : currentPeak;

        await txn.rawUpdate(
          '''
          UPDATE ${DatabaseConstants.tableBrainHealthCounter}
          SET current_score = ?, peak_score = ?, last_decay_at = ?, updated_at = ?
          WHERE id = ?
          ''',
          <Object>[newScore, peakScore, now, now, counterId],
        );
      }

      final double delta = double.parse((newScore - previousScore).toStringAsFixed(4));
      final String logId = _generateUuid('dcl');
      final String? serializedMetadata = metadata != null ? jsonEncode(metadata) : null;

      // Immutable decay log entry explicitly referencing the causal event_id
      await txn.insert(DatabaseConstants.tableDecayLog, <String, dynamic>{
        'id': logId,
        'counter_id': counterId,
        'user_id': userId,
        'event_id': causalEventId,
        'previous_score': previousScore,
        'new_score': newScore,
        'delta': delta,
        'cause': cause,
        'timestamp': now,
        'metadata': serializedMetadata,
      });

      developer.log(
        'Recorded brain health counter modification: prev=$previousScore, new=$newScore, delta=$delta, cause=$cause, eventId=$causalEventId',
        name: 'EncryptedDatabase',
      );
    });
  }

  Future<void> recordDecay({
    required String userId,
    required double decayAmount,
    required String cause,
    String? eventId,
    Map<String, dynamic>? metadata,
  }) async {
    final Database db = await database;
    final List<Map<String, dynamic>> existing = await db.query(
      DatabaseConstants.tableBrainHealthCounter,
      where: 'user_id = ?',
      whereArgs: <Object>[userId],
      limit: 1,
    );

    final double currentScore = existing.isNotEmpty
        ? (existing.first['current_score'] as num).toDouble()
        : 100.0;

    final double updatedScore = (currentScore - decayAmount).clamp(0.0, 1000.0);
    await updateBrainHealthCounter(
      userId: userId,
      newScore: updatedScore,
      cause: cause,
      eventId: eventId,
      metadata: metadata,
    );
  }

  Future<List<Map<String, dynamic>>> getDecayLogs({
    String? userId,
    int limit = 50,
  }) async {
    final Database db = await database;
    if (userId != null) {
      return await db.query(
        DatabaseConstants.tableDecayLog,
        where: 'user_id = ?',
        whereArgs: <Object>[userId],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    }
    return await db.query(
      DatabaseConstants.tableDecayLog,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  Future<Map<String, int>> getTableRowCounts() async {
    final Database db = await database;
    final Map<String, int> counts = <String, int>{};

    for (final String table in DatabaseConstants.allTables) {
      final List<Map<String, dynamic>> result = await db.rawQuery('SELECT COUNT(*) as count FROM $table;');
      final int count = Sqflite.firstIntValue(result) ?? 0;
      counts[table] = count;
    }

    return counts;
  }

  Future<bool> verifyEncryption() async {
    try {
      final String dbPath = await getDatabasePath();
      final File file = File(dbPath);
      if (!await file.exists()) {
        return false;
      }

      final RandomAccessFile raf = await file.open(mode: FileMode.read);
      final Uint8List headerBytes = await raf.read(16);
      await raf.close();

      if (headerBytes.length < 16) {
        return false;
      }

      // Plaintext SQLite databases strictly begin with ASCII "SQLite format 3\000"
      final String headerAscii = String.fromCharCodes(headerBytes);
      final bool startsWithSqliteHeader = headerAscii.startsWith('SQLite format 3');

      // In SQLCipher, page 1 is completely encrypted with random IV/salt, so it NEVER starts with SQLite format 3
      return !startsWithSqliteHeader;
    } catch (e) {
      developer.log('Verification check error: $e', name: 'EncryptedDatabase');
      return false;
    }
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      developer.log('Encrypted database successfully closed', name: 'EncryptedDatabase');
    }
  }

  static String _generateUuid([String prefix = 'id']) {
    final int now = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${now}_${(now % 100000)}';
  }
}
