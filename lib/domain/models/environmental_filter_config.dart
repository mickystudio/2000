enum UserLocation {
  home,
  workOffice,
  publicSpace,
  inTransit;

  String get displayName {
    switch (this) {
      case UserLocation.home:
        return 'At Home';
      case UserLocation.workOffice:
        return 'At Work / Office';
      case UserLocation.publicSpace:
        return 'In Public';
      case UserLocation.inTransit:
        return 'In Transit / Commute';
    }
  }
}

enum UserSocialState {
  alone,
  withPeople;

  String get displayName {
    switch (this) {
      case UserSocialState.alone:
        return 'Alone';
      case UserSocialState.withPeople:
        return 'Around Others';
    }
  }
}

enum UserEnergyState {
  lowFatigued,
  moderate,
  agitatedHigh;

  String get displayName {
    switch (this) {
      case UserEnergyState.lowFatigued:
        return 'Low / Exhausted';
      case UserEnergyState.moderate:
        return 'Moderate Energy';
      case UserEnergyState.agitatedHigh:
        return 'High Agitation / Restless';
    }
  }
}

class EnvironmentalFilterConfig {
  final UserLocation location;
  final UserSocialState socialState;
  final UserEnergyState energyState;
  final bool hasColdWater;
  final bool hasHeadphones;
  final bool canLeaveSpace;
  final bool canVocalize;

  const EnvironmentalFilterConfig({
    this.location = UserLocation.home,
    this.socialState = UserSocialState.alone,
    this.energyState = UserEnergyState.agitatedHigh,
    this.hasColdWater = true,
    this.hasHeadphones = true,
    this.canLeaveSpace = true,
    this.canVocalize = true,
  });

  EnvironmentalFilterConfig copyWith({
    UserLocation? location,
    UserSocialState? socialState,
    UserEnergyState? energyState,
    bool? hasColdWater,
    bool? hasHeadphones,
    bool? canLeaveSpace,
    bool? canVocalize,
  }) {
    return EnvironmentalFilterConfig(
      location: location ?? this.location,
      socialState: socialState ?? this.socialState,
      energyState: energyState ?? this.energyState,
      hasColdWater: hasColdWater ?? this.hasColdWater,
      hasHeadphones: hasHeadphones ?? this.hasHeadphones,
      canLeaveSpace: canLeaveSpace ?? this.canLeaveSpace,
      canVocalize: canVocalize ?? this.canVocalize,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'location': location.name,
        'social_state': socialState.name,
        'energy_state': energyState.name,
        'has_cold_water': hasColdWater,
        'has_headphones': hasHeadphones,
        'can_leave_space': canLeaveSpace,
        'can_vocalize': canVocalize,
      };

  factory EnvironmentalFilterConfig.fromJson(Map<String, dynamic> json) {
    return EnvironmentalFilterConfig(
      location: UserLocation.values.firstWhere(
        (UserLocation l) => l.name == json['location'],
        orElse: () => UserLocation.home,
      ),
      socialState: UserSocialState.values.firstWhere(
        (UserSocialState s) => s.name == json['social_state'],
        orElse: () => UserSocialState.alone,
      ),
      energyState: UserEnergyState.values.firstWhere(
        (UserEnergyState e) => e.name == json['energy_state'],
        orElse: () => UserEnergyState.agitatedHigh,
      ),
      hasColdWater: json['has_cold_water'] as bool? ?? true,
      hasHeadphones: json['has_headphones'] as bool? ?? true,
      canLeaveSpace: json['can_leave_space'] as bool? ?? true,
      canVocalize: json['can_vocalize'] as bool? ?? true,
    );
  }
}
