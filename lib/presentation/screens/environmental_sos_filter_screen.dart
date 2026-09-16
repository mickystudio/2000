import 'package:flutter/material.dart';
import '../../domain/models/environmental_filter_config.dart';
import '../../domain/models/sos_coping_strategy.dart';
import '../../domain/services/environmental_filter_service.dart';
import 'urge_wave_surfing_screen.dart';
import 'spiritual_module_screen.dart';

class EnvironmentalSosFilterScreen extends StatefulWidget {
  final String userId;

  const EnvironmentalSosFilterScreen({
    super.key,
    this.userId = 'usr_default_01',
  });

  @override
  State<EnvironmentalSosFilterScreen> createState() => _EnvironmentalSosFilterScreenState();
}

class _EnvironmentalSosFilterScreenState extends State<EnvironmentalSosFilterScreen> {
  final EnvironmentalFilterService _filterService = EnvironmentalFilterService();
  EnvironmentalFilterConfig _config = const EnvironmentalFilterConfig();
  List<SosCopingStrategy> _viableStrategies = <SosCopingStrategy>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final EnvironmentalFilterConfig config = await _filterService.getConfig();
    final List<SosCopingStrategy> filtered = _filterService.getFilteredStrategies(config);
    if (!mounted) return;
    setState(() {
      _config = config;
      _viableStrategies = filtered;
      _isLoading = false;
    });
  }

  void _updateConfig(EnvironmentalFilterConfig newConfig) {
    setState(() {
      _config = newConfig;
      _viableStrategies = _filterService.getFilteredStrategies(newConfig);
    });
    _filterService.saveConfig(newConfig);
  }

  void _showStrategyDetails(SosCopingStrategy strategy) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.all(22.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        strategy.title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E7490).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${strategy.estimatedDurationMinutes} min',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  strategy.category.displayName,
                  style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Execution Steps:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  strategy.detailedInstructions,
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Clinical Basis: ${strategy.evidenceBasis}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Close Instructions'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Contextual SOS Filter', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Context Filter Controller Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Current Environment Constraints',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Select your present location, energy, and available resources to isolate viable tools instantly.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          const SizedBox(height: 14),

                          // Location Selector
                          const Text('Location:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: UserLocation.values.map((UserLocation loc) {
                              final bool isSelected = _config.location == loc;
                              return ChoiceChip(
                                label: Text(loc.displayName),
                                selected: isSelected,
                                selectedColor: const Color(0xFF0F766E),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                                onSelected: (bool selected) {
                                  if (selected) _updateConfig(_config.copyWith(location: loc));
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),

                          // Social & Energy Row
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Text('Social Setting:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<UserSocialState>(
                                      value: _config.socialState,
                                      dropdownColor: const Color(0xFF0F172A),
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                      items: UserSocialState.values.map((UserSocialState s) {
                                        return DropdownMenuItem<UserSocialState>(value: s, child: Text(s.displayName));
                                      }).toList(),
                                      onChanged: (UserSocialState? val) {
                                        if (val != null) _updateConfig(_config.copyWith(socialState: val));
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Text('Energy Level:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<UserEnergyState>(
                                      value: _config.energyState,
                                      dropdownColor: const Color(0xFF0F172A),
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                      items: UserEnergyState.values.map((UserEnergyState e) {
                                        return DropdownMenuItem<UserEnergyState>(value: e, child: Text(e.displayName));
                                      }).toList(),
                                      onChanged: (UserEnergyState? val) {
                                        if (val != null) _updateConfig(_config.copyWith(energyState: val));
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Available Resources Toggle Chips
                          const Text('Available Tools & Options:', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: <Widget>[
                              FilterChip(
                                label: const Text('Cold Water / Ice'),
                                selected: _config.hasColdWater,
                                selectedColor: const Color(0xFF0284C7),
                                onSelected: (bool val) => _updateConfig(_config.copyWith(hasColdWater: val)),
                              ),
                              FilterChip(
                                label: const Text('Headphones'),
                                selected: _config.hasHeadphones,
                                selectedColor: const Color(0xFF0284C7),
                                onSelected: (bool val) => _updateConfig(_config.copyWith(hasHeadphones: val)),
                              ),
                              FilterChip(
                                label: const Text('Can Leave Room'),
                                selected: _config.canLeaveSpace,
                                selectedColor: const Color(0xFF0284C7),
                                onSelected: (bool val) => _updateConfig(_config.copyWith(canLeaveSpace: val)),
                              ),
                              FilterChip(
                                label: const Text('Can Pray Aloud'),
                                selected: _config.canVocalize,
                                selectedColor: const Color(0xFF0284C7),
                                onSelected: (bool val) => _updateConfig(_config.copyWith(canVocalize: val)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Viable Strategies (${_viableStrategies.length})',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${EnvironmentalFilterService.allStrategies.length - _viableStrategies.length} filtered out',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Filtered Strategy Cards
                    if (_viableStrategies.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No strategies match all selected constraints. Adjust filters or launch Urge Wave Surfing directly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      )
                    else
                      ..._viableStrategies.map((SosCopingStrategy strat) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    strat.title,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${strat.estimatedDurationMinutes}m',
                                    style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    strat.shortDescription,
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    strat.category.displayName,
                                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                            onTap: () => _showStrategyDetails(strat),
                          ),
                        );
                      }),

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) => UrgeWaveSurfingScreen(userId: widget.userId),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.waves),
                      label: const Text('Launch 15-Min Urge Wave Surfing'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
