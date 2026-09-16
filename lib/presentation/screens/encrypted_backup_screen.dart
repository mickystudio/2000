import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/security/encrypted_backup_service.dart';

class EncryptedBackupScreen extends StatefulWidget {
  final String userId;
  final VoidCallback? onRestored;

  const EncryptedBackupScreen({
    super.key,
    this.userId = 'usr_default_01',
    this.onRestored,
  });

  @override
  State<EncryptedBackupScreen> createState() => _EncryptedBackupScreenState();
}

class _EncryptedBackupScreenState extends State<EncryptedBackupScreen> {
  final EncryptedBackupService _backupService = EncryptedBackupService();

  final TextEditingController _exportPassphraseCtrl = TextEditingController();
  final TextEditingController _importPassphraseCtrl = TextEditingController();
  final TextEditingController _importPayloadCtrl = TextEditingController();

  bool _obscureExportPass = true;
  bool _obscureImportPass = true;

  bool _isProcessing = false;
  String? _exportedPayload;
  String? _statusMessage;
  bool _isSuccess = false;

  Future<void> _handleExport() async {
    final String pass = _exportPassphraseCtrl.text;
    if (pass.trim().length < 6) {
      setState(() {
        _statusMessage = 'Passphrase must be at least 6 characters.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
      _exportedPayload = null;
    });

    try {
      final String payload = await _backupService.exportEncryptedBackup(
        passphrase: pass,
        userId: widget.userId,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _exportedPayload = payload;
        _statusMessage = 'Database encrypted with AES-256-CBC and signed with HMAC-SHA256 successfully!';
        _isSuccess = true;
        _isProcessing = false;
        _exportPassphraseCtrl.clear(); // Never retain passphrase in memory
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Export failed: $e';
        _isSuccess = false;
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleImport() async {
    final String pass = _importPassphraseCtrl.text;
    final String payload = _importPayloadCtrl.text.trim();

    if (pass.isEmpty || payload.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter both the personal passphrase and the encrypted JSON payload.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final bool restored = await _backupService.importEncryptedBackup(
        backupJsonString: payload,
        passphrase: pass,
      );

      if (!mounted) return;
      if (restored) {
        HapticFeedback.heavyImpact();
        setState(() {
          _statusMessage = 'Encrypted database state successfully restored into SQLCipher vault!';
          _isSuccess = true;
          _isProcessing = false;
          _importPassphraseCtrl.clear();
          _importPayloadCtrl.clear();
        });
        widget.onRestored?.call();
      } else {
        setState(() {
          _statusMessage = 'Decryption failed: Incorrect passphrase or corrupted HMAC signature.';
          _isSuccess = false;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Import error: $e';
        _isSuccess = false;
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _exportPassphraseCtrl.dispose();
    _importPassphraseCtrl.dispose();
    _importPayloadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('Encrypted Vault Backup', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Architecture banner
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
                    Row(
                      children: <Widget>[
                        Icon(Icons.enhanced_encryption, color: Color(0xFF14B8A6), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Zero-Knowledge Encrypted JSON',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'All local tables are serialized and encrypted using AES-256 with PBKDF2 key stretching. Your personal passphrase is never stored on disk or in the keystore.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_statusMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _isSuccess ? const Color(0xFF064E3B) : const Color(0xFF451A1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(color: _isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFCA5A5), fontSize: 12),
                  ),
                ),

              // Export Section
              const Text('Export Encrypted Backup', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _exportPassphraseCtrl,
                obscureText: _obscureExportPass,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Choose a personal encryption passphrase',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureExportPass ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF64748B)),
                    onPressed: () => setState(() => _obscureExportPass = !_obscureExportPass),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _isProcessing ? null : _handleExport,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F766E), padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.download),
                label: const Text('Generate AES-256 Export'),
              ),

              if (_exportedPayload != null) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1120),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0284C7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text('Encrypted JSON Output:', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _exportedPayload!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Encrypted backup copied to clipboard!')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Copy', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      Text(
                        _exportedPayload!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 16),

              // Import Section
              const Text('Import & Restore Encrypted Backup', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _importPassphraseCtrl,
                obscureText: _obscureImportPass,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Enter the passphrase used during export',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureImportPass ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF64748B)),
                    onPressed: () => setState(() => _obscureImportPass = !_obscureImportPass),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _importPayloadCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'Paste Encrypted Backup JSON Payload',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  filled: true,
                  fillColor: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isProcessing ? null : _handleImport,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7), padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.restore),
                label: const Text('Decrypt & Restore Vault State'),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
