import '../models/biometric_sample.dart';
import '../models/morning_check_in.dart';
import '../models/sync_status.dart';
import '../models/vulnerability_inputs.dart';

/// Single unified repository interface for all biometric and self-reported signals.
///
/// Clean Architecture Contract:
/// Domain layer components (calculators, engines, evaluators) interact ONLY with
/// this contract. The domain layer never knows whether biometric data was captured
/// via native Huawei Health Kit SDK or manual entry fallback.
abstract class BioDataRepository {
  /// Stream broadcasting the current biometric synchronization status.
  Stream<SyncStatus> get syncStatusStream;

  /// Current synchronous snapshot of the synchronization state.
  SyncStatus get currentSyncStatus;

  /// Current cached biometric sample in-memory if available.
  BiometricSample? get cachedBiometricSample;

  /// Retrieves the current consolidated [VulnerabilityInputs] for the user,
  /// integrating latest sleep, step counts, and morning self-report psychometrics.
  Future<VulnerabilityInputs> getVulnerabilityInputs({required String userId});

  /// Retrieves the latest biometric sample (from Huawei Health Kit or fallback manual entry).
  Future<BiometricSample?> getLatestBiometricSample({required String userId});

  /// Retrieves the latest recorded Morning Check-In.
  Future<MorningCheckIn?> getLatestMorningCheckIn({required String userId});

  /// Records a morning single-tap self-assessment (3-tier scale).
  /// Feeds directly into VulnerabilityIndex's SelfReportScore regardless of sync mode.
  Future<MorningCheckIn> recordMorningCheckIn({
    required String userId,
    required MorningAssessmentTier tier,
    String? notes,
  });

  /// Submits manual fallback biometric measurements.
  /// Automatically called whenever Huawei Health Kit is unauthorized, unavailable, or stale.
  Future<BiometricSample> recordManualBiometrics({
    required String userId,
    required double totalSleepHours,
    required int stepCount,
    double? deepSleepHours,
    double? remSleepHours,
  });

  /// Requests authorization for Huawei Health Kit biometric permissions.
  /// If denied or unavailable, cleanly falls back to manual entry mode without throwing or blocking.
  Future<bool> requestBiometricAuthorization();

  /// Manually requests an immediate synchronization pass with Huawei Health Kit.
  /// Transitions state between [SyncStatus.connected], [SyncStatus.degraded], and [SyncStatus.manual].
  Future<SyncStatus> refreshSyncStatus({required String userId});
}
