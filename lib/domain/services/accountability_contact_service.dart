import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/accountability_contact.dart';

class AccountabilityContactService {
  static const String _storageKey = 'accountability_contacts_v1';
  final FlutterSecureStorage _secureStorage;

  AccountabilityContactService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Retrieves configured accountability contacts with fallback to clinical defaults if empty.
  Future<List<AccountabilityContact>> getContacts() async {
    try {
      final String? jsonStr = await _secureStorage.read(key: _storageKey);
      if (jsonStr == null || jsonStr.trim().isEmpty) {
        return _defaultContacts;
      }
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((dynamic item) => AccountabilityContact.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultContacts;
    }
  }

  Future<void> saveContacts(List<AccountabilityContact> contacts) async {
    final String jsonStr = jsonEncode(contacts.map((AccountabilityContact c) => c.toJson()).toList());
    await _secureStorage.write(key: _storageKey, value: jsonStr);
  }

  Future<void> addContact(AccountabilityContact contact) async {
    final List<AccountabilityContact> current = await getContacts();
    current.add(contact);
    await saveContacts(current);
  }

  Future<void> removeContact(String id) async {
    final List<AccountabilityContact> current = await getContacts();
    current.removeWhere((AccountabilityContact c) => c.id == id);
    await saveContacts(current);
  }

  static final List<AccountabilityContact> _defaultContacts = <AccountabilityContact>[
    const AccountabilityContact(
      id: 'contact_sp_01',
      name: 'Father Athanasius (Confessor)',
      role: AccountabilityRole.fatherConfessor,
      phoneNumber: '+1-555-019-2834',
      isEmergencyFastDial: true,
      preformattedSosMessage: 'Father, I am experiencing an acute urge and requesting your immediate prayer and counsel.',
    ),
    const AccountabilityContact(
      id: 'contact_rec_02',
      name: 'Michael K. (Recovery Sponsor)',
      role: AccountabilityRole.sponsor,
      phoneNumber: '+1-555-014-9982',
      isEmergencyFastDial: true,
      preformattedSosMessage: 'Hey Michael, I am experiencing a high-risk craving right now. Can we talk for 5 minutes?',
    ),
    const AccountabilityContact(
      id: 'contact_pt_03',
      name: 'David S. (Spiritual Brother)',
      role: AccountabilityRole.trustedFriend,
      phoneNumber: '+1-555-017-4321',
      isEmergencyFastDial: true,
      preformattedSosMessage: 'Brother, acute temptation spike. Please pray with me or pick up.',
    ),
  ];
}
