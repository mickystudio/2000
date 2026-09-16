import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/data/adapters/huawei_health_kit_client.dart';
import '../../lib/data/adapters/manual_data_entry_service.dart';
import '../../lib/data/adapters/unified_bio_data_repository.dart';
import '../../lib/domain/calculators/vulnerability_index_calculator.dart';
import '../../lib/domain/models/biometric_sample.dart';
import '../../lib/domain/models/morning_check_in.dart';
import '../../lib/domain/models/sync_status.dart';
import '../../lib/domain/models/vulnerability_index.dart';
import '../../lib/domain/models/vulnerability_inputs.dart';

/// In-memory mock of [ManualDataEntryService] for unit testing without SQLCipher native drivers.
class MockManualDataEntryService extends ManualDataEntryService {
  BiometricSample? mockManualSample;
  MorningCheckIn? mockMorningCheckIn;

  @override
  Future<BiometricSample> recordManualBiometrics({
    required String userId,
    required double totalSleepHours,
    required int stepCount,
    double? deepSleepHours,
    double? remSleepHours,
    DateTime? timestamp,
  }) async {
    final BiometricSample sample = BiometricSample(
      totalSleepHours: totalSleepHours,
      deepSleepHours: deepSleepHours,
      remSleepHours: remSleepHours,
      stepCount: stepCount,
      recordedAt: timestamp ?? DateTime.now(),
      source: BiometricDataSource.manualEntry,
    );
    mockManualSample = sample;
    return sample;
  }

  @override
  Future<BiometricSample?> getLatestManualBiometricSample({required String userId}) async {
    return mockManualSample;
  }

  @override
  Future<MorningCheckIn> saveMorningCheckIn(MorningCheckIn checkIn) async {
    mockMorningCheckIn = checkIn;
    return checkIn;
  }

  @override
  Future<MorningCheckIn?> getLatestMorningCheckIn({required String userId}) async {
    return mockMorningCheckIn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricSample Model & Staleness Tests', () {
    test('Identifies stale data (> 20 hours) accurately', () {
      final DateTime now = DateTime(2026, 9, 16, 12, 0);

      // Sample 19 hours old -> NOT stale
      final BiometricSample freshSample = BiometricSample(
        totalSleepHours: 7.5,
        stepCount: 8000,
        recordedAt: now.subtract(const Duration(hours: 19)),
        source: BiometricDataSource.huaweiHealthKit,
      );
      expect(freshSample.isStale(now: now), isFalse);

      // Sample 21 hours old -> STALE (> 20 hours)
      final BiometricSample staleSample = BiometricSample(
        totalSleepHours: 7.5,
        stepCount: 8000,
        recordedAt: now.subtract(const Duration(hours: 21)),
        source: BiometricDataSource.huaweiHealthKit,
      );
      expect(staleSample.isStale(now: now), isTrue);
    });

    test('Computes physiological deprivation scores correctly', () {
      final BiometricSample optimal = BiometricSample(
        totalSleepHours: 8.0,
        deepSleepHours: 2.0,
        remSleepHours: 1.8,
        stepCount: 10000,
        recordedAt: DateTime.now(),
        source: BiometricDataSource.huaweiHealthKit,
      );
      expect(optimal.computeSleepDeprivationScore(), equals(0.0));
      expect(optimal.computeRemDeficitScore(), equals(0.0));
      expect(optimal.computeSedentaryScore(), equals(0.0));

      final BiometricSample severeDeficit = BiometricSample(
        totalSleepHours: 4.0,
        deepSleepHours: 0.5,
        remSleepHours: 0.2,
        stepCount: 1200,
        recordedAt: DateTime.now(),
        source: BiometricDataSource.huaweiHealthKit,
      );
      expect(severeDeficit.computeSleepDeprivationScore(), equals(100.0));
      expect(severeDeficit.computeRemDeficitScore(), equals(100.0));
      expect(severeDeficit.computeSedentaryScore(), equals(100.0));
    });
  });

  group('Morning Self-Assessment 3-Tier Model Tests', () {
    test('Low tier yields 85.0 vulnerability score', () {
      final MorningCheckIn checkIn = MorningCheckIn.fromTierTap(
        id: 'chk_test_01',
        userId: 'usr_01',
        tier: MorningAssessmentTier.low,
      );
      expect(checkIn.tier, equals(MorningAssessmentTier.low));
      expect(checkIn.selfReportScore, equals(85.0));
      expect(checkIn.resilienceRating, equals(1.5));
    });

    test('Balanced tier yields 50.0 vulnerability score', () {
      final MorningCheckIn checkIn = MorningCheckIn.fromTierTap(
        id: 'chk_test_02',
        userId: 'usr_01',
        tier: MorningAssessmentTier.neutral,
      );
      expect(checkIn.tier, equals(MorningAssessmentTier.neutral));
      expect(checkIn.selfReportScore, equals(50.0));
      expect(checkIn.resilienceRating, equals(5.0));
    });

    test('Resilient tier yields 15.0 vulnerability score', () {
      final MorningCheckIn checkIn = MorningCheckIn.fromTierTap(
        id: 'chk_test_03',
        userId: 'usr_01',
        tier: MorningAssessmentTier.resilient,
      );
      expect(checkIn.tier, equals(MorningAssessmentTier.resilient));
      expect(checkIn.selfReportScore, equals(15.0));
      expect(checkIn.resilienceRating, equals(8.5));
    });
  });

  group('UnifiedBioDataRepository & Fallback State Engine Tests', () {
    test('Degrades gracefully to SelfReportScore when HMS returns stale data', () async {
      // Mock MethodChannel returning stale data (22 hours old)
      const MethodChannel mockChannel = MethodChannel('com.example.hms/health');
      final DateTime now = DateTime.now();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        mockChannel,
        (MethodCall call) async {
          if (call.method == 'isHealthKitAvailable') return true;
          if (call.method == 'hasAuthorization') return true;
          if (call.method == 'getLatestBiometrics') {
            return <String, dynamic>{
              'total_sleep_hours': 5.0,
              'deep_sleep_hours': 1.0,
              'rem_sleep_hours': 0.8,
              'step_count': 3000,
              'recorded_at_ms': now.subtract(const Duration(hours: 22)).millisecondsSinceEpoch,
            };
          }
          return null;
        },
      );

      final HuaweiHealthKitClient client = HuaweiHealthKitClient(channel: mockChannel);
      final MockManualDataEntryService mockManualService = MockManualDataEntryService();
      final UnifiedBioDataRepository repo = UnifiedBioDataRepository(
        healthKitClient: client,
        manualDataService: mockManualService,
      );

      // Verify sync status evaluation
      final SyncStatus status = await repo.refreshSyncStatus(userId: 'test_user');
      expect(status, equals(SyncStatus.degraded));

      // Domain inputs calculation must drop stale biometrics and retain self-report ground truth
      final VulnerabilityInputs inputs = await repo.getVulnerabilityInputs(userId: 'test_user');
      expect(inputs.sleepDeprivationScore, isNull);
      expect(inputs.remDeficitScore, isNull);
      expect(inputs.sedentaryScore, isNull);
      expect(inputs.selfReportScore, equals(50.0)); // Default neutral

      // Feed into VulnerabilityIndexCalculator
      const VulnerabilityIndexCalculator calculator = VulnerabilityIndexCalculator();
      final VulnerabilityIndex index = calculator.calculate(inputs);

      expect(index.isDegradedMode, isTrue);
      expect(index.score, equals(50.0));
      expect(index.activeWeights['w4SelfReport'], equals(1.0));
    });

    test('Connects and uses full biometrics when HMS returns fresh data', () async {
      const MethodChannel mockChannel = MethodChannel('com.example.hms/health');
      final DateTime now = DateTime.now();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        mockChannel,
        (MethodCall call) async {
          if (call.method == 'isHealthKitAvailable') return true;
          if (call.method == 'hasAuthorization') return true;
          if (call.method == 'getLatestBiometrics') {
            return <String, dynamic>{
              'total_sleep_hours': 8.0,
              'deep_sleep_hours': 2.0,
              'rem_sleep_hours': 1.8,
              'step_count': 10000,
              'recorded_at_ms': now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
            };
          }
          return null;
        },
      );

      final HuaweiHealthKitClient client = HuaweiHealthKitClient(channel: mockChannel);
      final MockManualDataEntryService mockManualService = MockManualDataEntryService();
      final UnifiedBioDataRepository repo = UnifiedBioDataRepository(
        healthKitClient: client,
        manualDataService: mockManualService,
      );

      final SyncStatus status = await repo.refreshSyncStatus(userId: 'test_user');
      expect(status, equals(SyncStatus.connected));

      final VulnerabilityInputs inputs = await repo.getVulnerabilityInputs(userId: 'test_user');
      expect(inputs.sleepDeprivationScore, equals(0.0));
      expect(inputs.remDeficitScore, equals(0.0));
      expect(inputs.sedentaryScore, equals(0.0));
      expect(inputs.selfReportScore, equals(50.0));

      const VulnerabilityIndexCalculator calculator = VulnerabilityIndexCalculator();
      final VulnerabilityIndex index = calculator.calculate(inputs);

      expect(index.isDegradedMode, isFalse);
      // w1*0 + w2*0 + w3*0 + w4*50 = 0.40 * 50 = 20.0
      expect(index.score, equals(20.0));
    });

    test('Falls back to manual entry when HMS is unavailable', () async {
      const MethodChannel mockChannel = MethodChannel('com.example.hms/health');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        mockChannel,
        (MethodCall call) async {
          if (call.method == 'isHealthKitAvailable') return false; // HMS absent
          return null;
        },
      );

      final HuaweiHealthKitClient client = HuaweiHealthKitClient(channel: mockChannel);
      final MockManualDataEntryService mockManualService = MockManualDataEntryService();

      // Seed manual fallback data
      await mockManualService.recordManualBiometrics(
        userId: 'test_user',
        totalSleepHours: 6.0,
        stepCount: 5000,
        deepSleepHours: 1.2,
        remSleepHours: 1.0,
      );

      // Record morning check-in: Low Tier (85.0)
      await mockManualService.saveMorningCheckIn(
        MorningCheckIn.fromTierTap(
          id: 'chk_manual_01',
          userId: 'test_user',
          tier: MorningAssessmentTier.low,
        ),
      );

      final UnifiedBioDataRepository repo = UnifiedBioDataRepository(
        healthKitClient: client,
        manualDataService: mockManualService,
      );

      final SyncStatus status = await repo.refreshSyncStatus(userId: 'test_user');
      expect(status, equals(SyncStatus.manual));

      final VulnerabilityInputs inputs = await repo.getVulnerabilityInputs(userId: 'test_user');
      expect(inputs.selfReportScore, equals(85.0));
      expect(inputs.sleepDeprivationScore, isNotNull);
      expect(inputs.sedentaryScore, isNotNull);

      final BiometricSample? retrieved = await repo.getLatestBiometricSample(userId: 'test_user');
      expect(retrieved?.source, equals(BiometricDataSource.manualEntry));
      expect(retrieved?.totalSleepHours, equals(6.0));
    });

    test('Cleanly falls back without throwing or blocking when HMS permission is denied', () async {
      const MethodChannel mockChannel = MethodChannel('com.example.hms/health');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        mockChannel,
        (MethodCall call) async {
          if (call.method == 'isHealthKitAvailable') return true;
          if (call.method == 'hasAuthorization') return false; // Permission denied
          if (call.method == 'requestAuthorization') {
            throw PlatformException(code: 'PERMISSION_DENIED', message: 'User rejected health scopes');
          }
          return null;
        },
      );

      final HuaweiHealthKitClient client = HuaweiHealthKitClient(channel: mockChannel);
      final MockManualDataEntryService mockManualService = MockManualDataEntryService();
      final UnifiedBioDataRepository repo = UnifiedBioDataRepository(
        healthKitClient: client,
        manualDataService: mockManualService,
      );

      // Must not throw or block; returns false and stays in manual mode
      final bool granted = await repo.requestBiometricAuthorization();
      expect(granted, isFalse);

      final SyncStatus status = await repo.refreshSyncStatus(userId: 'test_user');
      expect(status, equals(SyncStatus.manual));

      // Check vulnerability inputs fallback cleanly
      final VulnerabilityInputs inputs = await repo.getVulnerabilityInputs(userId: 'test_user');
      expect(inputs.hasAnyBiometricData, isFalse);
      expect(inputs.selfReportScore, equals(50.0));
      expect(inputs.isSelfReportDefaultFallback, isTrue);
    });

    test('Skipped morning assessment and missing biometrics cleanly resolve to documented neutral baseline (never silent zero)', () async {
      const MethodChannel mockChannel = MethodChannel('com.example.hms/health');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        mockChannel,
        (MethodCall call) async {
          if (call.method == 'isHealthKitAvailable') return false;
          return null;
        },
      );

      final HuaweiHealthKitClient client = HuaweiHealthKitClient(channel: mockChannel);
      final MockManualDataEntryService emptyManualService = MockManualDataEntryService();
      final UnifiedBioDataRepository repo = UnifiedBioDataRepository(
        healthKitClient: client,
        manualDataService: emptyManualService,
      );

      // Neither biometrics nor morning check-in exists
      final VulnerabilityInputs inputs = await repo.getVulnerabilityInputs(userId: 'new_user');
      expect(inputs.sleepDeprivationScore, isNull);
      expect(inputs.remDeficitScore, isNull);
      expect(inputs.sedentaryScore, isNull);
      expect(inputs.hasAnyBiometricData, isFalse);

      // Must be documented 50.0 neutral fallback baseline, NEVER a silent zero
      expect(inputs.selfReportScore, equals(MorningCheckIn.defaultNeutralScore));
      expect(inputs.selfReportScore, equals(50.0));
      expect(inputs.isSelfReportDefaultFallback, isTrue);

      const VulnerabilityIndexCalculator calculator = VulnerabilityIndexCalculator();
      final VulnerabilityIndex index = calculator.calculate(inputs);

      expect(index.isDegradedMode, isTrue);
      expect(index.isDefaultBaseline, isTrue);
      expect(index.score, equals(50.0));
      expect(index.activeWeights['w4SelfReport'], equals(1.0));
    });

    test('Boundary staleness test: exactly 19h 59m is fresh, 20h 01m is stale', () {
      final DateTime anchor = DateTime(2026, 9, 16, 12, 0, 0);

      final BiometricSample justFresh = BiometricSample(
        totalSleepHours: 7.0,
        stepCount: 7000,
        recordedAt: anchor.subtract(const Duration(hours: 19, minutes: 59)),
        source: BiometricDataSource.huaweiHealthKit,
      );
      expect(justFresh.isStale(now: anchor), isFalse);

      final BiometricSample justStale = BiometricSample(
        totalSleepHours: 7.0,
        stepCount: 7000,
        recordedAt: anchor.subtract(const Duration(hours: 20, minutes: 1)),
        source: BiometricDataSource.huaweiHealthKit,
      );
      expect(justStale.isStale(now: anchor), isTrue);
    });
  });
}
