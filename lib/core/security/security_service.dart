import 'dart:developer' as developer;
import 'package:flutter/services.dart';

class SecurityService {
  static const MethodChannel _channel = MethodChannel('com.example.security/flags');

  static const String _methodEnableSecure = 'enableSecureFlag';
  static const String _methodDisableSecure = 'disableSecureFlag';
  static const String _methodIsSecureEnabled = 'isSecureFlagEnabled';

  static final SecurityService _instance = SecurityService._internal();

  factory SecurityService() {
    return _instance;
  }

  SecurityService._internal();

  Future<bool> enableSecureScreen() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(_methodEnableSecure);
      final bool success = result ?? true;
      developer.log('SecurityService: FLAG_SECURE successfully enabled', name: 'SecurityService');
      return success;
    } on PlatformException catch (e) {
      developer.log('SecurityService: Failed to enable FLAG_SECURE: ${e.message}', name: 'SecurityService', error: e);
      return false;
    } on MissingPluginException catch (e) {
      developer.log('SecurityService: Native platform channel missing (non-Android runner)', name: 'SecurityService', error: e);
      return false;
    }
  }

  Future<bool> disableSecureScreen() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(_methodDisableSecure);
      final bool success = result ?? true;
      developer.log('SecurityService: FLAG_SECURE disabled', name: 'SecurityService');
      return success;
    } on PlatformException catch (e) {
      developer.log('SecurityService: Failed to disable FLAG_SECURE: ${e.message}', name: 'SecurityService', error: e);
      return false;
    } on MissingPluginException catch (e) {
      developer.log('SecurityService: Native platform channel missing (non-Android runner)', name: 'SecurityService', error: e);
      return false;
    }
  }

  Future<bool> isSecureScreenEnabled() async {
    try {
      final bool? isSecure = await _channel.invokeMethod<bool>(_methodIsSecureEnabled);
      return isSecure ?? false;
    } on PlatformException catch (e) {
      developer.log('SecurityService: Failed to query FLAG_SECURE state: ${e.message}', name: 'SecurityService', error: e);
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
