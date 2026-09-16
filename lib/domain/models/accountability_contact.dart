enum AccountabilityRole {
  sponsor,
  fatherConfessor,
  mentor,
  spouse,
  trustedFriend;

  String get displayName {
    switch (this) {
      case AccountabilityRole.sponsor:
        return 'Recovery Sponsor';
      case AccountabilityRole.fatherConfessor:
        return 'Father Confessor';
      case AccountabilityRole.mentor:
        return 'Spiritual Mentor';
      case AccountabilityRole.spouse:
        return 'Spouse / Partner';
      case AccountabilityRole.trustedFriend:
        return 'Accountability Partner';
    }
  }
}

class AccountabilityContact {
  final String id;
  final String name;
  final AccountabilityRole role;
  final String phoneNumber;
  final String? email;
  final bool isEmergencyFastDial;
  final String? preformattedSosMessage;

  const AccountabilityContact({
    required this.id,
    required this.name,
    required this.role,
    required this.phoneNumber,
    this.email,
    this.isEmergencyFastDial = true,
    this.preformattedSosMessage,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'role': role.name,
        'phone_number': phoneNumber,
        'email': email,
        'is_emergency_fast_dial': isEmergencyFastDial ? 1 : 0,
        'preformatted_sos_message': preformattedSosMessage,
      };

  factory AccountabilityContact.fromJson(Map<String, dynamic> json) {
    return AccountabilityContact(
      id: json['id'] as String,
      name: json['name'] as String,
      role: AccountabilityRole.values.firstWhere(
        (AccountabilityRole r) => r.name == json['role'],
        orElse: () => AccountabilityRole.trustedFriend,
      ),
      phoneNumber: json['phone_number'] as String,
      email: json['email'] as String?,
      isEmergencyFastDial: (json['is_emergency_fast_dial'] as num?)?.toInt() == 1,
      preformattedSosMessage: json['preformatted_sos_message'] as String?,
    );
  }
}
