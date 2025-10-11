import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/registration_code.dart';
import '../models/user_role.dart';
import 'permission_service.dart';

class RegistrationCodeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Generate a random 9-character alphanumeric code
  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed confusing chars: I, O, 0, 1
    final random = Random.secure();
    return List.generate(9, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Format code with dashes for readability: ABC-123-XYZ
  static String formatCode(String code) {
    if (code.length != 9) return code;
    return '${code.substring(0, 3)}-${code.substring(3, 6)}-${code.substring(6, 9)}';
  }

  /// Remove dashes from formatted code
  static String unformatCode(String code) {
    return code.replaceAll('-', '').toUpperCase();
  }

  /// Generate a new registration code for a system
  static Future<RegistrationCode> generateCode({
    required String systemId,
    int expirationDays = 7,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw 'Not authenticated';

    // Check if user has permission (Owner or Admin)
    final role = await PermissionService.getUserRole(systemId);
    if (role != UserRole.owner && role != UserRole.admin) {
      throw 'Only Owner and Admin can generate registration codes';
    }

    // Get user profile for audit trail
    final profileSnapshot = await _database.ref('users/${user.uid}/profile').get();
    final profile = profileSnapshot.value as Map<dynamic, dynamic>?;
    final email = user.email ?? 'unknown';

    // Generate unique code
    String code;
    bool isUnique = false;
    int attempts = 0;
    
    do {
      code = _generateCode();
      final existing = await _firestore
          .collection('registrationCodes')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      isUnique = existing.docs.isEmpty;
      attempts++;
      if (attempts > 10) throw 'Failed to generate unique code';
    } while (!isUnique);

    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: expirationDays));

    final codeData = RegistrationCode(
      id: '', // Will be set by Firestore
      code: code,
      systemId: systemId,
      generatedBy: user.uid,
      generatedByEmail: email,
      createdAt: now,
      expiresAt: expiresAt,
      used: false,
    );

    final docRef = await _firestore.collection('registrationCodes').add(codeData.toMap());
    
    return RegistrationCode(
      id: docRef.id,
      code: code,
      systemId: systemId,
      generatedBy: user.uid,
      generatedByEmail: email,
      createdAt: now,
      expiresAt: expiresAt,
      used: false,
    );
  }

  /// Validate and use a registration code to claim system ownership
  static Future<String> claimSystemWithCode(String codeInput) async {
    final user = _auth.currentUser;
    if (user == null) throw 'Not authenticated';

    final code = unformatCode(codeInput);

    // Find the code
    final querySnapshot = await _firestore
        .collection('registrationCodes')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw 'Invalid registration code';
    }

    final codeDoc = querySnapshot.docs.first;
    final registrationCode = RegistrationCode.fromFirestore(codeDoc);

    // Validate code
    if (registrationCode.used) {
      throw 'This code has already been used';
    }

    if (registrationCode.isExpired) {
      throw 'This code has expired';
    }

    final systemId = registrationCode.systemId;

    // Check if system exists
    final systemRef = _database.ref('hardwareSystems/$systemId');
    final systemSnapshot = await systemRef.get();
    
    if (!systemSnapshot.exists) {
      throw 'System not found. Please contact support.';
    }

    // Check if system already has an owner
    final ownerSnapshot = await systemRef.child('ownerId').get();
    if (ownerSnapshot.exists && ownerSnapshot.value != null) {
      throw 'This system already has an owner';
    }

    // Claim ownership
    await systemRef.update({
      'ownerId': user.uid,
      'ownerEmail': user.email,
      'claimedAt': ServerValue.timestamp,
      'claimedViaCode': code,
    });

    // Mark code as used
    await codeDoc.reference.update({
      'used': true,
      'usedBy': user.uid,
      'usedAt': FieldValue.serverTimestamp(),
    });

    // Add to user's systems
    await _database.ref('users/${user.uid}/systems/$systemId').set({
      'role': 'owner',
      'addedAt': ServerValue.timestamp,
    });

    return systemId;
  }

  /// Get all codes for a system
  static Future<List<RegistrationCode>> getCodesForSystem(String systemId) async {
    final querySnapshot = await _firestore
        .collection('registrationCodes')
        .where('systemId', isEqualTo: systemId)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs.map((doc) => RegistrationCode.fromFirestore(doc)).toList();
  }

  /// Delete a registration code
  static Future<void> deleteCode(String codeId, String systemId) async {
    final user = _auth.currentUser;
    if (user == null) throw 'Not authenticated';

    // Check permission
    final role = await PermissionService.getUserRole(systemId);
    if (role != UserRole.owner && role != UserRole.admin) {
      throw 'Only Owner and Admin can delete registration codes';
    }

    await _firestore.collection('registrationCodes').doc(codeId).delete();
  }

  /// Transfer ownership to another user
  static Future<void> transferOwnership({
    required String systemId,
    required String newOwnerEmail,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Not authenticated';

    // Check if current user is owner
    final role = await PermissionService.getUserRole(systemId);
    if (role != UserRole.owner) {
      throw 'Only the owner can transfer ownership';
    }

    // Find new owner by email
    final usersSnapshot = await _database
        .ref('users')
        .orderByChild('profile/email')
        .equalTo(newOwnerEmail)
        .limitToFirst(1)
        .get();

    if (!usersSnapshot.exists) {
      throw 'User not found with email: $newOwnerEmail';
    }

    final newOwnerData = usersSnapshot.value as Map<dynamic, dynamic>;
    final newOwnerId = newOwnerData.keys.first.toString();

    if (newOwnerId == currentUser.uid) {
      throw 'You are already the owner';
    }

    final systemRef = _database.ref('hardwareSystems/$systemId');

    // Get current owner info for history
    final currentOwnerSnapshot = await systemRef.child('ownerId').get();
    final currentOwnerId = currentOwnerSnapshot.value?.toString();

    // Update ownership
    await systemRef.update({
      'ownerId': newOwnerId,
      'ownerEmail': newOwnerEmail,
      'transferredAt': ServerValue.timestamp,
      'transferredFrom': currentOwnerId,
    });

    // Add to transfer history
    await systemRef.child('transferHistory').push().set({
      'fromUserId': currentOwnerId,
      'fromEmail': currentUser.email,
      'toUserId': newOwnerId,
      'toEmail': newOwnerEmail,
      'timestamp': ServerValue.timestamp,
    });

    // Update old owner to admin role in sharedWith
    if (currentOwnerId != null) {
      await systemRef.child('sharedWith/$currentOwnerId').set({
        'email': currentUser.email,
        'role': 'admin',
        'addedAt': ServerValue.timestamp,
        'note': 'Former owner',
      });

      // Update in user's systems
      await _database.ref('users/$currentOwnerId/systems/$systemId').update({
        'role': 'admin',
      });
    }

    // Remove new owner from sharedWith if they were there
    await systemRef.child('sharedWith/$newOwnerId').remove();

    // Add to new owner's systems
    await _database.ref('users/$newOwnerId/systems/$systemId').set({
      'role': 'owner',
      'addedAt': ServerValue.timestamp,
    });
  }
}
