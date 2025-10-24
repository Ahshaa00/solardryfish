import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../barrel.dart';
import '../services/registration_code_service.dart';

class SystemSelectorPage extends StatefulWidget {
  const SystemSelectorPage({super.key});

  @override
  State<SystemSelectorPage> createState() => _SystemSelectorPageState();
}

class _SystemSelectorPageState extends State<SystemSelectorPage> {
  // 🎬 SCREENSHOT MODE: Set to true to use mock data
  static const bool USE_MOCK_DATA = true;  // ⚠️ Change to false for real data

  final systemIdController = TextEditingController();
  final registrationCodeController = TextEditingController();
  bool useRegistrationCode = false;
  
  // For dropdown
  List<String> ownedSystems = [];
  List<String> sharedSystems = [];
  Map<String, bool> systemOnlineStatus = {}; // Track online status
  String? selectedSystemId;
  bool loadingSystems = true;
  Timer? _refreshTimer;

  void _showErrorDialog(String title, String message, {IconData icon = Icons.error_outline, Color color = Colors.red}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  bool loading = false;

  @override
  void initState() {
    super.initState();
    
    // 🎬 MOCK DATA: Initialize with perfect screenshot data
    if (USE_MOCK_DATA) {
      _initializeMockData();
      return;
    }
    
    _loadUserSystems();
    
    // Auto-refresh every 10 seconds to update online status
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadUserSystems();
      }
    });
  }

  // 🎬 MOCK DATA: Initialize perfect data for screenshots
  void _initializeMockData() {
    setState(() {
      loadingSystems = false;
      
      // Mock owned systems
      ownedSystems = [
        'SDF202509AA',
        'SDF202509AB',
      ];
      
      // Mock shared systems
      sharedSystems = [
        'SDF202509AC',
      ];
      
      // All systems online
      systemOnlineStatus = {
        'SDF202509AA': true,
        'SDF202509AB': true,
        'SDF202509AC': true,
      };
      
      // Pre-select first system
      selectedSystemId = 'SDF202509AA';
    });
    
    print('🎬 MOCK DATA: System Selector initialized with perfect screenshot data');
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    systemIdController.dispose();
    registrationCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserSystems() async {
    setState(() => loadingSystems = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get owned systems
      final ownedSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/ownedSystems')
          .get();
      
      final List<String> owned = [];
      if (ownedSnapshot.exists) {
        final data = ownedSnapshot.value as Map<dynamic, dynamic>;
        owned.addAll(data.keys.map((k) => k.toString()));
      }

      // Get shared systems and online status
      final systemsSnapshot = await FirebaseDatabase.instance
          .ref('hardwareSystems')
          .get();
      
      final List<String> shared = [];
      final Map<String, bool> onlineStatus = {};
      
      if (systemsSnapshot.exists) {
        final systems = systemsSnapshot.value as Map<dynamic, dynamic>;
        for (var entry in systems.entries) {
          final systemId = entry.key.toString();
          final systemData = entry.value as Map<dynamic, dynamic>;
          
          // Get online status with stale detection
          final status = systemData['status'] as Map<dynamic, dynamic>?;
          final isOnline = status?['online'] == true;
          final lastUpdate = status?['lastUpdate'];
          
          // Check if data is stale (no update in last 30 seconds)
          bool isStale = false;
          if (lastUpdate != null) {
            final timestamp = lastUpdate is int ? lastUpdate : int.tryParse(lastUpdate.toString()) ?? 0;
            final now = DateTime.now().millisecondsSinceEpoch;
            final difference = now - timestamp;
            isStale = difference > 60000; // 60 seconds (increased from 30s for stability)
          }
          
          // Mark as offline if stale
          onlineStatus[systemId] = isOnline && !isStale;
          
          // Check if user has shared access
          if (systemData['sharedWith'] != null) {
            final sharedWith = systemData['sharedWith'] as Map<dynamic, dynamic>;
            if (sharedWith.containsKey(user.uid)) {
              shared.add(systemId);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          ownedSystems = owned;
          sharedSystems = shared;
          systemOnlineStatus = onlineStatus;
          loadingSystems = false;
          
          // Auto-select if only one system
          if (owned.length == 1 && shared.isEmpty) {
            selectedSystemId = owned.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading systems: $e');
      if (mounted) {
        setState(() => loadingSystems = false);
      }
    }
  }

  bool isValidFormat(String id) {
    final pattern = RegExp(r'^SDF\d{6}[A-Z0-9]{2,4}$');
    return pattern.hasMatch(id);
  }

  Future<void> _handleRegistrationCode() async {
    final codeInput = registrationCodeController.text.trim();

    if (codeInput.isEmpty) {
      _showErrorDialog(
        'Code Required',
        'Please enter your registration code.',
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
      );
      return;
    }

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2235),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Validating Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Claiming system ownership...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      final systemId = await RegistrationCodeService.claimSystemWithCode(codeInput);
      
      if (mounted) Navigator.pop(context); // Close loading dialog

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System $systemId claimed successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Log system access
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance.ref('userAccess/${user.uid}').set({
          'systemId': systemId,
          'lastAccess': ServerValue.timestamp,
        });
        
        try {
          await FirebaseFirestore.instance.collection('activity_logs').add({
            'timestamp': FieldValue.serverTimestamp(),
            'user': user.email ?? 'Unknown User',
            'systemId': systemId,
            'message': 'System claimed via registration code',
            'action': 'system_claimed',
          });
        } catch (e) {
          debugPrint('Failed to log system claim: $e');
        }
      }

      // Navigate to dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(systemId: systemId)),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showErrorDialog(
        'Invalid Code',
        e.toString(),
        icon: Icons.error_outline,
        color: Colors.red,
      );
    }
  }

  Future<void> proceedToDashboard() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showErrorDialog(
        'Authentication Required',
        'Please log in first to access hardware systems.',
        icon: Icons.login,
        color: Colors.orange,
      );
      return;
    }

    // Handle registration code flow
    if (useRegistrationCode) {
      await _handleRegistrationCode();
      return;
    }

    // Handle dropdown selection
    if (selectedSystemId != null && selectedSystemId!.isNotEmpty) {
      // Use selected system from dropdown
      await _proceedWithSystemId(selectedSystemId!);
      return;
    }

    // Handle manual system ID input
    final rawInput = systemIdController.text.trim().toUpperCase();

    if (rawInput.isEmpty) {
      _showErrorDialog(
        'System Required',
        'Please select a system from the dropdown or enter a system ID.',
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
      );
      return;
    }

    if (!isValidFormat(rawInput)) {
      _showErrorDialog(
        'Invalid Format',
        'System ID must follow the format: SDF-YYMMDD-XX\n\nExample: SDF202509XZ',
        icon: Icons.error_outline,
        color: Colors.red,
      );
      return;
    }

    await _proceedWithSystemId(rawInput);
  }

  Future<void> _proceedWithSystemId(String rawInput) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildLoadingDialog(),
      );
    }

    try {
      final systemRef = FirebaseDatabase.instance.ref(
        'hardwareSystems/$rawInput',
      );
      final snapshot = await systemRef.get();

      if (!snapshot.exists) {
        if (mounted) Navigator.pop(context); // Close loading dialog
        _showErrorDialog(
          'System Not Found',
          'The system ID "$rawInput" was not found in the database.\n\nPlease check your hardware or contact support.',
          icon: Icons.search_off,
          color: Colors.red,
        );
        return;
      }

      // 🔒 SECURITY: Check system ownership
      final ownerSnapshot = await systemRef.child('ownerId').get();
      final systemOwnerId = ownerSnapshot.value as String?;

      // 🔧 TESTING: Super admin can access any system
      final isSuperAdmin = user.email?.toLowerCase() == PermissionService.superAdminEmail;

      // If system has no owner, allow first user to claim it
      if (systemOwnerId == null || systemOwnerId.isEmpty) {
        // Get user profile to store owner name
        final profileSnapshot = await FirebaseDatabase.instance
            .ref('users/${user.uid}/profile')
            .get();
        final profile = profileSnapshot.value as Map<dynamic, dynamic>?;
        final firstName = profile?['firstName'] ?? '';
        final lastName = profile?['lastName'] ?? '';
        final ownerName = '$firstName $lastName'.trim();
        
        // First-time setup: claim ownership
        await systemRef.update({
          'ownerId': user.uid,
          'ownerEmail': user.email,
          'ownerName': ownerName.isEmpty ? user.email : ownerName,
          'claimedAt': ServerValue.timestamp,
        });
        
        // Add to user's owned systems
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/ownedSystems/$rawInput')
            .set(true);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("System claimed successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (systemOwnerId != user.uid && !isSuperAdmin) {
        // 🚨 UNAUTHORIZED ACCESS ATTEMPT
        if (mounted) Navigator.pop(context);
        
        // Log unauthorized access attempt
        try {
          await FirebaseFirestore.instance.collection('security_logs').add({
            'type': 'unauthorized_access_attempt',
            'userId': user.uid,
            'userEmail': user.email,
            'systemId': rawInput,
            'systemOwner': systemOwnerId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Failed to log security event: $e');
        }
        
        _showErrorDialog(
          'Access Denied',
          'You don\'t have permission to access this system.\n\nThis system belongs to another user. Contact the owner to request access.',
          icon: Icons.block,
          color: Colors.red,
        );
        return;
      } else if (isSuperAdmin && systemOwnerId != user.uid) {
        // 🔧 TESTING: Super admin accessing system
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🔧 Super Admin Access Granted"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // Check if system is online with timeout
      final statusSnapshot = await systemRef.child('status/online').get();
      final lastUpdateSnapshot = await systemRef.child('status/lastUpdate').get();
      
      final isOnline = statusSnapshot.value == true;
      final lastUpdate = lastUpdateSnapshot.value;
      
      // Check if last update was recent (within 30 seconds)
      bool isActuallyOnline = isOnline;
      if (isOnline && lastUpdate != null) {
        final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate as int);
        final timeSinceUpdate = DateTime.now().difference(lastUpdateTime);
        if (timeSinceUpdate.inSeconds > 30) {
          isActuallyOnline = false;
        }
      }

      // Update offline status in database if system is offline
      if (!isActuallyOnline) {
        await systemRef.child('status').update({
          'online': false,
          'lastChecked': ServerValue.timestamp,
          'checkedBy': 'app',
        });
        
        // Log offline detection (optional - won't fail if permissions denied)
        try {
          await FirebaseFirestore.instance.collection('system_status_logs').add({
            'systemId': rawInput,
            'status': 'offline',
            'detectedBy': 'app',
            'timestamp': FieldValue.serverTimestamp(),
            'checkedBy': FirebaseAuth.instance.currentUser?.email ?? 'unknown',
          });
        } catch (e) {
          // Ignore Firestore permission errors - logging is optional
          debugPrint('Firestore logging failed (optional): $e');
        }
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (!isActuallyOnline) {
        // Show offline warning dialog
        final shouldProceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildOfflineWarningDialog(lastUpdate),
        );

        if (shouldProceed != true) {
          return;
        }
      }

      // Log system access (user already declared at the beginning)
      if (user != null) {
        // Save to user access record
        await FirebaseDatabase.instance.ref('userAccess/${user.uid}').set({
          'systemId': rawInput,
          'lastAccess': ServerValue.timestamp,
        });
        
        // Log to activity log
        try {
          await FirebaseFirestore.instance.collection('activity_logs').add({
            'timestamp': FieldValue.serverTimestamp(),
            'user': user.email ?? 'Unknown User',
            'systemId': rawInput,
            'message': 'User accessed the system',
            'action': 'system_access',
          });
        } catch (e) {
          debugPrint('Failed to log system access: $e');
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(systemId: rawInput)),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showErrorDialog(
        'Error',
        'Failed to load system: $e',
        icon: Icons.error,
        color: Colors.red,
      );
    }
  }

  Widget _buildLoadingDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated loading indicator
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Checking System Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Text(
              'Scanning hardware connection...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineWarningDialog(dynamic lastUpdate) {
    String lastSeenText = 'Never';
    if (lastUpdate != null) {
      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate as int);
      final timeSinceUpdate = DateTime.now().difference(lastUpdateTime);
      
      if (timeSinceUpdate.inMinutes < 1) {
        lastSeenText = '${timeSinceUpdate.inSeconds} seconds ago';
      } else if (timeSinceUpdate.inHours < 1) {
        lastSeenText = '${timeSinceUpdate.inMinutes} minutes ago';
      } else if (timeSinceUpdate.inDays < 1) {
        lastSeenText = '${timeSinceUpdate.inHours} hours ago';
      } else {
        lastSeenText = '${timeSinceUpdate.inDays} days ago';
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            const Text(
              'System Offline',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Message
            Text(
              'The hardware system is currently offline or not connected to the network.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            
            // Last seen info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Last seen: $lastSeenText',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You can still view the dashboard, but controls may not work until the system comes online.',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade400,
                      side: BorderSide(color: Colors.grey.shade700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Proceed Anyway',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMySystemsSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('hardwareSystems')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const SizedBox.shrink();
        }

        final systems = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.devices, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'My Systems',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                      '${systems.length}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...systems.entries.map((entry) {
              final systemId = entry.key as String;
              final systemData = entry.value as Map<dynamic, dynamic>;
              final isOnline = systemData['status']?['online'] == true;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2235),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOnline ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: ListTile(
                  leading: Container(
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
                  title: Text(
                    systemId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  subtitle: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 16),
                  onTap: () {
                    systemIdController.text = systemId;
                    proceedToDashboard();
                  },
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141829),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2235),
        elevation: 0,
        title: const Text(
          'SolarDryFish',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _loadUserSystems,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.amber),
            onPressed: logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
              
              // Title
              const Text(
                "Select Your System",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              
              const SizedBox(height: 32),
              
              // Toggle between System ID and Registration Code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => useRegistrationCode = false),
                    icon: Icon(
                      Icons.tag,
                      color: !useRegistrationCode ? Colors.amber : Colors.grey,
                    ),
                    label: Text(
                      'System ID',
                      style: TextStyle(
                        color: !useRegistrationCode ? Colors.amber : Colors.grey,
                        fontWeight: !useRegistrationCode ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => useRegistrationCode = true),
                    icon: Icon(
                      Icons.qr_code,
                      color: useRegistrationCode ? Colors.amber : Colors.grey,
                    ),
                    label: Text(
                      'Registration Code',
                      style: TextStyle(
                        color: useRegistrationCode ? Colors.amber : Colors.grey,
                        fontWeight: useRegistrationCode ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Input Container
              Container(
                constraints: const BoxConstraints(minHeight: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2235),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            useRegistrationCode ? Icons.qr_code : Icons.qr_code_scanner,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          useRegistrationCode ? "Registration Code" : "System ID",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (useRegistrationCode)
                      TextField(
                        controller: registrationCodeController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          hintText: "ABC-123-XYZ",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade600,
                            letterSpacing: 2,
                          ),
                          prefixIcon: const Icon(Icons.vpn_key, color: Colors.amber),
                          filled: true,
                          fillColor: const Color(0xFF141829),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade800),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.amber, width: 2),
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dropdown for owned/shared systems
                          if (loadingSystems)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(color: Colors.amber),
                              ),
                            )
                          else if (ownedSystems.isNotEmpty || sharedSystems.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Systems',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF141829),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade800),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    value: selectedSystemId,
                                    dropdownColor: const Color(0xFF1E2235),
                                    menuMaxHeight: 400, // Limit dropdown height
                                    decoration: InputDecoration(
                                      hintText: 'Select a system',
                                      hintStyle: TextStyle(color: Colors.grey.shade600),
                                      prefixIcon: const Icon(Icons.devices, color: Colors.amber),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    isExpanded: true,
                                    items: [
                                      if (ownedSystems.isNotEmpty)
                                        const DropdownMenuItem<String>(
                                          enabled: false,
                                          value: null,
                                          child: Text(
                                            '── Owned Systems ──',
                                            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ...ownedSystems.map((systemId) {
                                        final isOnline = systemOnlineStatus[systemId] ?? false;
                                        return DropdownMenuItem<String>(
                                          value: systemId,
                                          child: Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 16),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(systemId, style: const TextStyle(color: Colors.white)),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        color: isOnline ? Colors.green : Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isOnline ? 'Online' : 'Offline',
                                                      style: TextStyle(
                                                        color: isOnline ? Colors.green : Colors.red,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      if (sharedSystems.isNotEmpty) ...[
                                        const DropdownMenuItem<String>(
                                          enabled: false,
                                          value: null,
                                          child: Text(
                                            '── Shared Systems ──',
                                            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        ...sharedSystems.map((systemId) {
                                          final isOnline = systemOnlineStatus[systemId] ?? false;
                                          return DropdownMenuItem<String>(
                                            value: systemId,
                                            child: Row(
                                              children: [
                                                const Icon(Icons.people, color: Colors.blue, size: 16),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(systemId, style: const TextStyle(color: Colors.white)),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          color: isOnline ? Colors.green : Colors.red,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        isOnline ? 'Online' : 'Offline',
                                                        style: TextStyle(
                                                          color: isOnline ? Colors.green : Colors.red,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ],
                                    onChanged: (value) {
                                      setState(() => selectedSystemId = value);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Center(
                                  child: Text(
                                    'OR',
                                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          // Manual input field
                          TextField(
                            controller: systemIdController,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: "SDF202509XZ",
                              hintStyle: TextStyle(
                                color: Colors.grey.shade600,
                                letterSpacing: 1.5,
                              ),
                              prefixIcon: const Icon(Icons.tag, color: Colors.amber),
                              filled: true,
                              fillColor: const Color(0xFF141829),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade800),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.amber, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            useRegistrationCode
                                ? "Enter the 9-character code provided by the system owner"
                                : "Format: SDFYYYYMMXX (e.g., SDF202509XZ)",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: loading ? null : proceedToDashboard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey.shade800,
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Continue to Dashboard",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // User Info - Fixed at bottom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2235),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade800, width: 1),
                ),
              ),
              child: FutureBuilder<User?>(
                future: Future.value(FirebaseAuth.instance.currentUser),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Logged in as",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                snapshot.data!.email ?? "User",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
