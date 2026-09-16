import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tier2_escalation_screen.dart';

class Tier3LockdownScreen extends StatefulWidget {
  final String? triggerReason;
  final VoidCallback? onAcknowledged;

  const Tier3LockdownScreen({
    super.key,
    this.triggerReason,
    this.onAcknowledged,
  });

  @override
  State<Tier3LockdownScreen> createState() => _Tier3LockdownScreenState();
}

class _Tier3LockdownScreenState extends State<Tier3LockdownScreen> {
  bool _understandsClinicalNeed = false;
  bool _pledgesMedicalContact = false;
  final TextEditingController _ackCodeController = TextEditingController();
  String? _errorMessage;

  static const String requiredAckPhrase = 'I COMMIT TO CLINICAL SUPPORT';

  void _submitAcknowledgment() {
    if (!_understandsClinicalNeed || !_pledgesMedicalContact) {
      setState(() {
        _errorMessage = 'You must check both clinical acknowledgment declarations before proceeding.';
      });
      return;
    }

    if (_ackCodeController.text.trim().toUpperCase() != requiredAckPhrase) {
      setState(() {
        _errorMessage = 'Please type "$requiredAckPhrase" exactly to confirm your acknowledgment.';
      });
      return;
    }

    HapticFeedback.heavyImpact();
    widget.onAcknowledged?.call();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ackCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Strictly prevent hardware or gesture back button from dismissing without acknowledgment
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF180808),
        appBar: AppBar(
          backgroundColor: const Color(0xFF7F1D1D),
          automaticallyImplyLeading: false,
          title: const Row(
            children: <Widget>[
              Icon(Icons.lock, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'TIER 3 CLINICAL LOCKDOWN',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Lockdown Alert
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A0A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEF4444), width: 2.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Row(
                        children: <Widget>[
                          Icon(Icons.emergency, color: Color(0xFFEF4444), size: 28),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'SELF-GUIDED PROTOCOL LOCKED',
                              style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.triggerReason ??
                            'Trigger Condition: 3 or more severe compulsive relapses detected within the rolling 30-day window. Self-guided willpower strategies have proven mathematically insufficient to stabilize neurochemical equilibrium.',
                        style: const TextStyle(color: Color(0xFFFEE2E2), fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  '24/7 Crisis & Clinical Helplines',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // Helpline 1: SAMHSA
                _buildResourceCard(
                  title: 'SAMHSA National Helpline',
                  subtitle: 'Substance Abuse & Mental Health Services Administration',
                  phoneNumber: '1-800-662-4357 (HELP)',
                  details: '24/7, 365-day free and confidential treatment referral and information service.',
                  color: const Color(0xFF38BDF8),
                ),
                const SizedBox(height: 10),

                // Helpline 2: 988 Lifeline
                _buildResourceCard(
                  title: '988 Suicide & Crisis Lifeline',
                  subtitle: 'Free & Confidential Emotional Distress Support',
                  phoneNumber: 'Dial 988 or Text 988',
                  details: 'Immediate live counselor connection for severe psychological distress.',
                  color: const Color(0xFF4ADE80),
                ),
                const SizedBox(height: 10),

                // Helpline 3: Crisis Text Line
                _buildResourceCard(
                  title: 'Crisis Text Line',
                  subtitle: 'Text HOME to 741741',
                  phoneNumber: 'SMS: 741741',
                  details: 'Free 24/7 crisis support via SMS with certified crisis counselors.',
                  color: const Color(0xFFA78BFA),
                ),
                const SizedBox(height: 20),

                // Fast Action to Contacts
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const Tier2EscalationScreen(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.group),
                  label: const Text('Call Accountability Contacts / Confessor'),
                ),

                const SizedBox(height: 24),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 12),

                const Text(
                  'Mandatory Clinical Acknowledgment',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'To continue using diagnostic tracking tools in restricted mode, you must acknowledge the clinical necessity of human & medical intervention.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 14),

                CheckboxListTile(
                  value: _understandsClinicalNeed,
                  activeColor: const Color(0xFFEF4444),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'I acknowledge that solitary willpower alone cannot overcome entrenched neurological cycles and that clinical support is required.',
                    style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                  ),
                  onChanged: (bool? val) => setState(() => _understandsClinicalNeed = val ?? false),
                ),

                CheckboxListTile(
                  value: _pledgesMedicalContact,
                  activeColor: const Color(0xFFEF4444),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'I pledge to contact a licensed addiction therapist, physician, or my spiritual confessor within the next 24 hours.',
                    style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                  ),
                  onChanged: (bool? val) => setState(() => _pledgesMedicalContact = val ?? false),
                ),

                const SizedBox(height: 14),
                TextField(
                  controller: _ackCodeController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Type "$requiredAckPhrase" to confirm:',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF261212),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],

                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _submitAcknowledgment,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm & Acknowledge Protocol', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResourceCard({
    required String title,
    required String subtitle,
    required String phoneNumber,
    required String details,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(phoneNumber, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(height: 6),
          Text(details, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
        ],
      ),
    );
  }
}
