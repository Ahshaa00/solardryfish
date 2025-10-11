import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_role.dart';

class PermissionService {
  // 🔧 TESTING ONLY: Super admin account with full access to all systems
  // Change email here if needed (password is set during registration)
  static const String superAdminEmail = 'admin@mail.com';
  
  /// Get the current user's role for a specific system
  static Future<UserRole> getUserRole(String systemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return UserRole.viewer;

    try {
      // 🔧 TESTING: Super admin has owner access to all systems
      if (user.email?.toLowerCase() == superAdminEmail) {
        return UserRole.owner;
      }
      
      final systemRef = FirebaseDatabase.instance.ref('hardwareSystems/$systemId');
      
      // Check if user is the owner
      final ownerSnapshot = await systemRef.child('ownerId').get();
      if (ownerSnapshot.value == user.uid) {
        return UserRole.owner;
      }

      // Check if user is in sharedWith list
      final sharedSnapshot = await systemRef.child('sharedWith/${user.uid}/role').get();
      if (sharedSnapshot.exists) {
        final roleString = sharedSnapshot.value as String?;
        if (roleString != null) {
          return UserRoleExtension.fromString(roleString);
        }
      }

      // User has no access
      return UserRole.viewer;
    } catch (e) {
      print('Error getting user role: $e');
      return UserRole.viewer;
    }
  }

  /// Check if user can control the system (toggle lid, heater, etc.)
  static Future<bool> canControl(String systemId) async {
    final role = await getUserRole(systemId);
    return role.canControl;
  }

  /// Check if user can schedule drying sessions
  static Future<bool> canSchedule(String systemId) async {
    final role = await getUserRole(systemId);
    return role.canSchedule;
  }

  /// Check if user can invite other users
  static Future<bool> canInviteUsers(String systemId) async {
    final role = await getUserRole(systemId);
    return role.canInviteUsers;
  }

  /// Check if user can remove other users
  static Future<bool> canRemoveUsers(String systemId) async {
    final role = await getUserRole(systemId);
    return role.canRemoveUsers;
  }

  /// Check if user can change roles of other users
  static Future<bool> canChangeRoles(String systemId) async {
    final role = await getUserRole(systemId);
    return role.canChangeRoles;
  }

  /// Check if user can delete the system
  static Future<bool> canDeleteSystem(String systemId) async {
    final role = await getUserRole(systemId);
    return role.canDeleteSystem;
  }

  /// Check if user has any access to the system
  static Future<bool> hasAccess(String systemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final systemRef = FirebaseDatabase.instance.ref('hardwareSystems/$systemId');
      
      // Check if user is the owner
      final ownerSnapshot = await systemRef.child('ownerId').get();
      if (ownerSnapshot.value == user.uid) {
        return true;
      }

      // Check if user is in sharedWith list
      final sharedSnapshot = await systemRef.child('sharedWith/${user.uid}').get();
      return sharedSnapshot.exists;
    } catch (e) {
      print('Error checking access: $e');
      return false;
    }
  }

  /// Get all users who have access to a system
  static Future<Map<String, Map<String, dynamic>>> getSharedUsers(String systemId) async {
    try {
      final systemRef = FirebaseDatabase.instance.ref('hardwareSystems/$systemId/sharedWith');
      final snapshot = await systemRef.get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return data.map((key, value) => MapEntry(
          key.toString(),
          Map<String, dynamic>.from(value as Map),
        ));
      }
      return {};
    } catch (e) {
      print('Error getting shared users: $e');
      return {};
    }
  }

  /// Share system with another user
  static Future<void> shareSystem({
    required String systemId,
    required String targetUserId,
    required String targetEmail,
    required String targetFirstName,
    required String targetLastName,
    required UserRole role,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw 'Not authenticated';

    // Get current user's profile
    final profileSnapshot = await FirebaseDatabase.instance
        .ref('users/${currentUser.uid}/profile')
        .get();
    final profile = profileSnapshot.value as Map<dynamic, dynamic>?;
    final firstName = profile?['firstName'] ?? '';
    final lastName = profile?['lastName'] ?? '';
    final addedByName = '$firstName $lastName'.trim();

    final systemRef = FirebaseDatabase.instance.ref('hardwareSystems/$systemId');
    
    // Add user to sharedWith list
    await systemRef.child('sharedWith/$targetUserId').set({
      'email': targetEmail,
      'firstName': targetFirstName,
      'lastName': targetLastName,
      'role': role.value,
      'addedAt': ServerValue.timestamp,
      'addedBy': currentUser.uid,
      'addedByName': addedByName.isEmpty ? currentUser.email : addedByName,
    });

    // Add system to user's sharedSystems list
    await FirebaseDatabase.instance
        .ref('users/$targetUserId/sharedSystems/$systemId')
        .set({
      'role': role.value,
      'sharedAt': ServerValue.timestamp,
      'sharedBy': currentUser.uid,
    });
  }

  /// Remove user's access to a system
  static Future<void> removeAccess({
    required String systemId,
    required String targetUserId,
  }) async {
    final systemRef = FirebaseDatabase.instance.ref('hardwareSystems/$systemId');
    
    // Remove from sharedWith list
    await systemRef.child('sharedWith/$targetUserId').remove();

    // Remove from user's sharedSystems list
    await FirebaseDatabase.instance
        .ref('users/$targetUserId/sharedSystems/$systemId')
        .remove();
  }

  /// Change user's role
  static Future<void> changeUserRole({
    required String systemId,
    required String targetUserId,
    required UserRole newRole,
  }) async {
    final systemRef = FirebaseDatabase.instance.ref('hardwareSystems/$systemId');
    
    // Update role in sharedWith list
    await systemRef.child('sharedWith/$targetUserId/role').set(newRole.value);

    // Update role in user's sharedSystems list
    await FirebaseDatabase.instance
        .ref('users/$targetUserId/sharedSystems/$systemId/role')
        .set(newRole.value);
  }
}
