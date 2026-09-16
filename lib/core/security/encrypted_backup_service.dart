import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../data/database/database_constants.dart';
import '../../data/database/encrypted_database.dart';

class EncryptedBackupPayload {
  final String version;
  final String saltHex;
  final String ivHex;
  final String ciphertext;
  final String hmacHex;
  final int exportedAt;

  const EncryptedBackupPayload({
    required this.version,
    required this.saltHex,
    required this.ivHex,
    required this.ciphertext,
    required this.hmacHex,
    required this.exportedAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'salt_hex': saltHex,
        'iv_hex': ivHex,
        'ciphertext': ciphertext,
        'hmac_hex': hmacHex,
        'exported_at': exportedAt,
      };

  factory EncryptedBackupPayload.fromJson(Map<String, dynamic> json) {
    return EncryptedBackupPayload(
      version: json['version'] as String? ?? '1.0',
      saltHex: json['salt_hex'] as String,
      ivHex: json['iv_hex'] as String,
      ciphertext: json['ciphertext'] as String,
      hmacHex: json['hmac_hex'] as String,
      exportedAt: (json['exported_at'] as num).toInt(),
    );
  }
}

class EncryptedBackupService {
  static const String currentBackupVersion = 'AES256_V1';
  static const int kdfIterations = 50000;

  final EncryptedDatabase _database;

  EncryptedBackupService({EncryptedDatabase? database})
      : _database = database ?? EncryptedDatabase();

  /// Generates a cryptographically strong 32-byte key from user's momentary passphrase and salt.
  Uint8List _deriveKey(String passphrase, Uint8List salt) {
    // PBKDF2-like iterative SHA-256 HMAC stretching
    final List<int> passBytes = utf8.encode(passphrase);
    var hmac = Hmac(sha256, passBytes);
    var current = hmac.convert(salt).bytes;

    for (int i = 0; i < kdfIterations; i++) {
      hmac = Hmac(sha256, passBytes);
      current = hmac.convert(current).bytes;
    }
    return Uint8List.fromList(current);
  }

  Uint8List _generateRandomBytes(int length) {
    final Random random = Random.secure();
    final Uint8List bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Exports entire SQLCipher database state into an AES-256 authenticated encrypted JSON payload.
  /// The user's personal passphrase is used momentarily for encryption and is never saved.
  Future<String> exportEncryptedBackup({
    required String passphrase,
    required String userId,
  }) async {
    if (passphrase.trim().length < 6) {
      throw ArgumentError('Passphrase must be at least 6 characters long');
    }

    final Database db = await _database.database;
    final Map<String, dynamic> dump = <String, dynamic>{
      'exported_at': DateTime.now().toIso8601String(),
      'user_id': userId,
      'tables': <String, dynamic>{},
    };

    // Extract all relational tables
    for (final String table in DatabaseConstants.allTables) {
      final List<Map<String, dynamic>> rows = await db.query(table);
      dump['tables'][table] = rows;
    }

    final String plaintextJson = jsonEncode(dump);
    final Uint8List salt = _generateRandomBytes(16);
    final Uint8List ivBytes = _generateRandomBytes(16);

    final Uint8List derivedKey = _deriveKey(passphrase, salt);
    final enc.Key key = enc.Key(derivedKey);
    final enc.IV iv = enc.IV(ivBytes);

    final enc.Encrypter encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final enc.Encrypted encrypted = encrypter.encrypt(plaintextJson, iv: iv);

    // Compute HMAC-SHA256 for authenticated ciphertext verification
    final Hmac hmacCalculator = Hmac(sha256, derivedKey);
    final String hmacDigest = hmacCalculator.convert(encrypted.bytes).toString();

    final EncryptedBackupPayload payload = EncryptedBackupPayload(
      version: currentBackupVersion,
      saltHex: _bytesToHex(salt),
      ivHex: _bytesToHex(ivBytes),
      ciphertext: encrypted.base64,
      hmacHex: hmacDigest,
      exportedAt: DateTime.now().millisecondsSinceEpoch,
    );

    developer.log('Generated AES-256 encrypted backup payload (${payload.ciphertext.length} chars)',
        name: 'EncryptedBackupService');

    return jsonEncode(payload.toJson());
  }

  /// Validates passphrase, decrypts backup payload, and atomically restores full database state.
  Future<bool> importEncryptedBackup({
    required String backupJsonString,
    required String passphrase,
  }) async {
    try {
      if (passphrase.trim().isEmpty) {
        throw ArgumentError('Passphrase is required for decryption');
      }

      final Map<String, dynamic> decodedJson = jsonDecode(backupJsonString) as Map<String, dynamic>;
      final EncryptedBackupPayload payload = EncryptedBackupPayload.fromJson(decodedJson);

      final Uint8List salt = _hexToBytes(payload.saltHex);
      final Uint8List ivBytes = _hexToBytes(payload.ivHex);
      final Uint8List derivedKey = _deriveKey(passphrase, salt);

      // Verify HMAC before decrypting to protect against tampering
      final enc.Encrypted encryptedData = enc.Encrypted.fromBase64(payload.ciphertext);
      final Hmac hmacCalculator = Hmac(sha256, derivedKey);
      final String calculatedHmac = hmacCalculator.convert(encryptedData.bytes).toString();

      if (calculatedHmac != payload.hmacHex) {
        developer.log('HMAC verification failed. Incorrect passphrase or corrupted ciphertext.',
            name: 'EncryptedBackupService');
        return false;
      }

      final enc.Key key = enc.Key(derivedKey);
      final enc.IV iv = enc.IV(ivBytes);
      final enc.Encrypter decrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final String decryptedPlaintext = decrypter.decrypt(encryptedData, iv: iv);
      final Map<String, dynamic> restoredData = jsonDecode(decryptedPlaintext) as Map<String, dynamic>;
      final Map<String, dynamic> tables = restoredData['tables'] as Map<String, dynamic>;

      final Database db = await _database.database;

      await db.transaction((Transaction txn) async {
        // Clear existing tables in dependency order
        for (final String table in DatabaseConstants.allTables.reversed) {
          await txn.delete(table);
        }

        // Restore tables
        for (final String table in DatabaseConstants.allTables) {
          final List<dynamic>? rows = tables[table] as List<dynamic>?;
          if (rows != null) {
            for (final dynamic rawRow in rows) {
              final Map<String, dynamic> row = Map<String, dynamic>.from(rawRow as Map);
              await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }
      });

      developer.log('Encrypted backup successfully decrypted and restored into SQLCipher.',
          name: 'EncryptedBackupService');
      return true;
    } catch (e, stack) {
      developer.log('Decryption or restore failed: $e',
          name: 'EncryptedBackupService', error: e, stackTrace: stack);
      return false;
    }
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hex) {
    final List<int> result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(result);
  }
}
