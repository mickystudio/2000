import 'package:flutter/material.dart';
import '../../domain/models/morning_check_in.dart';
import '../../domain/repositories/bio_data_repository.dart';

/// Single-tap Morning Self-Assessment UI.
///
/// Features:
/// - 3-tier clinical scale: Low Energy/High Stress (85.0), Balanced/Steady (50.0), High Clarity/Resilient (15.0).
/// - Instant single-tap selection and immediate persistence to `daily_checkins` in SQLCipher.
/// - Directly feeds into VulnerabilityIndex's SelfReportScore regardless of biometric sync mode.
class MorningAssessmentWidget extends StatefulWidget {
  final String userId;
  final BioDataRepository repository;
  final VoidCallback? onSubmitted;

  const MorningAssessmentWidget({
    super.key,
    required this.userId,
    required this.repository,
    this.onSubmitted,
  });

  @override
  State<MorningAssessmentWidget> createState() => _MorningAssessmentWidgetState();
}

class _MorningAssessmentWidgetState extends State<MorningAssessmentWidget> {
  MorningCheckIn? _currentCheckIn;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentCheckIn();
  }

  Future<void> _loadCurrentCheckIn() async {
    setState(() => _isLoading = true);
    final MorningCheckIn? checkIn = await widget.repository.getLatestMorningCheckIn(userId: widget.userId);
    if (!mounted) return;
    setState(() {
      _currentCheckIn = checkIn;
      _isLoading = false;
    });
  }

  Future<void> _handleTierTap(MorningAssessmentTier tier) async {
    setState(() => _isSaving = true);
    try {
      final MorningCheckIn saved = await widget.repository.recordMorningCheckIn(
        userId: widget.userId,
        tier: tier,
      );
      if (!mounted) return;
      setState(() {
        _currentCheckIn = saved;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Morning check-in saved: ${tier.label}'),
          backgroundColor: const Color(0xFF0F766E),
          duration: const Duration(seconds: 2),
        ),
      );
      widget.onSubmitted?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record check-in: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Morning Self-Assessment',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_currentCheckIn != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064E3B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Recorded for ${_currentCheckIn!.checkinDate}',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF451A03),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFB45309)),
                  ),
                  child: const Text(
                    'Pending (Baseline: 50%)',
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Single-tap mood & executive energy rating. Calibrates psychometric baseline in VulnerabilityIndex.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildTierButton(
                  tier: MorningAssessmentTier.low,
                  title: 'Low / Stressed',
                  subtitle: 'Vuln: 85%',
                  color: const Color(0xFFEF4444),
                  activeColor: const Color(0xFF7F1D1D),
                  icon: Icons.battery_alert,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTierButton(
                  tier: MorningAssessmentTier.neutral,
                  title: 'Balanced',
                  subtitle: 'Vuln: 50%',
                  color: const Color(0xFFF59E0B),
                  activeColor: const Color(0xFF78350F),
                  icon: Icons.battery_charging_full,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTierButton(
                  tier: MorningAssessmentTier.resilient,
                  title: 'High Clarity',
                  subtitle: 'Vuln: 15%',
                  color: const Color(0xFF10B981),
                  activeColor: const Color(0xFF064E3B),
                  icon: Icons.shield,
                ),
              ),
            ],
          ),
          if (_isSaving) ...<Widget>[
            const SizedBox(height: 10),
            const LinearProgressIndicator(color: Color(0xFF14B8A6), backgroundColor: Color(0xFF0F172A)),
          ],
        ],
      ),
    );
  }

  Widget _buildTierButton({
    required MorningAssessmentTier tier,
    required String title,
    required String subtitle,
    required Color color,
    required Color activeColor,
    required IconData icon,
  }) {
    final bool isSelected = _currentCheckIn?.tier == tier;

    return InkWell(
      onTap: _isSaving ? null : () => _handleTierTap(tier),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? const Color(0xFFF1F5F9) : const Color(0xFF64748B),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
