import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/spiritual_content_models.dart';
import '../../domain/services/spiritual_service.dart';

class SpiritualModuleScreen extends StatefulWidget {
  final String userId;

  const SpiritualModuleScreen({
    super.key,
    this.userId = 'usr_default_01',
  });

  @override
  State<SpiritualModuleScreen> createState() => _SpiritualModuleScreenState();
}

class _SpiritualModuleScreenState extends State<SpiritualModuleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SpiritualService _spiritualService = SpiritualService();

  late AgpeyaPrayerHour _recommendedAgpeya;
  SpiritualQuoteTag _selectedQuoteTag = SpiritualQuoteTag.temptation;
  List<SpiritualQuote> _filteredQuotes = <SpiritualQuote>[];

  // Nightly Examen State
  final TextEditingController _gratitude1Ctrl = TextEditingController();
  final TextEditingController _gratitude2Ctrl = TextEditingController();
  final TextEditingController _gratitude3Ctrl = TextEditingController();
  final TextEditingController _logismoiCtrl = TextEditingController();
  final TextEditingController _repentanceCtrl = TextEditingController();
  final TextEditingController _tomorrowCtrl = TextEditingController();
  bool _isSavingExamen = false;
  String? _examenSavedMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _recommendedAgpeya = _spiritualService.getRecommendedAgpeyaHour();
    _filteredQuotes = _spiritualService.getQuotesForTag(_selectedQuoteTag);
  }

  void _onTagSelected(SpiritualQuoteTag tag) {
    setState(() {
      _selectedQuoteTag = tag;
      _filteredQuotes = _spiritualService.getQuotesForTag(tag);
    });
  }

  Future<void> _submitNightlyExamen() async {
    final List<String> gratitudes = <String>[
      _gratitude1Ctrl.text.trim(),
      _gratitude2Ctrl.text.trim(),
      _gratitude3Ctrl.text.trim(),
    ].where((String s) => s.isNotEmpty).toList();

    if (gratitudes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record at least one gratitude mercy.')),
      );
      return;
    }

    setState(() => _isSavingExamen = true);

    final NightlyExamenEntry entry = NightlyExamenEntry(
      id: 'ex_${DateTime.now().millisecondsSinceEpoch}',
      userId: widget.userId,
      date: DateTime.now(),
      gratitudeItems: gratitudes,
      logismoiReflection: _logismoiCtrl.text.trim(),
      prayerOfRepentance: _repentanceCtrl.text.trim(),
      tomorrowCommitment: _tomorrowCtrl.text.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _spiritualService.saveNightlyExamen(entry);

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isSavingExamen = false;
      _examenSavedMessage = 'Nightly Examen saved securely in SQLCipher vault.';
      _gratitude1Ctrl.clear();
      _gratitude2Ctrl.clear();
      _gratitude3Ctrl.clear();
      _logismoiCtrl.clear();
      _repentanceCtrl.clear();
      _tomorrowCtrl.clear();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gratitude1Ctrl.dispose();
    _gratitude2Ctrl.dispose();
    _gratitude3Ctrl.dispose();
    _logismoiCtrl.dispose();
    _repentanceCtrl.dispose();
    _tomorrowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'Orthodox Spiritual Sanctuary',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF14B8A6),
          labelColor: const Color(0xFF14B8A6),
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.access_time), text: 'Agpeya Risk Map'),
            Tab(icon: Icon(Icons.format_quote), text: 'Patristic Bank'),
            Tab(icon: Icon(Icons.nightlight_round), text: 'Nightly Examen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildAgpeyaTab(),
          _buildPatristicQuoteBankTab(),
          _buildNightlyExamenTab(),
        ],
      ),
    );
  }

  Widget _buildAgpeyaTab() {
    final int currentHour = DateTime.now().hour;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Active Hour Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF134E4A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF14B8A6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text('RECOMMENDED AGPEYA PRAYER', style: TextStyle(color: Color(0xFF5EEAD4), fontSize: 11, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF0F766E), borderRadius: BorderRadius.circular(4)),
                      child: Text('Current: ${currentHour.toString().padLeft(2, "0")}:00', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_recommendedAgpeya.name} • ${_recommendedAgpeya.arabicName}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(_recommendedAgpeya.commemoration, style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 12)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF042F2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '"${_recommendedAgpeya.prayerText}"',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontStyle: FontStyle.italic, height: 1.4),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Key Gospel: ${_recommendedAgpeya.keyGospel}', style: const TextStyle(color: Color(0xFF99F6E4), fontSize: 11)),
                Text('Psalms: ${_recommendedAgpeya.psalmReference}', style: const TextStyle(color: Color(0xFF5EEAD4), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Circadian Canonical Hours & Risk Heatmap',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // List of all Canonical Hours with risk multipliers
          ...SpiritualService.agpeyaHours.map((AgpeyaPrayerHour hour) {
            final bool isCurrent = hour.isCurrentHour(currentHour);
            final bool isCriticalNight = hour.baseCircadianRiskMultiplier >= 1.8;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFF14B8A6)
                      : (isCriticalNight ? const Color(0xFF991B1B) : const Color(0xFF334155)),
                  width: isCurrent ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        hour.name,
                        style: TextStyle(
                          color: isCurrent ? const Color(0xFF5EEAD4) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCriticalNight ? const Color(0xFF7F1D1D) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Risk: ${hour.baseCircadianRiskMultiplier}x',
                          style: TextStyle(
                            color: isCriticalNight ? const Color(0xFFFCA5A5) : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(hour.commemoration, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPatristicQuoteBankTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Targeted Patristic & Biblical Remedy',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select your current interior state to retrieve specific patristic medicine:',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Tag Filter Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: SpiritualQuoteTag.values.map((SpiritualQuoteTag tag) {
              final bool isSelected = _selectedQuoteTag == tag;
              return ChoiceChip(
                label: Text(tag.displayName),
                selected: isSelected,
                selectedColor: const Color(0xFF0F766E),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 12,
                ),
                onSelected: (bool selected) {
                  if (selected) _onTagSelected(tag);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Quote Cards
          ..._filteredQuotes.map((SpiritualQuote quote) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '"${quote.text}"',
                    style: const TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(quote.author, style: const TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(quote.source, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '${quote.text}\n— ${quote.author} (${quote.source})'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Quote copied to clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                  if (quote.historicalContext != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      quote.historicalContext!,
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 10),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNightlyExamenTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Orthodox Nightly Examen',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Before sleep, anchor your soul in three daily mercies, examine invading thoughts (logismoi), and pray the prayer of repentance.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_examenSavedMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF059669)),
              ),
              child: Text(
                _examenSavedMessage!,
                style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 12),
              ),
            ),

          // 1. Gratitude (3 Items)
          const Text('1. Three Daily Mercies & Graces:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _gratitude1Ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Mercy 1: e.g. Protected from temptation at 2 PM...',
              filled: true,
              fillColor: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _gratitude2Ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Mercy 2: e.g. Peaceful conversation with brother...',
              filled: true,
              fillColor: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _gratitude3Ctrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Mercy 3: e.g. Grace of strength during fatigue...',
              filled: true,
              fillColor: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Examination of Thoughts (Logismoi)
          const Text('2. Examination of Thoughts (Logismoi):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('What triggers, anger, or intrusive fantasy thoughts arose today?', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(height: 8),
          TextField(
            controller: _logismoiCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Reflect without despair on any triggers or vulnerabilities...',
              filled: true,
              fillColor: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Prayer of Repentance
          const Text('3. Prayer of Repentance & Cleansing:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _repentanceCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Lord Jesus Christ, forgive all my voluntary and involuntary transgressions...',
              filled: true,
              fillColor: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Tomorrow Commitment
          const Text('4. Spiritual Resolution for Tomorrow Morning:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _tomorrowCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'e.g. Pray 1st Hour Prime before touching phone...',
              filled: true,
              fillColor: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _isSavingExamen ? null : _submitNightlyExamen,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.lock),
            label: Text(_isSavingExamen ? 'Encrypting & Saving...' : 'Save Nightly Examen to Vault'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
