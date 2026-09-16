import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/accountability_contact.dart';
import '../../domain/services/accountability_contact_service.dart';

class Tier2EscalationScreen extends StatefulWidget {
  final String? triggerReason;

  const Tier2EscalationScreen({
    super.key,
    this.triggerReason,
  });

  @override
  State<Tier2EscalationScreen> createState() => _Tier2EscalationScreenState();
}

class _Tier2EscalationScreenState extends State<Tier2EscalationScreen> {
  final AccountabilityContactService _contactService = AccountabilityContactService();
  List<AccountabilityContact> _contacts = <AccountabilityContact>[];
  bool _isLoading = true;
  String? _statusFeedback;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    final List<AccountabilityContact> list = await _contactService.getContacts();
    if (!mounted) return;
    setState(() {
      _contacts = list;
      _isLoading = false;
    });
  }

  void _triggerCall(AccountabilityContact contact) {
    HapticFeedback.heavyImpact();
    setState(() {
      _statusFeedback = 'Initiating secure fast-dial to ${contact.name} (${contact.phoneNumber})...';
    });
    // In a real device environment, this uses url_launcher with tel: protocol
  }

  void _triggerSms(AccountabilityContact contact) {
    HapticFeedback.mediumImpact();
    final String message = contact.preformattedSosMessage ??
        'Urgent: Experiencing an acute urge wave and need your immediate prayer and support.';
    Clipboard.setData(ClipboardData(text: message));
    setState(() {
      _statusFeedback = 'Pre-formatted SOS message copied to clipboard for ${contact.name}!';
    });
  }

  void _showAddContactDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController msgCtrl = TextEditingController(
      text: 'Acute urge spike in progress. Requesting urgent counsel & prayer.',
    );
    AccountabilityRole selectedRole = AccountabilityRole.sponsor;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Add Accountability Contact', style: TextStyle(color: Colors.white, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Contact Name',
                        labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF475569))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF475569))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AccountabilityRole>(
                      value: selectedRole,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Role / Relationship'),
                      items: AccountabilityRole.values.map((AccountabilityRole r) {
                        return DropdownMenuItem<AccountabilityRole>(
                          value: r,
                          child: Text(r.displayName),
                        );
                      }).toList(),
                      onChanged: (AccountabilityRole? r) {
                        if (r != null) setDialogState(() => selectedRole = r);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: msgCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Pre-formatted SOS Message',
                        labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isNotEmpty && phoneCtrl.text.trim().isNotEmpty) {
                      final AccountabilityContact newContact = AccountabilityContact(
                        id: 'ct_${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text.trim(),
                        role: selectedRole,
                        phoneNumber: phoneCtrl.text.trim(),
                        preformattedSosMessage: msgCtrl.text.trim(),
                        isEmergencyFastDial: true,
                      );
                      await _contactService.addContact(newContact);
                      Navigator.of(ctx).pop();
                      _loadContacts();
                    }
                  },
                  child: const Text('Save Contact'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7F1D1D),
        elevation: 0,
        title: const Text(
          'Tier 2 Human Escalation',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
            tooltip: 'Add Contact',
            onPressed: _showAddContactDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFEF4444)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Escalation Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF451A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDC2626)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Row(
                            children: <Widget>[
                              Icon(Icons.shield_outlined, color: Color(0xFFEF4444), size: 24),
                              SizedBox(width: 8),
                              Text(
                                'HUMAN CONNECTION MANDATE',
                                style: TextStyle(
                                  color: Color(0xFFFCA5A5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.triggerReason ??
                                'Solitary willpower has degraded past clinical safety thresholds. You must break isolation and speak directly with an authorized accountability partner now.',
                            style: const TextStyle(color: Color(0xFFFEE2E2), fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_statusFeedback != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF064E3B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF059669)),
                        ),
                        child: Text(
                          _statusFeedback!,
                          style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 12),
                        ),
                      ),

                    const Text(
                      'Emergency Fast-Dial Contacts',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Contact Cards
                    ..._contacts.map((AccountabilityContact contact) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      contact.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${contact.role.displayName} • ${contact.phoneNumber}',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFF64748B), size: 18),
                                  onPressed: () async {
                                    await _contactService.removeContact(contact.id);
                                    _loadContacts();
                                  },
                                ),
                              ],
                            ),
                            if (contact.preformattedSosMessage != null) ...<Widget>[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'SOS Text: "${contact.preformattedSosMessage}"',
                                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _triggerCall(contact),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    icon: const Icon(Icons.phone, size: 16),
                                    label: const Text('Call Now', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _triggerSms(contact),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF38BDF8),
                                      side: const BorderSide(color: Color(0xFF0284C7)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                    label: const Text('Copy SOS Text'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Return to Safety Tools'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
