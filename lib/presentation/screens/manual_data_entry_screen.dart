import 'package:flutter/material.dart';
import '../../domain/models/biometric_sample.dart';
import '../../domain/repositories/bio_data_repository.dart';

/// Fallback data entry screen for recording sleep duration and step counts.
/// Used automatically whenever Huawei Health Kit is unavailable, unauthorized, or stale (> 20 hours).
class ManualDataEntryScreen extends StatefulWidget {
  final String userId;
  final BioDataRepository repository;
  final VoidCallback? onSaved;

  const ManualDataEntryScreen({
    super.key,
    required this.userId,
    required this.repository,
    this.onSaved,
  });

  @override
  State<ManualDataEntryScreen> createState() => _ManualDataEntryScreenState();
}

class _ManualDataEntryScreenState extends State<ManualDataEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _totalSleepController;
  late TextEditingController _deepSleepController;
  late TextEditingController _remSleepController;
  late TextEditingController _stepCountController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _totalSleepController = TextEditingController(text: '7.5');
    _deepSleepController = TextEditingController(text: '1.5');
    _remSleepController = TextEditingController(text: '1.5');
    _stepCountController = TextEditingController(text: '7500');
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final BiometricSample? sample = await widget.repository.getLatestBiometricSample(userId: widget.userId);
    if (sample != null && mounted) {
      setState(() {
        _totalSleepController.text = sample.totalSleepHours.toString();
        if (sample.deepSleepHours != null) {
          _deepSleepController.text = sample.deepSleepHours.toString();
        }
        if (sample.remSleepHours != null) {
          _remSleepController.text = sample.remSleepHours.toString();
        }
        _stepCountController.text = sample.stepCount.toString();
      });
    }
  }

  @override
  void dispose() {
    _totalSleepController.dispose();
    _deepSleepController.dispose();
    _remSleepController.dispose();
    _stepCountController.dispose();
    super.dispose();
  }

  Future<void> _submitManualData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final double totalSleep = double.parse(_totalSleepController.text.trim());
      final double? deepSleep = _deepSleepController.text.trim().isNotEmpty
          ? double.tryParse(_deepSleepController.text.trim())
          : null;
      final double? remSleep = _remSleepController.text.trim().isNotEmpty
          ? double.tryParse(_remSleepController.text.trim())
          : null;
      final int steps = int.parse(_stepCountController.text.trim());

      await widget.repository.recordManualBiometrics(
        userId: widget.userId,
        totalSleepHours: totalSleep,
        stepCount: steps,
        deepSleepHours: deepSleep,
        remSleepHours: remSleep,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Manual biometric telemetry recorded successfully'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );

      widget.onSaved?.call();
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording telemetry: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Biometric Entry'),
        backgroundColor: const Color(0xFF111827),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Automatic Fallback Mode: Active whenever Huawei Health Kit is unauthorized, offline, or telemetry is > 20 hours stale.',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sleep Architecture (Hours)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _totalSleepController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total Sleep Duration (Hours) *',
                  hintText: 'e.g. 7.5',
                  prefixIcon: Icon(Icons.bedtime_outlined),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFF0F172A),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter total sleep hours';
                  final double? numVal = double.tryParse(value.trim());
                  if (numVal == null || numVal < 0.0 || numVal > 24.0) {
                    return 'Enter a valid number between 0 and 24';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _deepSleepController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Deep Sleep (Opt)',
                        hintText: 'e.g. 1.5',
                        prefixIcon: Icon(Icons.nightlight_round),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFF0F172A),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final double? numVal = double.tryParse(value.trim());
                        if (numVal == null || numVal < 0.0 || numVal > 24.0) {
                          return 'Between 0 and 24';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _remSleepController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'REM Sleep (Opt)',
                        hintText: 'e.g. 1.5',
                        prefixIcon: Icon(Icons.remove_red_eye_outlined),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFF0F172A),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final double? numVal = double.tryParse(value.trim());
                        if (numVal == null || numVal < 0.0 || numVal > 24.0) {
                          return 'Between 0 and 24';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Physical Activity',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stepCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Daily Step Count *',
                  hintText: 'e.g. 8500',
                  prefixIcon: Icon(Icons.directions_walk),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFF0F172A),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter step count';
                  final int? numVal = int.tryParse(value.trim());
                  if (numVal == null || numVal < 0) return 'Must be a non-negative number';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submitManualData,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Persisting to Encrypted Vault...' : 'Save Biometric Telemetry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
