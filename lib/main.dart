import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audit/audit_report_service.dart';
import 'core/security/biometric_auth_service.dart';
import 'core/security/security_service.dart';
import 'core/security/stealth_mode_service.dart';
import 'data/adapters/unified_bio_data_repository.dart';
import 'data/database/encrypted_database.dart';
import 'domain/calculators/vulnerability_index_calculator.dart';
import 'domain/escalation/escalation_tier_evaluator.dart';
import 'domain/models/biometric_sample.dart';
import 'domain/models/escalation_tier_result.dart';
import 'domain/models/sync_status.dart';
import 'domain/models/vulnerability_index.dart';
import 'domain/models/vulnerability_inputs.dart';
import 'domain/repositories/bio_data_repository.dart';
import 'presentation/screens/environmental_sos_filter_screen.dart';
import 'presentation/screens/manual_data_entry_screen.dart';
import 'presentation/screens/settings_and_stealth_screen.dart';
import 'presentation/screens/spiritual_module_screen.dart';
import 'presentation/screens/stroop_test_screen.dart';
import 'presentation/screens/tier2_escalation_screen.dart';
import 'presentation/screens/tier3_lockdown_screen.dart';
import 'presentation/screens/urge_wave_surfing_screen.dart';
import 'presentation/widgets/morning_assessment_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize native FLAG_SECURE immediately on startup
  final SecurityService securityService = SecurityService();
  await securityService.enableSecureScreen();

  // 2. Check for widget zero-friction launch target
  final StealthModeService stealthService = StealthModeService();
  final String? initialTarget = await stealthService.checkInitialLaunchTarget();

  runApp(SecureVaultApp(initialTarget: initialTarget));
}

class SecureVaultApp extends StatelessWidget {
  final String? initialTarget;

  const SecureVaultApp({super.key, this.initialTarget});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Offline Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F17),
      ),
      home: initialTarget == 'urge_wave_surfing'
          ? const UrgeWaveSurfingScreen(isDirectShortcutLaunch: true)
          : const BiometricGateScreen(),
    );
  }
}

class BiometricGateScreen extends StatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen> {
  final BiometricAuthService _biometricAuth = BiometricAuthService();
  bool _isAuthenticating = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _triggerAuthentication();
  }

  Future<void> _triggerAuthentication() async {
    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });

    final BiometricAuthResult result = await _biometricAuth.authenticateOnLaunch();

    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
    });

    if (result.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const DashboardScreen(),
        ),
      );
    } else {
      setState(() {
        _authError = result.errorMessage ?? 'Authentication required to unlock encrypted vault.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Center(
                child: Icon(
                  Icons.shield_outlined,
                  size: 72,
                  color: Color(0xFF14B8A6),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Hardware-Secured Vault',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'SQLCipher 256-bit AES + Android Keystore\nProtected by native FLAG_SECURE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              if (_isAuthenticating)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
                )
              else ...<Widget>[
                if (_authError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF451A1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDC2626)),
                    ),
                    child: Text(
                      _authError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _triggerAuthentication,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Authenticate with Biometrics'),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    // Emergency direct SOS shortcut bypasses biometric lock
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const UrgeWaveSurfingScreen(
                          isDirectShortcutLaunch: true,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFB91C1C)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.emergency, color: Color(0xFFEF4444)),
                  label: const Text('Zero-Friction Emergency SOS'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  static const String currentUserId = 'usr_default_01';

  final EncryptedDatabase _database = EncryptedDatabase();
  final BioDataRepository _bioDataRepository = UnifiedBioDataRepository();
  final VulnerabilityIndexCalculator _vulnCalculator = const VulnerabilityIndexCalculator();
  final EscalationTierEvaluator _escalationEvaluator = const EscalationTierEvaluator();
  late final AuditReportService _auditService;

  AuditDiagnosticPayload? _payload;
  VulnerabilityIndex? _vulnerabilityIndex;
  BiometricSample? _latestBiometrics;
  SyncStatus _syncStatus = SyncStatus.manual;
  bool _isLoading = true;
  String _selectedFormat = 'JSON';

  bool _isTier3Restricted = false;
  Tier3Result? _tier3Evaluation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auditService = AuditReportService(
      database: _database,
      bioDataRepository: _bioDataRepository,
    );
    _refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Re-lock vault upon leaving app or switching stealth launcher
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const BiometricGateScreen(),
          ),
        );
      }
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    try {
      final SyncStatus status = await _bioDataRepository.refreshSyncStatus(userId: currentUserId);
      final BiometricSample? biometrics = await _bioDataRepository.getLatestBiometricSample(userId: currentUserId);
      final VulnerabilityInputs inputs = await _bioDataRepository.getVulnerabilityInputs(userId: currentUserId);
      final VulnerabilityIndex index = _vulnCalculator.calculate(inputs);
      final AuditDiagnosticPayload payload = await _auditService.generateDiagnosticPayload(userId: currentUserId);

      // Check Tier 3 clinical condition from persistent SQLCipher database
      final Tier3Result tier3Result = await _escalationEvaluator.evaluateTier3FromDatabase(_database, currentUserId);

      if (!mounted) return;
      setState(() {
        _syncStatus = status;
        _latestBiometrics = biometrics;
        _vulnerabilityIndex = index;
        _payload = payload;
        _tier3Evaluation = tier3Result;
        _isTier3Restricted = tier3Result.isTriggered;
        _isLoading = false;
      });

      if (tier3Result.isTriggered) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => Tier3LockdownScreen(
                triggerReason: tier3Result.diagnosticReason,
                onAcknowledged: () {
                  setState(() => _isTier3Restricted = true);
                },
              ),
            ),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _simulateBrainHealthDecay() async {
    await _database.recordDecay(
      userId: currentUserId,
      decayAmount: 4.5,
      cause: 'CIRCADIAN_SLEEP_DEPRIVATION',
      metadata: <String, dynamic>{
        'sleep_hours': _latestBiometrics?.totalSleepHours ?? 4.2,
        'stress_marker': 'ELEVATED',
      },
    );
    await _refreshAll();
  }

  void _openManualEntryScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ManualDataEntryScreen(
          userId: currentUserId,
          repository: _bioDataRepository,
          onSaved: _refreshAll,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neuro-Ascetic Vault'),
        backgroundColor: const Color(0xFF111827),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Stealth & Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => SettingsAndStealthScreen(
                    userId: currentUserId,
                    onDatabaseRestored: _refreshAll,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Telemetry',
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : _payload == null
              ? const Center(child: Text('Failed to load diagnostic payload'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (_isTier3Restricted) _buildTier3Banner(),
                      _buildCrisisHubCard(),
                      const SizedBox(height: 16),
                      _buildSyncStatusCard(),
                      const SizedBox(height: 16),
                      MorningAssessmentWidget(
                        userId: currentUserId,
                        repository: _bioDataRepository,
                        onSubmitted: _refreshAll,
                      ),
                      const SizedBox(height: 16),
                      _buildVulnerabilityCard(),
                      const SizedBox(height: 16),
                      _buildSecurityStatusCard(),
                      const SizedBox(height: 16),
                      _buildActionsCard(),
                      const SizedBox(height: 16),
                      _buildDiagnosticViewer(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTier3Banner() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF450A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.lock, color: Color(0xFFEF4444), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'RESTRICTED MODE: TIER 3 ACTIVE',
                  style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _tier3Evaluation?.diagnosticReason ?? 'Compulsive relapse threshold reached. Access clinical hotlines.',
                  style: const TextStyle(color: Color(0xFFFEE2E2), fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => Tier3LockdownScreen(
                    triggerReason: _tier3Evaluation?.diagnosticReason,
                  ),
                ),
              );
            },
            child: const Text('Helplines', style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCrisisHubCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0E7490)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Urge Defense & Crisis Suite',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Phase 4 Live', style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Immediate evidence-based neurocognitive, physiological, and ascetic interventions:',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Action 1: Urge Wave Surfing
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const UrgeWaveSurfingScreen(userId: currentUserId),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0E7490),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            icon: const Icon(Icons.waves, size: 20),
            label: const Text('15-Min Urge Wave Surfing Timer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),

          // Secondary row: Stroop & Spiritual
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const StroopTestScreen(userId: currentUserId),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.psychology, size: 16),
                  label: const Text('Stroop 90s Task', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const SpiritualModuleScreen(userId: currentUserId),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2DD4BF),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.menu_book, size: 16),
                  label: const Text('Agpeya Sanctuary', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tertiary row: Contacts & SOS Filter
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const Tier2EscalationScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF87171),
                    side: const BorderSide(color: Color(0xFF991B1B)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.phone_in_talk, size: 16),
                  label: const Text('Tier 2 Fast-Dial', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const EnvironmentalSosFilterScreen(userId: currentUserId),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFCBD5E1),
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('SOS Context Filter', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    Color statusColor = const Color(0xFF10B981);
    Color statusBg = const Color(0xFF064E3B);
    String statusTitle = 'Connected to HMS Health Kit';
    String statusDesc = 'Real-time telemetry stream active (< 20 hours old).';

    if (_syncStatus.isDegraded) {
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFF78350F);
      statusTitle = 'Degraded Biometric Stream';
      statusDesc = 'Telemetry is > 20 hours stale. VulnerabilityIndex utilizes self-report baseline.';
    } else if (_syncStatus.isManual) {
      statusColor = const Color(0xFF38BDF8);
      statusBg = const Color(0xFF0C4A6E);
      statusTitle = 'Manual Entry Fallback';
      statusDesc = 'HMS Health Kit unavailable or unauthorized. Manual input active.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Biometric Sync Pipeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  _syncStatus.name.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusTitle,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0)),
          ),
          const SizedBox(height: 4),
          Text(
            statusDesc,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
          ),
          const Divider(color: Color(0xFF334155), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Total Sleep', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    _latestBiometrics != null ? '${_latestBiometrics!.totalSleepHours} hrs' : 'No Data',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Deep / REM', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    _latestBiometrics != null
                        ? '${_latestBiometrics!.deepSleepHours ?? "-"} / ${_latestBiometrics!.remSleepHours ?? "-"} hrs'
                        : 'No Data',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Daily Steps', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    _latestBiometrics != null ? '${_latestBiometrics!.stepCount}' : 'No Data',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _openManualEntryScreen,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF38BDF8),
              side: const BorderSide(color: Color(0xFF0284C7)),
              minimumSize: const Size.fromHeight(40),
            ),
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('Open Manual Biometric Entry Form'),
          ),
        ],
      ),
    );
  }

  Widget _buildVulnerabilityCard() {
    if (_vulnerabilityIndex == null) return const SizedBox.shrink();

    final Color scoreColor = _vulnerabilityIndex!.score > 70.0
        ? const Color(0xFFEF4444)
        : _vulnerabilityIndex!.score > 40.0
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Composite Vulnerability Index',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '${_vulnerabilityIndex!.score.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: scoreColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _vulnerabilityIndex!.isDegradedMode
                ? 'Mode: Graceful Degradation (Dynamically re-normalized weights)'
                : 'Mode: Complete Biometric Telemetry',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (_vulnerabilityIndex!.score / 100.0).clamp(0.0, 1.0),
            color: scoreColor,
            backgroundColor: const Color(0xFF0F172A),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Hardware & Storage Security',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          _statusRow('SQLCipher Database', _payload!.isDatabaseEncrypted ? 'ENCRYPTED' : 'UNENCRYPTED',
              _payload!.isDatabaseEncrypted),
          _statusRow(
              'Native FLAG_SECURE',
              _payload!.securityFlagsState['flag_secure_enabled'] == true ? 'ACTIVE' : 'INACTIVE',
              _payload!.securityFlagsState['flag_secure_enabled'] == true),
          _statusRow(
              'Android Keystore 256-bit Key',
              _payload!.securityFlagsState['master_key_present'] == true ? 'PRESENT' : 'MISSING',
              _payload!.securityFlagsState['master_key_present'] == true),
          const Divider(color: Color(0xFF334155), height: 24),
          Text(
            'Schema Hash: ${_payload!.schemaHashSha256.substring(0, 16)}...',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isOk ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: isOk ? const Color(0xFF34D399) : const Color(0xFFF87171),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Audit Operations & Decay Trigger Test',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _simulateBrainHealthDecay,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.flash_on, size: 18),
            label: const Text('Record Brain Health Decay (Writes to decay_log)'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticViewer() {
    final String content = _selectedFormat == 'JSON' ? _payload!.toJson() : _payload!.toMarkdown();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Diagnostic Payload', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Row(
                children: <Widget>[
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(value: 'JSON', label: Text('JSON')),
                      ButtonSegment<String>(value: 'MD', label: Text('MD')),
                    ],
                    selected: <String>{_selectedFormat},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() => _selectedFormat = newSelection.first);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payload copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF38BDF8)),
            ),
          ),
        ],
      ),
    );
  }
}
