import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/security/security_service.dart';
import '../../core/security/stealth_mode_service.dart';
import '../../data/database/encrypted_database.dart';
import 'encrypted_backup_screen.dart';
import 'tier2_escalation_screen.dart';
import 'environmental_sos_filter_screen.dart';

class SettingsAndStealthScreen extends StatefulWidget {
  final String userId;
  final VoidCallback? onDatabaseRestored;

  const SettingsAndStealthScreen({
    super.key,
    this.userId = 'usr_default_01',
    this.onDatabaseRestored,
  });

  @override
  State<SettingsAndStealthScreen> createState() => _SettingsAndStealthScreenState();
}

class _SettingsAndStealthScreenState extends State<SettingsAndStealthScreen> {
  final StealthModeService _stealthService = StealthModeService();
  final SecurityService _securityService = SecurityService();
  final EncryptedDatabase _database = EncryptedDatabase();

  StealthModeType _currentStealth = StealthModeType.defaultVault;
  bool _isSecureScreenEnabled = true;
  bool _isDbEncrypted = false;
  bool _isLoading = true;
  String? _statusFeedback;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final StealthModeType mode = await _stealthService.getCurrentStealthMode();
    final bool secure = await _securityService.isSecureScreenEnabled();
    final bool encrypted = await _database.verifyEncryption();

    if (!mounted) return;
    setState(() {
      _currentStealth = mode;
      _isSecureScreenEnabled = secure;
      _isDbEncrypted = encrypted;
      _isLoading = false;
    });
  }

  Future<void> _changeStealthMode(StealthModeType mode) async {
    HapticFeedback.selectionClick();
    final bool success = await _stealthService.setStealthMode(mode);
    if (!mounted) return;
    setState(() {
      _currentStealth = mode;
      _statusFeedback = success
          ? 'Stealth alias changed to: ${mode.displayName}. Android launcher will reflect this change.'
          : 'Failed to switch launcher component alias.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('Security & Disguise Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_statusFeedback != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF064E3B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF059669)),
                        ),
                        child: Text(_statusFeedback!, style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 12)),
                      ),

                    // Stealth Disguise Section
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
                          const Row(
                            children: <Widget>[
                              Icon(Icons.visibility_off, color: Color(0xFF38BDF8), size: 22),
                              SizedBox(width: 8),
                              Text('Stealth Mode (Manifest Alias)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Switch the app icon and label dynamically on your Android device to prevent visual surveillance.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          const SizedBox(height: 14),

                          ...StealthModeType.values.map((StealthModeType mode) {
                            final bool isSelected = _currentStealth == mode;
                            return RadioListTile<StealthModeType>(
                              value: mode,
                              groupValue: _currentStealth,
                              activeColor: const Color(0xFF14B8A6),
                              contentPadding: EdgeInsets.zero,
                              title: Text(mode.displayName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                              subtitle: Text('App Label: "${mode.appLabel}"', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                              onChanged: (StealthModeType? val) {
                                if (val != null) _changeStealthMode(val);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Security & Hardware Status Card
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
                          const Text('Hardware & Database Security', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          _statusRow('FLAG_SECURE Screen Blocker', _isSecureScreenEnabled ? 'ACTIVE (Hardware Enforced)' : 'DISABLED', const Color(0xFF22C55E)),
                          const Divider(color: Color(0xFF334155), height: 18),
                          _statusRow('SQLCipher 256-bit AES DB', _isDbEncrypted ? 'ENCRYPTED (Header Verified)' : 'UNENCRYPTED', const Color(0xFF22C55E)),
                          const Divider(color: Color(0xFF334155), height: 18),
                          _statusRow('Android Keystore Master Key', 'AES-GCM-256 (Protected)', const Color(0xFF38BDF8)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Shortcuts to Management Screens
                    ListTile(
                      tileColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: const Icon(Icons.backup, color: Color(0xFF14B8A6)),
                      title: const Text('Encrypted JSON Backup & Restore', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('AES-256 zero-knowledge export/import', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) => EncryptedBackupScreen(
                              userId: widget.userId,
                              onRestored: widget.onDatabaseRestored,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    ListTile(
                      tileColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: const Icon(Icons.group, color: Color(0xFFEF4444)),
                      title: const Text('Accountability Contacts & Hotline', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Fast-dial sponsor & confessor numbers', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) => const Tier2EscalationScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    ListTile(
                      tileColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: const Icon(Icons.tune, color: Color(0xFF38BDF8)),
                      title: const Text('Environmental Constraints Filter', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Location, energy, and coping tools', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) => EnvironmentalSosFilterScreen(userId: widget.userId),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statusRow(String label, String value, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
        Text(value, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
