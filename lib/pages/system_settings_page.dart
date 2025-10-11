import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_role.dart';
import '../models/shared_user.dart';
import '../services/permission_service.dart';
import '../services/registration_code_service.dart';
import '../widgets/user_list_tile.dart';
import '../widgets/permission_badge.dart';
import 'registration_codes_page.dart';

class SystemSettingsPage extends StatefulWidget {
  final String systemId;
  const SystemSettingsPage({super.key, required this.systemId});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  UserRole? currentUserRole;
  String ownerId = '';
  String ownerEmail = '';
  String ownerName = '';
  Map<String, SharedUser> sharedUsers = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => loading = true);
    
    try {
      // Get current user's role
      final role = await PermissionService.getUserRole(widget.systemId);
      
      // Get system owner info
      final systemRef = FirebaseDatabase.instance.ref('hardwareSystems/${widget.systemId}');
      final ownerSnapshot = await systemRef.child('ownerId').get();
      final ownerEmailSnapshot = await systemRef.child('ownerEmail').get();
      final ownerNameSnapshot = await systemRef.child('ownerName').get();
      
      // Get shared users
      final sharedUsersData = await PermissionService.getSharedUsers(widget.systemId);
      final Map<String, SharedUser> users = {};
      
      final currentUser = FirebaseAuth.instance.currentUser;
      final isSuperAdmin = currentUser?.email?.toLowerCase() == PermissionService.superAdminEmail;
      
      for (var entry in sharedUsersData.entries) {
        final userEmail = entry.value['email']?.toString().toLowerCase() ?? '';
        
        // Hide super admin from non-super-admin users
        if (userEmail == PermissionService.superAdminEmail && !isSuperAdmin) {
          continue; // Skip super admin
        }
        
        users[entry.key] = SharedUser.fromMap(entry.key, entry.value);
      }
      
      if (mounted) {
        setState(() {
          currentUserRole = role;
          ownerId = ownerSnapshot.value?.toString() ?? '';
          ownerEmail = ownerEmailSnapshot.value?.toString() ?? '';
          ownerName = ownerNameSnapshot.value?.toString() ?? ownerEmail;
          sharedUsers = users;
          loading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> inviteUser() async {
    if (currentUserRole == null || !currentUserRole!.canInviteUsers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You don\'t have permission to invite users')),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const InviteUserDialog(),
    );

    if (result != null && mounted) {
      try {
        // Search for user by email
        final email = result['email'] as String;
        final role = result['role'] as UserRole;
        
        // Query users by email
        final usersRef = FirebaseDatabase.instance.ref('users');
        final query = usersRef.orderByChild('profile/email').equalTo(email);
        final snapshot = await query.get();
        
        if (!snapshot.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User not found. They need to register first.')),
            );
          }
          return;
        }
        
        // Get user data
        final userData = snapshot.value as Map<dynamic, dynamic>;
        final targetUserId = userData.keys.first.toString();
        final profile = userData[targetUserId]['profile'] as Map<dynamic, dynamic>;
        
        final targetEmail = profile['email'] as String;
        final targetFirstName = profile['firstName'] as String? ?? '';
        final targetLastName = profile['lastName'] as String? ?? '';
        
        // Share system
        await PermissionService.shareSystem(
          systemId: widget.systemId,
          targetUserId: targetUserId,
          targetEmail: targetEmail,
          targetFirstName: targetFirstName,
          targetLastName: targetLastName,
          role: role,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully shared with $targetEmail')),
          );
          loadData(); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error inviting user: $e')),
          );
        }
      }
    }
  }

  Future<void> changeUserRole(String userId, UserRole currentRole) async {
    if (currentUserRole == null || !currentUserRole!.canChangeRoles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You don\'t have permission to change roles')),
      );
      return;
    }

    final newRole = await showDialog<UserRole>(
      context: context,
      builder: (context) => RoleSelectionDialog(currentRole: currentRole),
    );

    if (newRole != null && newRole != currentRole && mounted) {
      try {
        await PermissionService.changeUserRole(
          systemId: widget.systemId,
          targetUserId: userId,
          newRole: newRole,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role updated successfully')),
          );
          loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error changing role: $e')),
          );
        }
      }
    }
  }

  Future<void> _transferOwnership() async {
    final emailController = TextEditingController();
    
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Transfer Ownership', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WARNING: This action will transfer full ownership of this system to another user. You will become an Admin.',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Owner Email',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.email, color: Colors.amber),
                  filled: true,
                  fillColor: const Color(0xFF141829),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an email')),
                );
                return;
              }
              Navigator.pop(context, emailController.text.trim().toLowerCase());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (email != null && mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );

      try {
        await RegistrationCodeService.transferOwnership(
          systemId: widget.systemId,
          newOwnerEmail: email,
        );
        
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ownership transferred successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          loadData();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> removeUser(String userId, String userName) async {
    if (currentUserRole == null || !currentUserRole!.canRemoveUsers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You don\'t have permission to remove users')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        title: const Text('Remove User?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove $userName from this system?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await PermissionService.removeAccess(
          systemId: widget.systemId,
          targetUserId: userId,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User removed successfully')),
          );
          loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing user: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E2235),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (currentUserRole != null)
            Padding(
              padding: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
              child: PermissionBadge(role: currentUserRole!),
            ),
        ],
      ),
      backgroundColor: const Color(0xFF141829),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // System Info Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade700, Colors.amber],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.settings, size: 32, color: Colors.black87),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'System ID',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                widget.systemId,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Registration Codes Button (Owner & Admin only)
                  if (currentUserRole == UserRole.owner || currentUserRole == UserRole.admin)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegistrationCodesPage(systemId: widget.systemId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Manage Registration Codes'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber,
                          side: const BorderSide(color: Colors.amber),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  
                  if (currentUserRole == UserRole.owner || currentUserRole == UserRole.admin)
                    const SizedBox(height: 12),

                  // Transfer Ownership Button (Owner only)
                  if (currentUserRole == UserRole.owner)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _transferOwnership,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Transfer Ownership'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  
                  if (currentUserRole == UserRole.owner)
                    const SizedBox(height: 24),

                  // Users Section
                  Row(
                    children: [
                      const Text(
                        'Users',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${sharedUsers.length + 1}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Owner (Current User if owner)
                  // Hide if owner is super admin and current user is not super admin
                  if (!(ownerEmail.toLowerCase() == PermissionService.superAdminEmail && 
                        currentUser?.email?.toLowerCase() != PermissionService.superAdminEmail))
                    StreamBuilder<DatabaseEvent>(
                      stream: FirebaseDatabase.instance
                          .ref('users/$ownerId/profile')
                          .onValue,
                      builder: (context, snapshot) {
                        final profile = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
                        final firstName = profile?['firstName'] ?? '';
                        final lastName = profile?['lastName'] ?? '';
                        final userId = profile?['userId'] ?? 'N/A';
                        
                        final ownerUser = SharedUser(
                          userId: userId,
                          email: ownerEmail,
                          firstName: firstName,
                          lastName: lastName,
                          role: UserRole.owner,
                          addedAt: DateTime.now(),
                          addedBy: ownerId,
                          addedByName: 'System',
                        );

                        return UserListTile(
                          user: ownerUser,
                          isCurrentUser: currentUser?.uid == ownerId,
                          canManage: false, // Can't manage owner
                        );
                      },
                    ),

                  // Shared Users
                  ...sharedUsers.entries.map((entry) {
                    final user = entry.value;
                    final isCurrentUser = currentUser?.uid == entry.key;
                    final canManage = currentUserRole != null && 
                                     currentUserRole!.canRemoveUsers && 
                                     !isCurrentUser;

                    return UserListTile(
                      user: user,
                      isCurrentUser: isCurrentUser,
                      canManage: canManage,
                      onChangeRole: canManage && currentUserRole!.canChangeRoles
                          ? () => changeUserRole(entry.key, user.role)
                          : null,
                      onRemove: canManage
                          ? () => removeUser(entry.key, user.displayName)
                          : null,
                    );
                  }).toList(),

                  const SizedBox(height: 16),

                  // Invite Button
                  if (currentUserRole != null && currentUserRole!.canInviteUsers)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: inviteUser,
                        icon: const Icon(Icons.person_add),
                        label: const Text(
                          'Invite User',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// Invite User Dialog
class InviteUserDialog extends StatefulWidget {
  const InviteUserDialog({super.key});

  @override
  State<InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<InviteUserDialog> {
  final emailController = TextEditingController();
  UserRole selectedRole = UserRole.operator;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2235),
      title: const Text('Invite User', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.email, color: Colors.amber),
              filled: true,
              fillColor: const Color(0xFF141829),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Select Role:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...UserRole.values.where((r) => r != UserRole.owner).map((role) {
            return RadioListTile<UserRole>(
              value: role,
              groupValue: selectedRole,
              onChanged: (value) => setState(() => selectedRole = value!),
              title: Text(role.displayName, style: const TextStyle(color: Colors.white)),
              subtitle: Text(role.description, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              activeColor: Colors.amber,
            );
          }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            if (emailController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter an email')),
              );
              return;
            }
            Navigator.pop(context, {
              'email': emailController.text.trim().toLowerCase(),
              'role': selectedRole,
            });
          },
          child: const Text('Invite', style: TextStyle(color: Colors.amber)),
        ),
      ],
    );
  }
}

// Role Selection Dialog
class RoleSelectionDialog extends StatefulWidget {
  final UserRole currentRole;
  const RoleSelectionDialog({super.key, required this.currentRole});

  @override
  State<RoleSelectionDialog> createState() => _RoleSelectionDialogState();
}

class _RoleSelectionDialogState extends State<RoleSelectionDialog> {
  late UserRole selectedRole;

  @override
  void initState() {
    super.initState();
    selectedRole = widget.currentRole;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2235),
      title: const Text('Change Role', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserRole.values.where((r) => r != UserRole.owner).map((role) {
          return RadioListTile<UserRole>(
            value: role,
            groupValue: selectedRole,
            onChanged: (value) => setState(() => selectedRole = value!),
            title: Text(role.displayName, style: const TextStyle(color: Colors.white)),
            subtitle: Text(role.description, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            activeColor: Colors.amber,
          );
        }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, selectedRole),
          child: const Text('Update', style: TextStyle(color: Colors.amber)),
        ),
      ],
    );
  }
}
