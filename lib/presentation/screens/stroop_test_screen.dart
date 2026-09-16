import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/escalation/escalation_tier_evaluator.dart';
import '../../domain/models/escalation_tier_result.dart';
import '../../domain/models/stroop_test_result.dart';
import 'tier2_escalation_screen.dart';

class StroopColorItem {
  final String name;
  final Color color;

  const StroopColorItem(this.name, this.color);
}

class StroopTrial {
  final String word;
  final Color inkColor;
  final String correctColorName;
  final bool isCongruent;

  const StroopTrial({
    required this.word,
    required this.inkColor,
    required this.correctColorName,
    required this.isCongruent,
  });
}

class StroopTestScreen extends StatefulWidget {
  final String userId;
  final int initialCravingRating;

  const StroopTestScreen({
    super.key,
    this.userId = 'usr_default_01',
    this.initialCravingRating = 8,
  });

  @override
  State<StroopTestScreen> createState() => _StroopTestScreenState();
}

class _StroopTestScreenState extends State<StroopTestScreen> {
  static const int sessionDurationSeconds = 90;

  static const List<StroopColorItem> availableColors = <StroopColorItem>[
    StroopColorItem('RED', Color(0xFFEF4444)),
    StroopColorItem('GREEN', Color(0xFF22C55E)),
    StroopColorItem('BLUE', Color(0xFF3B82F6)),
    StroopColorItem('YELLOW', Color(0xFFEAB308)),
    StroopColorItem('PURPLE', Color(0xFFA855F7)),
  ];

  final Random _random = Random();
  final EscalationTierEvaluator _escalationEvaluator = const EscalationTierEvaluator();

  bool _hasStarted = false;
  bool _isFinished = false;

  int _secondsRemaining = sessionDurationSeconds;
  Timer? _countdownTimer;

  late StroopTrial _currentTrial;
  int _trialStartTimeMs = 0;

  int _totalTrials = 0;
  int _correctTrials = 0;
  final List<int> _reactionTimesMs = <int>[];

  late int _preCravingRating;
  int _postCravingRating = 8;
  bool _isAssessingPostCraving = false;

  Tier2Result? _tier2Result;
  final EscalationTierEvaluator _escalationEvaluator = const EscalationTierEvaluator();

  @override
  void initState() {
    super.initState();
    _preCravingRating = widget.initialCravingRating;
    _currentTrial = _generateTrial();
  }

  StroopTrial _generateTrial() {
    final StroopColorItem wordItem = availableColors[_random.nextInt(availableColors.length)];
    // 75% probability of incongruent trial for maximal cognitive interference
    final bool isCongruent = _random.nextDouble() < 0.25;
    final StroopColorItem inkItem = isCongruent
        ? wordItem
        : availableColors.where((StroopColorItem c) => c.name != wordItem.name).toList()[_random.nextInt(availableColors.length - 1)];

    return StroopTrial(
      word: wordItem.name,
      inkColor: inkItem.color,
      correctColorName: inkItem.name,
      isCongruent: isCongruent,
    );
  }

  void _startTest() {
    setState(() {
      _hasStarted = true;
      _secondsRemaining = sessionDurationSeconds;
      _trialStartTimeMs = DateTime.now().millisecondsSinceEpoch;
      _currentTrial = _generateTrial();
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _finishTest();
        }
      });
    });
  }

  void _handleColorSelection(String selectedColorName) {
    if (!_hasStarted || _isFinished) return;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int reactionTime = nowMs - _trialStartTimeMs;
    final bool isCorrect = selectedColorName == _currentTrial.correctColorName;

    setState(() {
      _totalTrials++;
      if (isCorrect) {
        _correctTrials++;
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.heavyImpact();
      }
      _reactionTimesMs.add(reactionTime);
      _trialStartTimeMs = nowMs;
      _currentTrial = _generateTrial();
    });
  }

  void _finishTest() {
    _countdownTimer?.cancel();
    setState(() {
      _isFinished = true;
      _isAssessingPostCraving = true;
    });
  }

  void _evaluateEscalation() {
    final int elapsedSeconds = sessionDurationSeconds - _secondsRemaining;
    final double avgReactionTime = _reactionTimesMs.isNotEmpty
        ? _reactionTimesMs.reduce((int a, int b) => a + b) / _reactionTimesMs.length
        : 0.0;
    final double accuracy = _totalTrials > 0 ? (_correctTrials / _totalTrials) * 100 : 0.0;

    final StroopTestResult result = StroopTestResult(
      durationSeconds: elapsedSeconds,
      initialCravingIntensity: _preCravingRating,
      postTestCravingIntensity: _postCravingRating,
      totalTrials: _totalTrials,
      correctTrials: _correctTrials,
      accuracyPercentage: accuracy,
      averageReactionTimeMs: avgReactionTime,
      completedAt: DateTime.now(),
    );

    final Tier2Result tier2Check = _escalationEvaluator.evaluateTier2Instance(result);

    setState(() {
      _tier2Result = tier2Check;
      _isAssessingPostCraving = false;
    });

    if (tier2Check.isTriggered) {
      HapticFeedback.vibrate();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Stroop Cognitive Control',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: !_hasStarted
              ? _buildIntroView()
              : _isAssessingPostCraving
                  ? _buildPostCravingAssessment()
                  : _isFinished
                      ? _buildResultsView()
                      : _buildActiveTestView(),
        ),
      ),
    );
  }

  Widget _buildIntroView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Center(
          child: Icon(Icons.psychology_alt, size: 68, color: Color(0xFF38BDF8)),
        ),
        const SizedBox(height: 20),
        const Text(
          '90-Second Cognitive Interference Task',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        const Text(
          'Prefrontal Cortex Defusion Rule:\nTap the button corresponding to the INK COLOR of the word, NOT the text itself.\n\nThis task forces your executive control network to override automatic impulsive processing.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.5),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text('Initial Craving Intensity:', style: TextStyle(color: Colors.white, fontSize: 13)),
                  Text('$_preCravingRating / 10', style: const TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _preCravingRating.toDouble(),
                min: 1.0,
                max: 10.0,
                divisions: 9,
                activeColor: const Color(0xFFEF4444),
                inactiveColor: const Color(0xFF475569),
                onChanged: (double val) => setState(() => _preCravingRating = val.toInt()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _startTest,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start 90s Stroop Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildActiveTestView() {
    final double progress = (sessionDurationSeconds - _secondsRemaining) / sessionDurationSeconds;

    return Column(
      children: <Widget>[
        // Top Timer & Accuracy Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Time: ${_secondsRemaining}s',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
            ),
            Text(
              'Accuracy: ${_totalTrials > 0 ? ((_correctTrials / _totalTrials) * 100).toStringAsFixed(0) : "100"}% ($_correctTrials/$_totalTrials)',
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFF1E293B),
          color: const Color(0xFF0284C7),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const Spacer(),

        // Stimulus Word
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
          ),
          child: Text(
            _currentTrial.word,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: _currentTrial.inkColor,
              letterSpacing: 3.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Select the INK COLOR above (not the word text)',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),

        const Spacer(),

        // Ink Color Choices
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: availableColors.map((StroopColorItem item) {
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 64) / 2,
              height: 54,
              child: ElevatedButton(
                onPressed: () => _handleColorSelection(item.name),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: item.color,
                  side: BorderSide(color: item.color, width: 2.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  item.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPostCravingAssessment() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF22C55E)),
        const SizedBox(height: 16),
        const Text(
          '90-Second Session Complete',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Rate your urge intensity right now after completing the cognitive task:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: <Widget>[
              Text(
                '$_postCravingRating / 10',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _postCravingRating >= 8 ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                ),
              ),
              Slider(
                value: _postCravingRating.toDouble(),
                min: 1.0,
                max: 10.0,
                divisions: 9,
                activeColor: _postCravingRating >= 8 ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
                onChanged: (double val) => setState(() => _postCravingRating = val.toInt()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _evaluateEscalation,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Submit & View Results', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    final double avgReactionTime = _reactionTimesMs.isNotEmpty
        ? _reactionTimesMs.reduce((int a, int b) => a + b) / _reactionTimesMs.length
        : 0.0;
    final double accuracy = _totalTrials > 0 ? (_correctTrials / _totalTrials) * 100 : 0.0;
    final bool isTier2 = _tier2Result?.isTriggered ?? false;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Escalation Flag Alert if Tier 2 fires
          if (isTier2)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF451A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'TIER 2 HUMAN ESCALATION TRIGGERED',
                        style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tier2Result?.diagnosticReason ?? 'Craving intensity remained >= 8/10 after 90s cognitive trial. Automatic protocol demands human contact.',
                    style: const TextStyle(color: Color(0xFFFEE2E2), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) => const Tier2EscalationScreen(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.phone_forwarded),
                    label: const Text('Open Emergency Contacts Fast-Dial'),
                  ),
                ],
              ),
            ),

          // Cognitive Performance Metrics
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Session Cognitive Metrics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    _metricCard('Accuracy', '${accuracy.toStringAsFixed(0)}%', const Color(0xFF22C55E)),
                    const SizedBox(width: 12),
                    _metricCard('Avg RT', '${avgReactionTime.toStringAsFixed(0)}ms', const Color(0xFF38BDF8)),
                    const SizedBox(width: 12),
                    _metricCard('Trials', '$_totalTrials', const Color(0xFFA855F7)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text('Pre vs Post Craving Delta:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    Text(
                      '$_preCravingRating  ➔  $_postCravingRating (${_postCravingRating - _preCravingRating <= 0 ? "" : "+"}${_postCravingRating - _preCravingRating})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _postCravingRating < _preCravingRating ? const Color(0xFF22C55E) : const Color(0xFFF87171),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.done),
            label: const Text('Done & Return'),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: <Widget>[
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}
