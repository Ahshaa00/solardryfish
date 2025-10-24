import 'dart:async';
import '../barrel.dart';

class HomePage extends StatefulWidget {
  final String systemId;
  const HomePage({required this.systemId, super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<String> _screenTitles = ['Dashboard', 'Schedule', 'Activity Log'];
  final ConnectionMonitorService _connectionMonitor = ConnectionMonitorService();
  bool _dialogShown = false;
  
  // Stale data detection
  int _lastUpdateTimestamp = 0;
  bool _isOnline = false;
  bool _firebaseOnlineStatus = false;  // Track Firebase's reported status separately
  Timer? _freshnessTimer;
  
  // Cache streams to prevent "already listened to" error
  late final Stream<DatabaseEvent> _userProfileStream;
  late final Stream<DatabaseEvent> _systemOnlineStream;
  late final Stream<DatabaseEvent> _lastUpdateStream;

  @override
  void initState() {
    super.initState();
    _connectionMonitor.startMonitoring();
    _connectionMonitor.addListener(_onConnectionChanged);
    
    // Initialize broadcast streams once
    _userProfileStream = FirebaseDatabase.instance
        .ref('users/${FirebaseAuth.instance.currentUser?.uid}/profile')
        .onValue
        .asBroadcastStream();
    
    _systemOnlineStream = FirebaseDatabase.instance
        .ref('hardwareSystems/${widget.systemId}/status/online')
        .onValue
        .asBroadcastStream();
    
    _lastUpdateStream = FirebaseDatabase.instance
        .ref('hardwareSystems/${widget.systemId}/status/lastUpdate')
        .onValue
        .asBroadcastStream();
    
    // Listen to lastUpdate for stale detection
    _lastUpdateStream.listen((event) {
      final timestamp = event.snapshot.value;
      if (timestamp != null && mounted) {
        setState(() {
          _lastUpdateTimestamp = timestamp is int ? timestamp : int.tryParse(timestamp.toString()) ?? 0;
          // Update online status when timestamp changes
          _updateOnlineStatus();
        });
      }
    });
    
    // Listen to online status from Firebase
    _systemOnlineStream.listen((event) {
      if (mounted) {
        final firebaseOnline = event.snapshot.value == true;
        setState(() {
          _firebaseOnlineStatus = firebaseOnline;
          // Update _isOnline based on Firebase status and data freshness
          _updateOnlineStatus();
        });
      }
    });
    
    // Check data freshness every 3 seconds
    _freshnessTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkDataFreshness();
    });
  }
  
  void _checkDataFreshness() {
    if (mounted) {
      setState(() {
        _updateOnlineStatus();
      });
    }
  }
  
  void _updateOnlineStatus() {
    // Determine online status based on Firebase status AND data freshness
    if (_lastUpdateTimestamp == 0) {
      // No timestamp received yet, use Firebase status
      _isOnline = _firebaseOnlineStatus;
      return;
    }
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = now - _lastUpdateTimestamp;
    
    // Consider data stale if no update in last 60 seconds
    final isDataFresh = difference <= 60000;
    
    // System is online only if Firebase says online AND data is fresh
    _isOnline = _firebaseOnlineStatus && isDataFresh;
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    
    if (!_connectionMonitor.isConnected && !_dialogShown) {
      _dialogShown = true;
      ConnectionMonitorService.showConnectionLostDialog(context).then((_) {
        _dialogShown = false;
      });
    }
  }

  @override
  void dispose() {
    _connectionMonitor.removeListener(_onConnectionChanged);
    _freshnessTimer?.cancel();
    super.dispose();
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(systemId: widget.systemId, key: const ValueKey('dashboard'));
      case 1:
        return ScheduleScreen(systemId: widget.systemId, key: const ValueKey('schedule'));
      case 2:
        return ActivityLogScreen(systemId: widget.systemId, key: const ValueKey('activity'));
      default:
        return DashboardScreen(systemId: widget.systemId, key: const ValueKey('dashboard'));
    }
  }

  void _onDrawerItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close drawer after selection
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141829),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2235),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.amber),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: const Text(
          'SolarDryFish',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Online/Offline indicator with stale detection
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isOnline ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: _isOnline ? Colors.green : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.amber),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications', arguments: widget.systemId);
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _getScreen(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.schedule_rounded,
                  label: 'Schedule',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.history_rounded,
                  label: 'Activity',
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.amber : Colors.grey.shade400,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF141829),
      child: Column(
        children: [
          // Header with gradient and user info
          StreamBuilder<DatabaseEvent>(
            stream: _userProfileStream,
            builder: (context, snapshot) {
              final profile = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
              final firstName = profile?['firstName'] ?? '';
              final lastName = profile?['lastName'] ?? '';
              final userId = profile?['userId'] ?? 'N/A';
              final fullName = '$firstName $lastName'.trim();

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.amber.shade700, Colors.amber, Colors.amber.shade300],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? "User" : fullName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $userId',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.devices, size: 14, color: Colors.black87),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.systemId,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Role Badge
                    FutureBuilder<UserRole>(
                      future: PermissionService.getUserRole(widget.systemId),
                      builder: (context, roleSnapshot) {
                        if (!roleSnapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        
                        final role = roleSnapshot.data!;
                        final roleColor = role == UserRole.owner ? Colors.amber :
                                         role == UserRole.admin ? Colors.blue :
                                         role == UserRole.operator ? Colors.green : Colors.grey;
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: roleColor, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield, size: 12, color: roleColor),
                              const SizedBox(width: 4),
                              Text(
                                role.displayName.toUpperCase(),
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Text(
                    'MENU',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                _buildDrawerItem(
                  icon: Icons.account_circle_outlined,
                  title: 'Account',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/account', arguments: widget.systemId);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.sensors_outlined,
                  title: 'System Monitor',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/monitor', arguments: widget.systemId);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.build_circle_outlined,
                  title: 'Hardware Testing',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/hardware_test', arguments: widget.systemId);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings_outlined,
                  title: 'System Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SystemSettingsPage(systemId: widget.systemId),
                      ),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Divider(color: Colors.grey, thickness: 0.5),
                ),
                _buildDrawerItem(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Switch System',
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E2235),
                        title: const Text(
                          'Switch System?',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'You will be redirected to select a different hardware system.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const SystemSelectorPage()),
                                (route) => false,
                              );
                            },
                            child: const Text('Switch', style: TextStyle(color: Colors.amber)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  isLogout: true,
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.transparent,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isLogout 
                ? Colors.red.withOpacity(0.1) 
                : Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isLogout ? Colors.red : Colors.amber,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isLogout ? Colors.red : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: isLogout ? Colors.red.withOpacity(0.5) : Colors.grey.shade600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
        hoverColor: isLogout 
            ? Colors.red.withOpacity(0.05) 
            : Colors.amber.withOpacity(0.05),
      ),
    );
  }
}
