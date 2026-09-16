import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../core/security/biometric_auth_service.dart';
import '../core/security/master_key_storage.dart';
import '../core/security/security_service.dart';
import '../data/adapters/unified_bio_data_repository.dart';
import '../data/database/database_constants.dart';
import '../data/database/encrypted_database.dart';
import '../domain/models/sync_status.dart';
import '../domain/repositories/bio_data_repository.dart';

class AuditDiagnosticPayload {
  final String timestampIso;
  final String schemaHashSha256;
  final bool isDatabaseEncrypted;
  final String databasePath;
  final int databaseSizeBytes;
  final Map<String, dynamic> securityFlagsState;
  final Map<String, dynamic> biometricSyncState;
  final Map<String, int> tableRowCounts;
  final List<Map<String, dynamic>> recentDecayLogs;

  const AuditDiagnosticPayload({
    required this.timestampIso,
    required this.schemaHashSha256,
    required this.isDatabaseEncrypted,
    required this.databasePath,
    required this.databaseSizeBytes,
    required this.securityFlagsState,
    required this.biometricSyncState,
    required this.tableRowCounts,
    required this.recentDecayLogs,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'audit_metadata': <String, dynamic>{
        'generated_at': timestampIso,
        'phase': 'PHASE_3_BIOMETRICS_AND_SYNC_ENGINE',
        'schema_version': DatabaseConstants.databaseVersion,
      },
      'database_status': <String, dynamic>{
        'encrypted': isDatabaseEncrypted,
        'cipher': 'SQLCipher 256-bit AES-GCM/CBC (KDF 256000 iter)',
        'file_path': databasePath,
        'file_size_bytes': databaseSizeBytes,
      },
      'schema_integrity': <String, dynamic>{
        'schema_hash_sha256': schemaHashSha256,
        'tables_registered': DatabaseConstants.allTables,
      },
      'hardware_security_flags': securityFlagsState,
      'biometric_sync_status': biometricSyncState,
      'table_row_counts': tableRowCounts,
      'recent_decay_audit_trail': recentDecayLogs,
    };
  }

  String toJson({bool pretty = true}) {
    final Map<String, dynamic> map = toMap();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }
    return jsonEncode(map);
  }

  String toMarkdown() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('# Security & Database Diagnostic Audit Report');
    buffer.writeln();
    buffer.writeln('- **Timestamp**: `$timestampIso`');
    buffer.writeln('- **Phase**: `Phase 3 - Biometrics, Huawei Health Kit SDK & Sync Engine`');
    buffer.writeln('- **Schema Hash (SHA-256)**: `$schemaHashSha256`');
    buffer.writeln();

    buffer.writeln('## 1. Storage & Encryption Status');
    buffer.writeln();
    buffer.writeln('| Property | Status / Value |');
    buffer.writeln('| --- | --- |');
    buffer.writeln('| Database Encrypted | ${isDatabaseEncrypted ? "✅ Verified (SQLCipher ciphertext verified)" : "❌ Unencrypted or missing"} |');
    buffer.writeln('| Database File Path | `$databasePath` |');
    buffer.writeln('| Database File Size | `$databaseSizeBytes bytes` |');
    buffer.writeln('| Key Derivation | `PBKDF2-HMAC-SHA512 (256,000 iterations)` |');
    buffer.writeln();

    buffer.writeln('## 2. Hardware Security & Platform Flags');
    buffer.writeln();
    buffer.writeln('| Security Subsystem | State | Details |');
    buffer.writeln('| --- | --- | --- |');
    buffer.writeln('| Android `FLAG_SECURE` | ${securityFlagsState['flag_secure_enabled'] == true ? "ACTIVE (Native Protected)" : "INACTIVE"} | Screenshot & Screen Recording Prevention |');
    buffer.writeln('| Keystore Master Key | ${securityFlagsState['master_key_present'] == true ? "PRESENT (256-bit AES in Android Keystore)" : "MISSING"} | Checksum: `${securityFlagsState['master_key_fingerprint_redacted'] ?? "N/A"}` |');
    buffer.writeln('| Biometric Hardware | ${securityFlagsState['biometric_hardware_available'] == true ? "AVAILABLE" : "UNAVAILABLE / EMULATOR"} | Supported Types: `${securityFlagsState['enrolled_biometrics']}` |');
    buffer.writeln();

    buffer.writeln('## 3. Biometric Sync Engine Status');
    buffer.writeln();
    buffer.writeln('| Channel / Source | Status | Details |');
    buffer.writeln('| --- | --- | --- |');
    buffer.writeln('| Biometric Pipeline Status | `${biometricSyncState['status_code']}` | ${biometricSyncState['display_name']} |');
    buffer.writeln('| Native HMS Health Kit | ${biometricSyncState['hms_available'] == true ? "AVAILABLE" : "UNAVAILABLE"} | Primary SDK Integration |');
    buffer.writeln('| HMS OAuth Authorization | ${biometricSyncState['hms_authorized'] == true ? "AUTHORIZED" : "UNAUTHORIZED"} | Sleep & Step Scopes |');
    buffer.writeln('| Staleness Threshold | `20 Hours` | Automated Fallback Trigger |');
    buffer.writeln('| Last Biometric Recorded | `${biometricSyncState['last_reading_time'] ?? "None"}` | Source: `${biometricSyncState['last_reading_source'] ?? "None"}` |');
    buffer.writeln();

    buffer.writeln('## 4. Table Row Counts');
    buffer.writeln();
    buffer.writeln('| Table Name | Row Count |');
    buffer.writeln('| --- | --- |');
    tableRowCounts.forEach((String table, int count) {
      buffer.writeln('| `$table` | `$count` |');
    });
    buffer.writeln();

    buffer.writeln('## 5. Recent Decay Log Modifications');
    buffer.writeln();
    if (recentDecayLogs.isEmpty) {
      buffer.writeln('*No decay modifications recorded yet.*');
    } else {
      buffer.writeln('| Timestamp | User ID | Causal Event ID | Previous | New | Delta | Cause |');
      buffer.writeln('| --- | --- | --- | --- | --- | --- | --- |');
      for (final Map<String, dynamic> log in recentDecayLogs) {
        final int ts = log['timestamp'] as int? ?? 0;
        final String formattedTime = DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String();
        buffer.writeln('| `$formattedTime` | `${log['user_id']}` | `${log['event_id'] ?? "AUTO_GEN"}` | `${log['previous_score']}` | `${log['new_score']}` | `${log['delta']}` | `${log['cause']}` |');
      }
    }
    buffer.writeln();

    return buffer.toString();
  }
}

class AuditReportService {
  final EncryptedDatabase _database;
  final SecurityService _securityService;
  final BiometricAuthService _biometricService;
  final MasterKeyStorage _masterKeyStorage;
  final BioDataRepository _bioDataRepository;

  static final AuditReportService _instance = AuditReportService._internal(
    EncryptedDatabase(),
    SecurityService(),
    BiometricAuthService(),
    MasterKeyStorage(),
    UnifiedBioDataRepository(),
  );

  factory AuditReportService({
    EncryptedDatabase? database,
    SecurityService? securityService,
    BiometricAuthService? biometricService,
    MasterKeyStorage? masterKeyStorage,
    BioDataRepository? bioDataRepository,
  }) {
    if (database != null ||
        securityService != null ||
        biometricService != null ||
        masterKeyStorage != null ||
        bioDataRepository != null) {
      return AuditReportService._internal(
        database ?? EncryptedDatabase(),
        securityService ?? SecurityService(),
        biometricService ?? BiometricAuthService(),
        masterKeyStorage ?? MasterKeyStorage(),
        bioDataRepository ?? UnifiedBioDataRepository(),
      );
    }
    return _instance;
  }

  AuditReportService._internal(
    this._database,
    this._securityService,
    this._biometricService,
    this._masterKeyStorage,
    this._bioDataRepository,
  );

  Future<AuditDiagnosticPayload> generateDiagnosticPayload({String userId = 'usr_default_01'}) async {
    developer.log('Generating diagnostic audit payload', name: 'AuditReportService');

    final String timestampIso = DateTime.now().toUtc().toIso8601String();
    final String schemaHash = computeSchemaHash();

    final String dbPath = await _database.getDatabasePath();
    final File dbFile = File(dbPath);
    final int dbSize = await dbFile.exists() ? await dbFile.length() : 0;
    final bool isEncrypted = await _database.verifyEncryption();

    final bool flagSecureEnabled = await _securityService.isSecureScreenEnabled();
    final bool hasMasterKey = await _masterKeyStorage.hasMasterKey();
    final String? keyFingerprint = await _masterKeyStorage.getMasterKeyFingerprint();

    // Redact fingerprint prefix and never expose raw key material or full cryptographic hashes
    final String? safeKeyFingerprint = (keyFingerprint != null && keyFingerprint.length >= 12)
        ? '${keyFingerprint.substring(0, 12)}...[REDACTED_FOR_AUDIT]'
        : null;

    final bool bioDeviceSupported = await _biometricService.isDeviceSupported();
    final bool bioCanCheck = await _biometricService.canCheckBiometrics();
    final List<dynamic> biometrics = await _biometricService.getAvailableBiometrics();

    final Map<String, dynamic> securityFlagsState = <String, dynamic>{
      'flag_secure_enabled': flagSecureEnabled,
      'master_key_present': hasMasterKey,
      'master_key_fingerprint_redacted': safeKeyFingerprint,
      'biometric_hardware_available': bioDeviceSupported || bioCanCheck,
      'enrolled_biometrics': biometrics.map((dynamic b) => b.toString()).toList(),
    };

    // Evaluate sync status for the audit report
    final SyncStatus syncStatus = await _bioDataRepository.refreshSyncStatus(userId: userId);
    final dynamic latestSample = await _bioDataRepository.getLatestBiometricSample(userId: userId);

    final Map<String, dynamic> biometricSyncState = <String, dynamic>{
      'status_code': syncStatus.name,
      'display_name': syncStatus.displayName,
      'is_connected': syncStatus.isConnected,
      'is_degraded': syncStatus.isDegraded,
      'is_manual': syncStatus.isManual,
      'staleness_threshold_hours': 20,
      'last_reading_time': latestSample?.recordedAt.toIso8601String(),
      'last_reading_source': latestSample?.source.name,
      'total_sleep_hours': latestSample?.totalSleepHours,
      'step_count': latestSample?.stepCount,
    };

    final Map<String, int> tableCounts = await _database.getTableRowCounts();
    final List<Map<String, dynamic>> decayLogs = await _database.getDecayLogs(limit: 10);

    return AuditDiagnosticPayload(
      timestampIso: timestampIso,
      schemaHashSha256: schemaHash,
      isDatabaseEncrypted: isEncrypted,
      databasePath: dbPath,
      databaseSizeBytes: dbSize,
      securityFlagsState: securityFlagsState,
      biometricSyncState: biometricSyncState,
      tableRowCounts: tableCounts,
      recentDecayLogs: decayLogs,
    );
  }

  Future<String> generateJsonDiagnosticPayload({bool pretty = true, String userId = 'usr_default_01'}) async {
    final AuditDiagnosticPayload payload = await generateDiagnosticPayload(userId: userId);
    return payload.toJson(pretty: pretty);
  }

  Future<String> generateMarkdownDiagnosticPayload({String userId = 'usr_default_01'}) async {
    final AuditDiagnosticPayload payload = await generateDiagnosticPayload(userId: userId);
    return payload.toMarkdown();
  }

  static String computeSchemaHash() {
    final List<String> schemaStatements = <String>[
      DatabaseConstants.createTableUsers.trim(),
      DatabaseConstants.createTableDailyCheckins.trim(),
      DatabaseConstants.createTableEvents.trim(),
      DatabaseConstants.createTableBrainHealthCounter.trim(),
      DatabaseConstants.createTableDecayLog.trim(),
      DatabaseConstants.createTableSpiritualContent.trim(),
      DatabaseConstants.createTableSpiritualLog.trim(),
      DatabaseConstants.createTableSosSessions.trim(),
      DatabaseConstants.createDecayTrigger.trim(),
    ]..addAll(DatabaseConstants.createIndices.map((String s) => s.trim()));

    schemaStatements.sort();
    final String concatenated = schemaStatements.join('\n---\n');
    final Digest digest = sha256.convert(utf8.encode(concatenated));
    return digest.toString();
  }
}
