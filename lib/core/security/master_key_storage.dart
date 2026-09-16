import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MasterKeyStorage {
  static const String _storageKeyAlias = 'sqlcipher_256_master_key_v1';

  final FlutterSecureStorage _secureStorage;

  static final MasterKeyStorage _instance = MasterKeyStorage._internal(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        resetOnError: false,
        keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );

  factory MasterKeyStorage({FlutterSecureStorage? storage}) {
    if (storage != null) {
      return MasterKeyStorage._internal(storage);
    }
    return _instance;
  }

  MasterKeyStorage._internal(this._secureStorage);

  Future<String> getOrCreateMasterKey() async {
    try {
      final String? existingKey = await _secureStorage.read(key: _storageKeyAlias);
      if (existingKey != null && _isValid256BitHex(existingKey)) {
        developer.log('MasterKeyStorage: Retrieved existing 256-bit AES master key from Android Keystore', name: 'MasterKeyStorage');
        return existingKey;
      }

      final String newlyGeneratedKey = _generateCryptographic256BitHex();
      await _secureStorage.write(
        key: _storageKeyAlias,
        value: newlyGeneratedKey,
      );
      developer.log('MasterKeyStorage: Generated and securely persisted new 256-bit AES master key in Android Keystore', name: 'MasterKeyStorage');
      return newlyGeneratedKey;
    } catch (e, stackTrace) {
      developer.log('MasterKeyStorage: Critical error accessing Keystore', name: 'MasterKeyStorage', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<bool> hasMasterKey() async {
    try {
      final String? key = await _secureStorage.read(key: _storageKeyAlias);
      return key != null && _isValid256BitHex(key);
    } catch (e) {
      developer.log('MasterKeyStorage: Error querying key presence: $e', name: 'MasterKeyStorage');
      return false;
    }
  }

  Future<String?> getMasterKeyFingerprint() async {
    try {
      final String? key = await _secureStorage.read(key: _storageKeyAlias);
      if (key == null) return null;
      final Digest digest = sha256.convert(utf8.encode(key));
      return digest.toString();
    } catch (e) {
      developer.log('MasterKeyStorage: Error computing master key fingerprint: $e', name: 'MasterKeyStorage');
      return null;
    }
  }

  Future<void> deleteMasterKey() async {
    await _secureStorage.delete(key: _storageKeyAlias);
    developer.log('MasterKeyStorage: Cryptographic key erased from Keystore', name: 'MasterKeyStorage');
  }

  static String _generateCryptographic256BitHex() {
    final Random secureRandom = Random.secure();
    final List<int> keyBytes = List<int>.generate(32, (_) => secureRandom.nextInt(256));
    return keyBytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool _isValid256BitHex(String hexKey) {
    if (hexKey.length != 64) return false;
    final RegExp hexRegex = RegExp(r'^[0-9a-fA-F]{64}$');
    return hexRegex.hasMatch(hexKey);
  }
}
