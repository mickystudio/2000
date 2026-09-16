import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthResult {
  final bool isAuthenticated;
  final String? errorMessage;
  final String? errorCode;
  final List<BiometricType> availableBiometrics;
  final bool isHardwareAvailable;

  const BiometricAuthResult({
    required this.isAuthenticated,
    this.errorMessage,
    this.errorCode,
    this.availableBiometrics = const <BiometricType>[],
    this.isHardwareAvailable = false,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'isAuthenticated': isAuthenticated,
      'errorMessage': errorMessage,
      'errorCode': errorCode,
      'availableBiometrics': availableBiometrics.map((BiometricType b) => b.name).toList(),
      'isHardwareAvailable': isHardwareAvailable,
    };
  }
}

class BiometricAuthService {
  final LocalAuthentication _auth;

  static final BiometricAuthService _instance = BiometricAuthService._internal(
    LocalAuthentication(),
  );

  factory BiometricAuthService({LocalAuthentication? auth}) {
    if (auth != null) {
      return BiometricAuthService._internal(auth);
    }
    return _instance;
  }

  BiometricAuthService._internal(this._auth);

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      developer.log('Biometric check error: ${e.message}', name: 'BiometricAuthService', error: e);
      return false;
    }
  }

  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException catch (e) {
      developer.log('Device support check error: ${e.message}', name: 'BiometricAuthService', error: e);
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      developer.log('Available biometrics query error: ${e.message}', name: 'BiometricAuthService', error: e);
      return <BiometricType>[];
    }
  }

  Future<BiometricAuthResult> authenticateOnLaunch({
    String localizedReason = 'Authenticate with Face or Fingerprint to unlock your secure offline vault',
  }) async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      final bool canCheck = await _auth.canCheckBiometrics;
      final List<BiometricType> biometrics = await _auth.getAvailableBiometrics();

      if (!isSupported && !canCheck) {
        developer.log('Biometrics hardware not available on device', name: 'BiometricAuthService');
        return BiometricAuthResult(
          isAuthenticated: false,
          errorCode: 'HARDWARE_UNAVAILABLE',
          errorMessage: 'Biometric hardware is not supported or accessible on this device.',
          availableBiometrics: biometrics,
          isHardwareAvailable: false,
        );
      }

      final bool authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );

      return BiometricAuthResult(
        isAuthenticated: authenticated,
        availableBiometrics: biometrics,
        isHardwareAvailable: true,
      );
    } on PlatformException catch (e) {
      developer.log('Launch biometric gate failed: ${e.code} - ${e.message}', name: 'BiometricAuthService', error: e);
      return BiometricAuthResult(
        isAuthenticated: false,
        errorCode: e.code,
        errorMessage: e.message ?? 'Unknown biometric authentication error occurred.',
        isHardwareAvailable: true,
      );
    } catch (e) {
      developer.log('Unexpected biometric gate failure', name: 'BiometricAuthService', error: e);
      return BiometricAuthResult(
        isAuthenticated: false,
        errorCode: 'UNEXPECTED_EXCEPTION',
        errorMessage: e.toString(),
        isHardwareAvailable: false,
      );
    }
  }

  Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } on PlatformException catch (e) {
      developer.log('Stop authentication exception: ${e.message}', name: 'BiometricAuthService', error: e);
    }
  }
}
