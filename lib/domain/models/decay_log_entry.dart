import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Immutable domain entity representing an audit log entry for brain health counter changes.
///
/// Under domain rules:
/// Every brain_health_counter change must write one row to decay_log (cause, amount, resulting_value, timestamp)
/// — never mutate the counter as a bare scalar without a log entry.
class DecayLogEntry {
  final String id;
  final String counterId;
  final String userId;
  final String? eventId;
  final double previousScore;
  final double resultingValue;
  final double amount; // Loss/delta (negative for decay)
  final String cause;
  final DateTime timestamp;
  final String cryptographicHash;
  final Map<String, dynamic>? metadata;

  DecayLogEntry({
    required this.id,
    required this.counterId,
    required this.userId,
    this.eventId,
    required this.previousScore,
    required this.resultingValue,
    required this.amount,
    required this.cause,
    required this.timestamp,
    String? cryptographicHash,
    this.metadata,
  }) : cryptographicHash = cryptographicHash ??
            _computeHash(id, counterId, userId, previousScore, resultingValue, amount, cause, timestamp);

  static String _computeHash(
    String id,
    String counterId,
    String userId,
    double previousScore,
    double resultingValue,
    double amount,
    String cause,
    DateTime timestamp,
  ) {
    final String payload = '$id:$counterId:$userId:$previousScore:$resultingValue:$amount:$cause:${timestamp.millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  @override
  String toString() =>
      'DecayLogEntry(id: $id, cause: "$cause", delta: $amount, resulting: $resultingValue, time: $timestamp)';
}
