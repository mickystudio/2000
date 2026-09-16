import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/database/database_constants.dart';
import '../../data/database/encrypted_database.dart';
import 'stroop_test_screen.dart';
import 'spiritual_module_screen.dart';
import 'tier2_escalation_screen.dart';

class UrgeWaveSurfingScreen extends StatefulWidget {
  final String userId;
  final bool isDirectShortcutLaunch;

  const UrgeWaveSurfingScreen({
    super.key,
    this.userId = 'usr_default_01',
    this.isDirectShortcutLaunch = false,
  });

  @override
  State<UrgeWaveSurfingScreen> createState() => _UrgeWaveSurfingScreenState();
}

class _UrgeWaveSurfingScreenState extends State<UrgeWaveSurfingScreen>
    with SingleTickerProviderStateMixin {
  static const int totalSessionSeconds = 15 * 60; // 900 seconds (15 minutes)
  static const int promptIntervalSeconds = 60; // rating prompt every 60 seconds

  late AnimationController _waveAnimController;
  Timer? _timer;
  int _secondsRemaining = totalSessionSeconds;
  bool _isRunning = true;

  // Time-series of urge intensity ratings [0..10]
  final List<int> _ratingHistory = <int>[];
  final List<int> _timestampHistory = <int>[];

  int _currentRating = 8;
  bool _showRatingDialog = false;
  int _ratingPromptCountdown = promptIntervalSeconds;

  String _breathPhase = 'Inhale';
  int _breathTimer = 4;
  Timer? _breathCycleTimer;

  final EncryptedDatabase _database = EncryptedDatabase();

  @override
  void initState() {
    super.initState();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Initial baseline rating
    _ratingHistory.add(_currentRating);
    _timestampHistory.add(0);

    _startSessionTimer();
    _startBreathingCycle();
  }

  void _startSessionTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;

      setState(() {
        if (_secondsRemaining > 0 && _isRunning) {
          _secondsRemaining--;
          _ratingPromptCountdown--;

          if (_ratingPromptCountdown <= 0) {
            _ratingPromptCountdown = promptIntervalSeconds;
            _showRatingDialog = true;
            HapticFeedback.heavyImpact();
          }
        } else if (_secondsRemaining <= 0) {
          _timer?.cancel();
          _isRunning = false;
          _saveSosSession('COMPLETED_15MIN');
        }
      });
    });
  }

  void _startBreathingCycle() {
    _breathCycleTimer?.cancel();
    _breathCycleTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted || !_isRunning) return;
      setState(() {
        _breathTimer--;
        if (_breathTimer <= 0) {
          if (_breathPhase == 'Inhale') {
            _breathPhase = 'Hold';
            _breathTimer = 4;
            HapticFeedback.selectionClick();
          } else if (_breathPhase == 'Hold') {
            _breathPhase = 'Exhale Slowly';
            _breathTimer = 6;
            HapticFeedback.selectionClick();
          } else {
            _breathPhase = 'Inhale';
            _breathTimer = 4;
            HapticFeedback.mediumImpact();
          }
        }
      });
    });
  }

  void _submitRating(int rating) {
    setState(() {
      _currentRating = rating;
      final int elapsed = totalSessionSeconds - _secondsRemaining;
      _ratingHistory.add(rating);
      _timestampHistory.add(elapsed);
      _showRatingDialog = false;
      _ratingPromptCountdown = promptIntervalSeconds;
    });

    // If craving remains critical, highlight Tier 2 option
    if (rating >= 8) {
      HapticFeedback.vibrate();
    }
  }

  Future<void> _saveSosSession(String outcome) async {
    try {
      final db = await _database.database;
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int elapsed = totalSessionSeconds - _secondsRemaining;

      await db.insert(DatabaseConstants.tableSosSessions, <String, dynamic>{
        'id': 'sos_${now}_${widget.userId}',
        'user_id': widget.userId,
        'trigger_reason': 'ACUTE_URGE_WAVE_SURFING',
        'duration_seconds': elapsed,
        'outcome_state': outcome,
        'notes': 'Initial: ${_ratingHistory.first}, Final: ${_ratingHistory.last}, Ratings: ${_ratingHistory.join(",")}',
        'started_at': now - (elapsed * 1000),
        'ended_at': now,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathCycleTimer?.cancel();
    _waveAnimController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final int elapsed = totalSessionSeconds - _secondsRemaining;
    final double progress = elapsed / totalSessionSeconds;

    return Scaffold(
      backgroundColor: const Color(0xFF07141A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () {
            _saveSosSession('INTERRUPTED_BY_USER');
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              SystemNavigator.pop();
            }
          },
        ),
        title: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0E7490),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SOS CRISIS MODE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.isDirectShortcutLaunch)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF0284C7)),
                ),
                child: const Text('Zero Friction', style: TextStyle(fontSize: 10, color: Color(0xFF38BDF8))),
              ),
          ],
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const Tier2EscalationScreen(),
                ),
              );
            },
            icon: const Icon(Icons.phone_in_talk, color: Color(0xFFF87171), size: 18),
            label: const Text('I Need Help', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                // Header countdown and breathing rhythm
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '15-Minute Urge Surfing',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Neurobiology: Urges crest like ocean waves and naturally subside within 15-20 min.',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Main visual wave & breathing indicator
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // Fluid Wave Animated Canvas
                        AnimatedBuilder(
                          animation: _waveAnimController,
                          builder: (BuildContext context, Widget? child) {
                            return CustomPaint(
                              painter: WaveSurfingPainter(
                                animationValue: _waveAnimController.value,
                                currentRating: _currentRating,
                                breathPhase: _breathPhase,
                              ),
                              size: const Size(300, 300),
                            );
                          },
                        ),

                        // Center Countdown & Breathing Cues
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              _formatTime(_secondsRemaining),
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E7490).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF06B6D4)),
                              ),
                              child: Text(
                                '$_breathPhase ($_breathTimer s)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF67E8F9),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Current Intensity: $_currentRating / 10',
                              style: TextStyle(
                                fontSize: 12,
                                color: _currentRating >= 8 ? const Color(0xFFFCA5A5) : const Color(0xFF94A3B8),
                                fontWeight: _currentRating >= 8 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Real-time wave intensity curve
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              'Urge Intensity Curve',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Prompt in ${_ratingPromptCountdown}s',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: CustomPaint(
                            painter: UrgeIntensityCurvePainter(
                              ratings: _ratingHistory,
                              timestamps: _timestampHistory,
                              totalDuration: totalSessionSeconds,
                            ),
                            child: Container(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) => StroopTestScreen(
                                  userId: widget.userId,
                                  initialCravingRating: _currentRating,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.psychology, size: 18),
                          label: const Text('Stroop Mini-Game'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) => SpiritualModuleScreen(userId: widget.userId),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.menu_book, size: 18),
                          label: const Text('Agpeya & Prayer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Rating prompt modal overlay
            if (_showRatingDialog)
              Container(
                color: Colors.black.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF0E7490), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'Momentary Urge Check',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Rate your current craving intensity right now (1 = Barely noticeable, 10 = Overwhelming):',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: List<Widget>.generate(10, (int index) {
                            final int score = index + 1;
                            final bool isHigh = score >= 8;
                            return InkWell(
                              onTap: () => _submitRating(score),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isHigh ? const Color(0xFF7F1D1D) : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isHigh ? const Color(0xFFEF4444) : const Color(0xFF334155),
                                  ),
                                ),
                                child: Text(
                                  '$score',
                                  style: TextStyle(
                                    color: isHigh ? const Color(0xFFFCA5A5) : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WaveSurfingPainter extends CustomPainter {
  final double animationValue;
  final int currentRating;
  final String breathPhase;

  WaveSurfingPainter({
    required this.animationValue,
    required this.currentRating,
    required this.breathPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double baseRadius = size.width / 2 - 20;

    // Breath expansion multiplier
    double expansion = 1.0;
    if (breathPhase == 'Inhale') {
      expansion = 1.0 + (0.12 * math.sin(animationValue * math.pi));
    } else if (breathPhase == 'Hold') {
      expansion = 1.12;
    } else {
      expansion = 1.12 - (0.12 * math.sin(animationValue * math.pi));
    }

    // Outer glow wave
    final Paint wavePaint = Paint()
      ..color = const Color(0xFF06B6D4).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final Path wavePath = Path();
    final int points = 120;
    final double angleStep = (math.pi * 2) / points;

    for (int i = 0; i <= points; i++) {
      final double angle = i * angleStep;
      // Multi-frequency sinusoidal wave
      final double waveOffset = math.sin((angle * 5) + (animationValue * math.pi * 2)) * (currentRating * 1.5) +
          math.cos((angle * 3) - (animationValue * math.pi)) * (currentRating * 0.8);

      final double r = (baseRadius * expansion) + waveOffset;
      final double x = center.dx + r * math.cos(angle);
      final double y = center.dy + r * math.sin(angle);

      if (i == 0) {
        wavePath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }
    }
    wavePath.close();
    canvas.drawPath(wavePath, wavePaint);

    // Inner pulsating body
    final Paint fillPaint = Paint()
      ..color = (currentRating >= 8
          ? const Color(0xFFDC2626).withOpacity(0.08)
          : const Color(0xFF0E7490).withOpacity(0.1))
      ..style = PaintingStyle.fill;
    canvas.drawPath(wavePath, fillPaint);

    // Inner calm target circle
    final Paint innerCirclePaint = Paint()
      ..color = const Color(0xFF0891B2).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, baseRadius * 0.75, innerCirclePaint);
  }

  @override
  bool shouldRepaint(covariant WaveSurfingPainter oldDelegate) => true;
}

class UrgeIntensityCurvePainter extends CustomPainter {
  final List<int> ratings;
  final List<int> timestamps;
  final int totalDuration;

  UrgeIntensityCurvePainter({
    required this.ratings,
    required this.timestamps,
    required this.totalDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (ratings.isEmpty) return;

    final Paint gridPaint = Paint()
      ..color = const Color(0xFF334155).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw horizontal guidelines (1, 5, 10)
    for (int level in <int>[2, 5, 8, 10]) {
      final double y = size.height - ((level / 10.0) * size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw curve
    final Paint linePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF0284C7).withOpacity(0.3),
          const Color(0xFF0284C7).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final Path path = Path();
    final Path fillPath = Path();

    for (int i = 0; i < ratings.length; i++) {
      final double x = timestamps[i] / totalDuration * size.width;
      final double y = size.height - ((ratings[i] / 10.0) * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw point
      final Paint dotPaint = Paint()
        ..color = ratings[i] >= 8 ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 4.0, dotPaint);
    }

    if (ratings.length > 1) {
      final double lastX = timestamps.last / totalDuration * size.width;
      fillPath.lineTo(lastX, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant UrgeIntensityCurvePainter oldDelegate) => true;
}
