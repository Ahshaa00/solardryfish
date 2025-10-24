import '../barrel.dart';

class AccountPage extends StatelessWidget {
  final String systemId;
  const AccountPage({super.key, required this.systemId});

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) return "***@$domain";
    return "${name[0]}***${name[name.length - 1]}@$domain";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "No email";

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Account"),
          backgroundColor: const Color(0xFF1E2235),
        ),
        body: const Center(
          child: Text("Please log in"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Account",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E2235),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFF141829),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header with User Data
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('users/${user.uid}/profile')
                  .onValue,
              builder: (context, snapshot) {
                final profile = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
                final firstName = profile?['firstName'] ?? '';
                final lastName = profile?['lastName'] ?? '';
                final userId = profile?['userId'] ?? 'N/A';
                final fullName = '$firstName $lastName'.trim();

                return Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.amber.shade700, Colors.amber],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        fullName.isEmpty ? "User" : fullName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withOpacity(0.5)),
                        ),
                        child: Text(
                          'ID: $userId',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),

            // My Hardware Systems Section
            _buildMySystemsSection(user.uid),
            const SizedBox(height: 16),

            // Shared With Me Section
            _buildSharedSystemsSection(user.uid),
            const SizedBox(height: 16),

            // System ID Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.device_hub,
                          color: Colors.amber,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "System ID",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141829),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tag, color: Colors.amber, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            systemId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Email Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.email,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Email Address",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141829),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alternate_email, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            email,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Reset Password Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/reset_pass');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_reset, size: 24),
                    SizedBox(width: 12),
                    Text(
                      "Change Password",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Your account is linked to this system. Contact support for account changes.",
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMySystemsSection(String userId) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('users/$userId/ownedSystems')
          .onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const SizedBox.shrink();
        }

        final ownedSystems = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.devices,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "My Hardware Systems",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${ownedSystems.length}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...ownedSystems.keys.map((systemId) {
                return FutureBuilder<DatabaseEvent>(
                  future: FirebaseDatabase.instance
                      .ref('hardwareSystems/$systemId/status')
                      .once(),
                  builder: (context, statusSnapshot) {
                    final status = statusSnapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
                    final isOnline = status?['online'] == true;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141829),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOnline ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isOnline ? Colors.green : Colors.grey).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.router,
                              color: isOnline ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  systemId.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'OWNER',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isOnline ? 'Online' : 'Offline',
                                      style: TextStyle(
                                        color: isOnline ? Colors.green : Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _showDeleteSystemDialog(context, systemId.toString(), userId),
                            tooltip: 'Remove System',
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/system_selector');
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add New System'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSharedSystemsSection(String userId) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('users/$userId/sharedSystems')
          .onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const SizedBox.shrink();
        }

        final sharedSystems = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.people,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Shared With Me",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${sharedSystems.length}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...sharedSystems.entries.map((entry) {
                final systemId = entry.key.toString();
                final systemData = entry.value as Map<dynamic, dynamic>;
                final role = systemData['role'] as String? ?? 'viewer';
                
                return FutureBuilder<List<DatabaseEvent>>(
                  future: Future.wait([
                    FirebaseDatabase.instance.ref('hardwareSystems/$systemId/status').once(),
                    FirebaseDatabase.instance.ref('hardwareSystems/$systemId/ownerName').once(),
                  ]),
                  builder: (context, futureSnapshot) {
                    if (!futureSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    
                    final status = futureSnapshot.data![0].snapshot.value as Map<dynamic, dynamic>?;
                    final ownerName = futureSnapshot.data![1].snapshot.value as String? ?? 'Unknown';
                    final isOnline = status?['online'] == true;
                    
                    final roleColor = role == 'admin' ? Colors.blue : 
                                     role == 'operator' ? Colors.green : Colors.grey;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141829),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOnline ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isOnline ? Colors.blue : Colors.grey).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.router,
                              color: isOnline ? Colors.blue : Colors.grey,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  systemId,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: roleColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        role.toUpperCase(),
                                        style: TextStyle(
                                          color: roleColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isOnline ? 'Online' : 'Offline',
                                      style: TextStyle(
                                        color: isOnline ? Colors.blue : Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Owner: $ownerName',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // Show delete system dialog with password verification
  static void _showDeleteSystemDialog(BuildContext context, String systemId, String userId) {
    final passwordController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2235),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning, color: Colors.red, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Remove System',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to remove system "$systemId"?',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Text(
                  '⚠️ This will remove the system from your account. You can re-add it later using a registration code.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Enter your password to confirm',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.lock, color: Colors.amber),
                  filled: true,
                  fillColor: const Color(0xFF141829),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () {
                passwordController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isDeleting ? null : () async {
                if (passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your password'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() => isDeleting = true);

                try {
                  // Verify password by re-authenticating
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null || user.email == null) {
                    throw Exception('User not logged in');
                  }

                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passwordController.text,
                  );

                  await user.reauthenticateWithCredential(credential);

                  // Password verified, proceed with deletion
                  await _deleteSystem(systemId, userId);

                  passwordController.dispose();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('System "$systemId" removed successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  setState(() => isDeleting = false);
                  String errorMessage = 'Authentication failed';
                  if (e.code == 'wrong-password') {
                    errorMessage = 'Incorrect password';
                  } else if (e.code == 'too-many-requests') {
                    errorMessage = 'Too many attempts. Try again later';
                  }
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  setState(() => isDeleting = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Remove System'),
            ),
          ],
        ),
      ),
    );
  }

  // Delete system from user's account
  static Future<void> _deleteSystem(String systemId, String userId) async {
    final dbRef = FirebaseDatabase.instance.ref();
    
    // Remove from user's owned systems
    await dbRef.child('users/$userId/ownedSystems/$systemId').remove();
    
    // Remove system ownership from hardwareSystems
    await dbRef.child('hardwareSystems/$systemId/ownerId').remove();
    await dbRef.child('hardwareSystems/$systemId/ownerEmail').remove();
    await dbRef.child('hardwareSystems/$systemId/ownerName').remove();
    
    // Log the action
    await FirebaseFirestore.instance.collection('activity_logs').add({
      'systemId': systemId,
      'user': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
      'message': 'System removed from account',
      'timestamp': Timestamp.now(),
    });
  }
}
