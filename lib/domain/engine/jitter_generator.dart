import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Pure domain utility producing deterministic, bounded pseudo-random jitter.
///
/// Mathematical contract:
/// - Output range: strictly bounded within [-0.10, +0.10] (representing ±10% jitter).
/// - Determinism: identical [dailyDataHash] input produces identical jitter output down to floating-point precision.
/// - Cryptographic unpredictability: uses SHA-256 digest to prevent user gaming while ensuring full audit reproducibility.
class JitterGenerator {
  /// Maximum jitter magnitude (±10%).
  static const double maxJitterMagnitude = 0.10;

  /// Computes a deterministic jitter in [-0.10, +0.10] from [dailyDataHash].
  static double computeJitter(String dailyDataHash) {
    if (dailyDataHash.isEmpty) {
      return 0.0;
    }

    final List<int> bytes = utf8.encode(dailyDataHash);
    final Digest digest = sha256.convert(bytes);
    final List<int> hashBytes = digest.bytes;

    // Interpret the first 8 bytes as a 64-bit unsigned BigInt to ensure uniform distribution
    BigInt value = BigInt.zero;
    for (int i = 0; i < 8; i++) {
      value = (value << 8) | BigInt.from(hashBytes[i]);
    }

    // Maximum 64-bit unsigned integer: 0xFFFFFFFFFFFFFFFF
    final BigInt maxUint64 = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);
    final double normalizedRatio = value.toDouble() / maxUint64.toDouble();

    // Map [0.0, 1.0] -> [-maxJitterMagnitude, +maxJitterMagnitude]
    final double jitter = -maxJitterMagnitude + (normalizedRatio * (2 * maxJitterMagnitude));

    // Clamp to guarantee exact boundary adherence
    return jitter.clamp(-maxJitterMagnitude, maxJitterMagnitude);
  }
}
