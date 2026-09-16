import 'dart:async';
import 'dart:developer' as developer;
import '../../domain/models/biometric_sample.dart';
import '../../domain/models/morning_check_in.dart';
import '../../domain/models/sync_status.dart';
import '../../domain/models/vulnerability_inputs.dart';
import '../../domain/repositories/bio_data_repository.dart';
import 'huawei_health_kit_client.dart';
import 'manual_data_entry_service.dart';

/// Concrete implementation of [BioDataRepository] orchestrating native Huawei Health Kit
/// data retrieval with seamless automated fallback to manual data entry.
///
/// Clean Architecture: Data Layer.
/// Encapsulates all HMS SDK queries, staleness checks (>20h threshold), and SQLCipher persistence.
class UnifiedBioDataRepository implements BioDataRepository {
  final HuaweiHealthKitClient healthKitClient;
  final ManualDataEntryService manualDataService;

  final StreamController<SyncStatus> _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = SyncStatus.manual;

  /// Cache of the most recent resolved biometric sample in-memory.
  BiometricSample? _cachedBiometricSample;

  UnifiedBioDataRepository({
    HuaweiHealthKitClient? healthKitClient,
    ManualDataEntryService? manualDataService,
  })  : healthKitClient = healthKitClient ?? HuaweiHealthKitClient(),
        manualDataService = manualDataService ?? ManualDataEntryService();

  @override
  Stream<SyncStatus> get syncStatusStream => _statusController.stream;

  @override
  SyncStatus get currentSyncStatus => _currentStatus;

  @override
  BiometricSample? get cachedBiometricSample => _cachedBiometricSample;

  void _updateStatus(SyncStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
      developer.log('Biometric sync status changed to: ${newStatus.name}', name: 'UnifiedBioDataRepository');
    }
  }

  @override
  Future<bool> requestBiometricAuthorization() async {
    try {
      final bool isHmsAvailable = await healthKitClient.isAvailable();
      if (!isHmsAvailable) {
        developer.log('HMS Health Kit is not available on this device; staying in manual mode.',
            name: 'UnifiedBioDataRepository');
        _updateStatus(SyncStatus.manual);
        return false;
      }

      final bool granted = await healthKitClient.requestAuthorization();
      if (granted) {
        developer.log('HMS Health Kit authorization granted.', name: 'UnifiedBioDataRepository');
        _updateStatus(SyncStatus.connected);
        return true;
      } else {
        developer.log('HMS Health Kit authorization denied; falling back to manual entry mode.',
            name: 'UnifiedBioDataRepository');
        _updateStatus(SyncStatus.manual);
        return false;
      }
    } catch (e, stack) {
      developer.log('Exception during biometric authorization request; falling back cleanly: $e',
          name: 'UnifiedBioDataRepository', error: e, stackTrace: stack);
      _updateStatus(SyncStatus.manual);
      return false;
    }
  }

  @override
  Future<SyncStatus> refreshSyncStatus({required String userId}) async {
    try {
      // 1. Verify HMS Health Kit native availability
      final bool isHmsAvailable = await healthKitClient.isAvailable();
      if (!isHmsAvailable) {
        _updateStatus(SyncStatus.manual);
        return SyncStatus.manual;
      }

      // 2. Check authorization
      final bool hasAuth = await healthKitClient.hasAuthorization();
      if (!hasAuth) {
        _updateStatus(SyncStatus.manual);
        return SyncStatus.manual;
      }

      // 3. Attempt to fetch latest telemetry
      final BiometricSample? sample = await healthKitClient.fetchLatestBiometrics();
      if (sample == null) {
        // Check if we have recent cached or manual data
        final BiometricSample? fallback = await manualDataService.getLatestManualBiometricSample(userId: userId);
        if (fallback != null && !fallback.isStale()) {
          _updateStatus(SyncStatus.manual);
        } else {
          _updateStatus(SyncStatus.degraded);
        }
        return _currentStatus;
      }

      _cachedBiometricSample = sample;

      // 4. Evaluate staleness (> 20 hours)
      if (sample.isStale()) {
        _updateStatus(SyncStatus.degraded);
        return SyncStatus.degraded;
      }

      _updateStatus(SyncStatus.connected);
      return SyncStatus.connected;
    } catch (e, stack) {
      developer.log('Error refreshing sync status; falling back cleanly to manual mode: $e',
          name: 'UnifiedBioDataRepository', error: e, stackTrace: stack);
      _updateStatus(SyncStatus.manual);
      return SyncStatus.manual;
    }
  }

  @override
  Future<BiometricSample?> getLatestBiometricSample({required String userId}) async {
    try {
      // 1. Check primary HMS Health Kit path
      final bool isAvailable = await healthKitClient.isAvailable();
      final bool hasAuth = isAvailable && await healthKitClient.hasAuthorization();

      if (isAvailable && hasAuth) {
        final BiometricSample? hmsSample = await healthKitClient.fetchLatestBiometrics();
        if (hmsSample != null) {
          if (hmsSample.isStale()) {
            developer.log('HMS Health Kit data is stale (> 20 hours). Checking manual entry fallback.',
                name: 'UnifiedBioDataRepository');
            _updateStatus(SyncStatus.degraded);

            // Check if user entered fresher manual data
            final BiometricSample? manualSample =
                await manualDataService.getLatestManualBiometricSample(userId: userId);
            if (manualSample != null && manualSample.recordedAt.isAfter(hmsSample.recordedAt)) {
              _cachedBiometricSample = manualSample;
              return manualSample;
            }
          } else {
            _updateStatus(SyncStatus.connected);
            _cachedBiometricSample = hmsSample;
            return hmsSample;
          }
        }
      }

      // 2. Fallback to manual entry
      _updateStatus(SyncStatus.manual);
      final BiometricSample? manual = await manualDataService.getLatestManualBiometricSample(userId: userId);
      _cachedBiometricSample = manual;
      return manual;
    } catch (e, stack) {
      developer.log('Error querying biometric sample; falling back cleanly to manual storage: $e',
          name: 'UnifiedBioDataRepository', error: e, stackTrace: stack);
      _updateStatus(SyncStatus.manual);
      return await manualDataService.getLatestManualBiometricSample(userId: userId);
    }
  }

  @override
  Future<MorningCheckIn?> getLatestMorningCheckIn({required String userId}) async {
    try {
      return await manualDataService.getLatestMorningCheckIn(userId: userId);
    } catch (e, stack) {
      developer.log('Error retrieving morning check-in: $e',
          name: 'UnifiedBioDataRepository', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<MorningCheckIn> recordMorningCheckIn({
    required String userId,
    required MorningAssessmentTier tier,
    String? notes,
  }) async {
    final String checkinId = 'chk_${DateTime.now().millisecondsSinceEpoch}';
    final MorningCheckIn checkIn = MorningCheckIn.fromTierTap(
      id: checkinId,
      userId: userId,
      tier: tier,
      notes: notes,
    );
    return await manualDataService.saveMorningCheckIn(checkIn);
  }

  @override
  Future<BiometricSample> recordManualBiometrics({
    required String userId,
    required double totalSleepHours,
    required int stepCount,
    double? deepSleepHours,
    double? remSleepHours,
  }) async {
    final BiometricSample sample = await manualDataService.recordManualBiometrics(
      userId: userId,
      totalSleepHours: totalSleepHours,
      stepCount: stepCount,
      deepSleepHours: deepSleepHours,
      remSleepHours: remSleepHours,
    );
    _cachedBiometricSample = sample;
    _updateStatus(SyncStatus.manual);
    return sample;
  }

  @override
  Future<VulnerabilityInputs> getVulnerabilityInputs({required String userId}) async {
    try {
      // 1. Resolve biometric sensor signals (HMS or Fallback Manual)
      final BiometricSample? bioSample = await getLatestBiometricSample(userId: userId);

      // 2. Resolve Ground-Truth Morning Self-Assessment
      final MorningCheckIn? checkIn = await getLatestMorningCheckIn(userId: userId);

      // Documented neutral psychometric baseline (50.0) if no check-in recorded yet today.
      // Under no circumstance does this default to a silent zero (0.0).
      final bool isCheckInSkipped = checkIn == null;
      final double selfReportScore = checkIn?.selfReportScore ?? MorningCheckIn.defaultNeutralScore;

      if (bioSample == null) {
        // Biometrics unavailable -> Graceful degradation to self-report baseline only
        return VulnerabilityInputs(
          sleepDeprivationScore: null,
          remDeficitScore: null,
          sedentaryScore: null,
          selfReportScore: selfReportScore,
          isSelfReportDefaultFallback: isCheckInSkipped,
        );
      }

      // Check if biometric data is stale (> 20 hours).
      // Stale biometrics are treated as unavailable to prevent acting on outdated physiology.
      if (bioSample.isStale()) {
        developer.log(
          'Biometric sample from ${bioSample.recordedAt} is stale (>20h). Falling back to SelfReportScore ground truth.',
          name: 'UnifiedBioDataRepository',
        );
        _updateStatus(SyncStatus.degraded);
        return VulnerabilityInputs(
          sleepDeprivationScore: null,
          remDeficitScore: null,
          sedentaryScore: null,
          selfReportScore: selfReportScore,
          isSelfReportDefaultFallback: isCheckInSkipped,
        );
      }

      // Fresh biometrics active
      return VulnerabilityInputs(
        sleepDeprivationScore: bioSample.computeSleepDeprivationScore(),
        remDeficitScore: bioSample.computeRemDeficitScore(),
        sedentaryScore: bioSample.computeSedentaryScore(),
        selfReportScore: selfReportScore,
        isSelfReportDefaultFallback: isCheckInSkipped,
      );
    } catch (e, stack) {
      developer.log('Error calculating vulnerability inputs; defaulting safely: $e',
          name: 'UnifiedBioDataRepository', error: e, stackTrace: stack);
      return const VulnerabilityInputs(
        sleepDeprivationScore: null,
        remDeficitScore: null,
        sedentaryScore: null,
        selfReportScore: MorningCheckIn.defaultNeutralScore,
        isSelfReportDefaultFallback: true,
      );
    }
  }

  void dispose() {
    _statusController.close();
  }
}
