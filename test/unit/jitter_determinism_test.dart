import 'package:flutter_test/flutter_test.dart';
import '../../lib/domain/engine/jitter_generator.dart';

void main() {
  group('Jitter Determinism & Bound Unit Tests', () {
    test('Same hash input produces identical jitter output across repeated invocations', () {
      const String hashA = '8f4c2e6b91a03d7c5e8b2a1f0d9c4b7a3e6f8d2c1b5a9e0f3d7c2b8a4f1e6d0c';
      const String hashB = 'user_vault_salt_2026-09-16_daily_metrics_hash';

      final double jitterA1 = JitterGenerator.computeJitter(hashA);
      final double jitterA2 = JitterGenerator.computeJitter(hashA);
      final double jitterA3 = JitterGenerator.computeJitter(hashA);

      expect(jitterA1, equals(jitterA2));
      expect(jitterA2, equals(jitterA3));

      final double jitterB1 = JitterGenerator.computeJitter(hashB);
      final double jitterB2 = JitterGenerator.computeJitter(hashB);

      expect(jitterB1, equals(jitterB2));
      // Distinct daily hashes should yield distinct pseudo-random jitter
      expect(jitterA1, isNot(equals(jitterB1)));
    });

    test('All generated jitter outputs adhere strictly to the [-0.10, +0.10] bound (±10%)', () {
      final List<String> testHashes = <String>[
        'test_seed_001',
        'test_seed_002',
        'extreme_low_0000000000000000',
        'extreme_high_ffffffffffffffff',
        'session_hash_alpha_2026',
        'session_hash_omega_2026',
        'clinical_daily_hash_patient_42',
      ];

      for (final String hash in testHashes) {
        final double jitter = JitterGenerator.computeJitter(hash);
        expect(jitter, greaterThanOrEqualTo(-0.10), reason: 'Jitter for $hash was below -0.10');
        expect(jitter, lessThanOrEqualTo(0.10), reason: 'Jitter for $hash exceeded +0.10');
      }
    });

    test('Empty hash defaults safely to 0.0 with zero bias', () {
      final double jitter = JitterGenerator.computeJitter('');
      expect(jitter, equals(0.0));
    });
  });
}
