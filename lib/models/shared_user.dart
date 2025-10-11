import 'user_role.dart';

class SharedUser {
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final DateTime addedAt;
  final String addedBy;
  final String addedByName;

  SharedUser({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.addedAt,
    required this.addedBy,
    required this.addedByName,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get displayName => fullName.isEmpty ? email : fullName;

  factory SharedUser.fromMap(String userId, Map<dynamic, dynamic> map) {
    return SharedUser(
      userId: userId,
      email: map['email'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      role: UserRoleExtension.fromString(map['role'] as String? ?? 'viewer'),
      addedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['addedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      addedBy: map['addedBy'] as String? ?? '',
      addedByName: map['addedByName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role.value,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'addedBy': addedBy,
      'addedByName': addedByName,
    };
  }
}
