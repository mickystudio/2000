import 'dart:developer' as developer;
import 'package:flutter/services.dart';

enum StealthModeType {
  defaultVault,
  calculator,
  notes;

  String get code {
    switch (this) {
      case StealthModeType.calculator:
        return 'calculator';
      case StealthModeType.notes:
        return 'notes';
      case StealthModeType.defaultVault:
        return 'default';
    }
  }

  String get displayName {
    switch (this) {
      case StealthModeType.calculator:
        return 'Calculator Disguise';
      case StealthModeType.notes:
        return 'Daily Notes Disguise';
      case StealthModeType.defaultVault:
        return 'Secure Vault (Default)';
    }
  }

  String get appLabel {
    switch (this) {
      case StealthModeType.calculator:
        return 'Calculator';
      case StealthModeType.notes:
        return 'Daily Notes';
      case StealthModeType.defaultVault:
        return 'Secure Vault';
    }
  }

  static StealthModeType fromCode(String? code) {
    switch (code?.toLowerCase()) {
      case 'calculator':
        return StealthModeType.calculator;
      case 'notes':
        return StealthModeType.notes;
      default:
        return StealthModeType.defaultVault;
    }
  }
}

class StealthModeService {
  static const MethodChannel _stealthChannel = MethodChannel('com.example.security/stealth_mode');
  static const MethodChannel _launchIntentChannel = MethodChannel('com.example.security/launch_intent');

  final MethodChannel stealthChannel;
  final MethodChannel launchIntentChannel;

  StealthModeService({
    MethodChannel? stealthChannel,
    MethodChannel? launchIntentChannel,
  })  : stealthChannel = stealthChannel ?? _stealthChannel,
        launchIntentChannel = launchIntentChannel ?? _launchIntentChannel;

  /// Switches active Android launcher activity-alias.
  Future<bool> setStealthMode(StealthModeType mode) async {
    try {
      final bool? success = await stealthChannel.invokeMethod<bool>(
        'setStealthMode',
        <String, dynamic>{'mode': mode.code},
      );
      developer.log('Stealth mode switched to: ${mode.code} (success=$success)', name: 'StealthModeService');
      return success ?? false;
    } catch (e) {
      developer.log('Failed to switch stealth mode: $e', name: 'StealthModeService');
      return false;
    }
  }

  /// Retrieves the current active stealth mode alias.
  Future<StealthModeType> getCurrentStealthMode() async {
    try {
      final String? modeCode = await stealthChannel.invokeMethod<String>('getCurrentStealthMode');
      return StealthModeType.fromCode(modeCode);
    } catch (e) {
      developer.log('Failed to query active stealth mode: $e', name: 'StealthModeService');
      return StealthModeType.defaultVault;
    }
  }

  /// Checks if application was launched via AppWidget / Lockscreen quick-action shortcut.
  Future<String?> checkInitialLaunchTarget() async {
    try {
      final String? target = await launchIntentChannel.invokeMethod<String>('getInitialLaunchTarget');
      return target;
    } catch (e) {
      developer.log('Failed to query launch intent: $e', name: 'StealthModeService');
      return null;
    }
  }
}
