import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationCode {
  final String id;
  final String code;
  final String systemId;
  final String generatedBy;
  final String generatedByEmail;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;
  final String? usedBy;
  final DateTime? usedAt;

  RegistrationCode({
    required this.id,
    required this.code,
    required this.systemId,
    required this.generatedBy,
    required this.generatedByEmail,
    required this.createdAt,
    required this.expiresAt,
    required this.used,
    this.usedBy,
    this.usedAt,
  });

  factory RegistrationCode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RegistrationCode(
      id: doc.id,
      code: data['code'] ?? '',
      systemId: data['systemId'] ?? '',
      generatedBy: data['generatedBy'] ?? '',
      generatedByEmail: data['generatedByEmail'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      used: data['used'] ?? false,
      usedBy: data['usedBy'],
      usedAt: data['usedAt'] != null ? (data['usedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'systemId': systemId,
      'generatedBy': generatedBy,
      'generatedByEmail': generatedByEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'used': used,
      'usedBy': usedBy,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !used && !isExpired;

  String get status {
    if (used) return 'Used';
    if (isExpired) return 'Expired';
    return 'Active';
  }
}
