import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/environmental_filter_config.dart';
import '../models/sos_coping_strategy.dart';

class EnvironmentalFilterService {
  static const String _configKey = 'env_filter_config_v1';
  final FlutterSecureStorage _secureStorage;

  EnvironmentalFilterService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<EnvironmentalFilterConfig> getConfig() async {
    try {
      final String? jsonStr = await _secureStorage.read(key: _configKey);
      if (jsonStr == null || jsonStr.trim().isEmpty) {
        return const EnvironmentalFilterConfig();
      }
      return EnvironmentalFilterConfig.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return const EnvironmentalFilterConfig();
    }
  }

  Future<void> saveConfig(EnvironmentalFilterConfig config) async {
    await _secureStorage.write(key: _configKey, value: jsonEncode(config.toJson()));
  }

  /// Returns only coping strategies that match the provided environmental constraints.
  List<SosCopingStrategy> getFilteredStrategies(EnvironmentalFilterConfig config) {
    return allStrategies.where((SosCopingStrategy s) => s.isViable(config)).toList();
  }

  static const List<SosCopingStrategy> allStrategies = <SosCopingStrategy>[
    SosCopingStrategy(
      id: 'strat_tipp_cold_water',
      title: 'Mammalian Dive Reflex (TIPP)',
      shortDescription: 'Submerge face in a bowl of ice-cold water for 30s to stimulate the vagus nerve and slow heart rate.',
      detailedInstructions: '1. Fill a sink or bowl with cold water and ice.\n2. Take a deep breath and submerge your face up to your temples for 15-30 seconds.\n3. The trigeminal-vagal reflex activates, instantly reducing sympathetic arousal and craving intensity.',
      category: CopingCategory.physiological,
      estimatedDurationMinutes: 3,
      requiresColdWater: true,
      requiresHeadphones: false,
      requiresLeavingSpace: false,
      requiresVocalize: false,
      allowedLocations: <UserLocation>[UserLocation.home, UserLocation.workOffice],
      allowedSocialStates: <UserSocialState>[UserSocialState.alone, UserSocialState.withPeople],
      suitableEnergyStates: <UserEnergyState>[UserEnergyState.agitatedHigh, UserEnergyState.moderate],
      evidenceBasis: 'Linehan DBT distress tolerance research on vagal parasympathetic activation.',
    ),
    SosCopingStrategy(
      id: 'strat_hesychasm_jesus_prayer',
      title: 'Hesychastic Jesus Prayer Cycle',
      shortDescription: 'Synchronized rhythmic breathing with the Jesus Prayer to calm racing logismoi (thoughts).',
      detailedInstructions: '1. Inhale deeply for 4 seconds meditating: "Lord Jesus Christ, Son of God..."\n2. Exhale slowly for 6 seconds: "...have mercy on me, a sinner."\n3. Repeat for 50 breath cycles without judging intrusive thoughts.',
      category: CopingCategory.spiritual,
      estimatedDurationMinutes: 5,
      requiresColdWater: false,
      requiresHeadphones: false,
      requiresLeavingSpace: false,
      requiresVocalize: false,
      allowedLocations: <UserLocation>[UserLocation.home, UserLocation.workOffice, UserLocation.publicSpace, UserLocation.inTransit],
      allowedSocialStates: <UserSocialState>[UserSocialState.alone, UserSocialState.withPeople],
      suitableEnergyStates: <UserEnergyState>[UserEnergyState.lowFatigued, UserEnergyState.moderate, UserEnergyState.agitatedHigh],
      evidenceBasis: 'Orthodox ascetic hesychasm & slow-paced resonant breathing (0.1 Hz vagal stimulation).',
    ),
    SosCopingStrategy(
      id: 'strat_brisk_physical_walk',
      title: 'Rapid Environmental Shift & Brisk Walk',
      shortDescription: 'Immediately leave the current room or trigger zone and walk vigorously for 10 minutes.',
      detailedInstructions: '1. Stand up immediately without deliberation.\n2. Walk outdoors or in hallways with an upright posture and brisk pace.\n3. Observe 5 distinct colors, 4 textures, 3 sounds around you to ground somatic awareness.',
      category: CopingCategory.environmentalShift,
      estimatedDurationMinutes: 10,
      requiresColdWater: false,
      requiresHeadphones: false,
      requiresLeavingSpace: true,
      requiresVocalize: false,
      allowedLocations: <UserLocation>[UserLocation.home, UserLocation.workOffice],
      allowedSocialStates: <UserSocialState>[UserSocialState.alone, UserSocialState.withPeople],
      suitableEnergyStates: <UserEnergyState>[UserEnergyState.agitatedHigh, UserEnergyState.moderate],
      evidenceBasis: 'Dopaminergic receptor redistribution via motor activation and stimulus interruption.',
    ),
    SosCopingStrategy(
      id: 'strat_audio_psalm_50',
      title: 'Chanted Psalm 50 / Audio Agpeya',
      shortDescription: 'Put on headphones and listen to contemplative choral Psalm recitation.',
      detailedInstructions: '1. Put on headphones.\n2. Listen attentively to the chanted Psalm of Repentance ("Have mercy upon me, O God...").\n3. Let the ancient modal cadence absorb auditory and working memory capacity.',
      category: CopingCategory.spiritual,
      estimatedDurationMinutes: 7,
      requiresColdWater: false,
      requiresHeadphones: true,
      requiresLeavingSpace: false,
      requiresVocalize: false,
      allowedLocations: <UserLocation>[UserLocation.home, UserLocation.workOffice, UserLocation.publicSpace, UserLocation.inTransit],
      allowedSocialStates: <UserSocialState>[UserSocialState.alone, UserSocialState.withPeople],
      suitableEnergyStates: <UserEnergyState>[UserEnergyState.lowFatigued, UserEnergyState.moderate, UserEnergyState.agitatedHigh],
      evidenceBasis: 'Auditory cognitive capture and affective neural stabilization.',
    ),
    SosCopingStrategy(
      id: 'strat_prostrations_metanias',
      title: 'Physical Metanias (Prostrations)',
      shortDescription: 'Perform 12 slow, reverent prostrations with the Sign of the Cross to engage full-body kinetic energy.',
      detailedInstructions: '1. Stand before the icon or neutral space.\n2. Cross yourself and bow to the ground, touching forehead to the floor.\n3. Rise with breath, saying: "Lord Jesus Christ, help me." Repeat 12 to 24 times.',
      category: CopingCategory.spiritual,
      estimatedDurationMinutes: 6,
      requiresColdWater: false,
      requiresHeadphones: false,
      requiresLeavingSpace: false,
      requiresVocalize: true,
      allowedLocations: <UserLocation>[UserLocation.home],
      allowedSocialStates: <UserSocialState>[UserSocialState.alone],
      suitableEnergyStates: <UserEnergyState>[UserEnergyState.agitatedHigh, UserEnergyState.moderate],
      evidenceBasis: 'Kinetic physical exhaustion of compulsive sympathetic drive combined with prayer.',
    ),
    SosCopingStrategy(
      id: 'strat_somatic_54321_grounding',
      title: '5-4-3-2-1 Sensory Reset',
      shortDescription: 'Anchor your sensory cortex by identifying 5 things you see, 4 you feel, 3 you hear, 2 you smell, 1 you taste.',
      detailedInstructions: '1. Acknowledge 5 visual details around you.\n2. Feel 4 tactile sensations (feet on floor, fabric texture).\n3. Listen for 3 distinct audio frequencies.\n4. Detect 2 scent nuances.\n5. Notice 1 taste sensation.',
      category: CopingCategory.somaticGrounding,
      estimatedDurationMinutes: 4,
      requiresColdWater: false,
      requiresHeadphones: false,
      requiresLeavingSpace: false,
      requiresVocalize: false,
      allowedLocations: <UserLocation>[UserLocation.home, UserLocation.workOffice, UserLocation.publicSpace, UserLocation.inTransit],
      allowedSocialStates: <UserSocialState>[UserSocialState.alone, UserSocialState.withPeople],
      suitableEnergyStates: <UserEnergyState>[UserEnergyState.lowFatigued, UserEnergyState.moderate, UserEnergyState.agitatedHigh],
      evidenceBasis: 'Parietal-insula sensory grounding interrupts orbitofrontal craving hyperfixation.',
    ),
  ];
}
