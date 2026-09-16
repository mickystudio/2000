import 'environmental_filter_config.dart';

enum CopingCategory {
  physiological,
  cognitive,
  spiritual,
  somaticGrounding,
  environmentalShift;

  String get displayName {
    switch (this) {
      case CopingCategory.physiological:
        return 'Physiological Reset (TIPP)';
      case CopingCategory.cognitive:
        return 'Cognitive Control';
      case CopingCategory.spiritual:
        return 'Spiritual / Hesychastic';
      case CopingCategory.somaticGrounding:
        return 'Somatic Grounding';
      case CopingCategory.environmentalShift:
        return 'Environmental Shift';
    }
  }
}

class SosCopingStrategy {
  final String id;
  final String title;
  final String shortDescription;
  final String detailedInstructions;
  final CopingCategory category;
  final int estimatedDurationMinutes;
  final bool requiresColdWater;
  final bool requiresHeadphones;
  final bool requiresLeavingSpace;
  final bool requiresVocalize;
  final List<UserLocation> allowedLocations;
  final List<UserSocialState> allowedSocialStates;
  final List<UserEnergyState> suitableEnergyStates;
  final String evidenceBasis;

  const SosCopingStrategy({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.detailedInstructions,
    required this.category,
    required this.estimatedDurationMinutes,
    this.requiresColdWater = false,
    this.requiresHeadphones = false,
    this.requiresLeavingSpace = false,
    this.requiresVocalize = false,
    this.allowedLocations = const <UserLocation>[
      UserLocation.home,
      UserLocation.workOffice,
      UserLocation.publicSpace,
      UserLocation.inTransit,
    ],
    this.allowedSocialStates = const <UserSocialState>[
      UserSocialState.alone,
      UserSocialState.withPeople,
    ],
    this.suitableEnergyStates = const <UserEnergyState>[
      UserEnergyState.lowFatigued,
      UserEnergyState.moderate,
      UserEnergyState.agitatedHigh,
    ],
    required this.evidenceBasis,
  });

  /// Evaluates whether this coping strategy is viable under the user's current environment.
  bool isViable(EnvironmentalFilterConfig config) {
    if (requiresColdWater && !config.hasColdWater) return false;
    if (requiresHeadphones && !config.hasHeadphones) return false;
    if (requiresLeavingSpace && !config.canLeaveSpace) return false;
    if (requiresVocalize && !config.canVocalize) return false;

    if (!allowedLocations.contains(config.location)) return false;
    if (!allowedSocialStates.contains(config.socialState)) return false;
    if (!suitableEnergyStates.contains(config.energyState)) return false;

    return true;
  }
}
