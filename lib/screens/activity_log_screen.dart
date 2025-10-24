import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../barrel.dart' hide Query, Transaction, TransactionHandler;
import '../models/user_role.dart';
import '../services/permission_service.dart';

class ActivityLogScreen extends StatefulWidget {
  final String systemId;
  const ActivityLogScreen({required this.systemId, super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  // 🎬 SCREENSHOT MODE: Set to true to use mock data
  static const bool USE_MOCK_DATA = true;  // ⚠️ Change to false for real data

  final int pageSize = 10;
  final int maxLogs = 150; // Changed from 50 to 150 (between 100-200)
  List<DocumentSnapshot> allLogs = [];
  List<Map<String, dynamic>> mockLogs = []; // For mock data
  int currentPage = 0;
  bool isLoading = true;
  UserRole? userRole;
  List<String> availableUsers = []; // For dropdown

  DateTime? startDate;
  DateTime? endDate;
  String userFilter = '';
  String keywordFilter = '';
  final TextEditingController startDateController = TextEditingController();
  final TextEditingController endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // 🎬 MOCK DATA: Initialize with perfect screenshot data
    if (USE_MOCK_DATA) {
      _initializeMockData();
      return;
    }
    
    _loadUserRole();
    fetchLogs();
  }

  @override
  void dispose() {
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }

  // 🎬 MOCK DATA: Initialize perfect data for screenshots
  void _initializeMockData() {
    final now = DateTime.now();
    
    setState(() {
      isLoading = false;
      userRole = UserRole.owner;
      availableUsers = ['owner@solardry.com', 'user@solardry.com'];
      currentPage = 0;
      
      // Create mock activity logs
      mockLogs = [
        {
          'message': 'Schedule started: Phase 1 (2h), Phase 2 (1h)',
          'user': 'owner@solardry.com',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
        },
        {
          'message': 'Lid opened manually',
          'user': 'owner@solardry.com',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 15))),
        },
        {
          'message': 'Manual override enabled',
          'user': 'owner@solardry.com',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(minutes: 20))),
        },
        {
          'message': 'Temperature target set to 35.0°C',
          'user': 'user@solardry.com',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        },
        {
          'message': 'Schedule completed successfully',
          'user': 'owner@solardry.com',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
        },
        {
          'message': 'Lid closed automatically',
          'user': 'System',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
        },
        {
          'message': 'Rain detected - Lid closing',
          'user': 'System',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 4))),
        },
        {
          'message': 'User logged in',
          'user': 'user@solardry.com',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 5))),
        },
        {
          'message': 'System settings updated',
          'user': 'owner@solardry.com',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 6))),
        },
        {
          'message': 'Battery charging started',
          'user': 'System',
          'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 8))),
        },
      ];
    });
    
    print('🎬 MOCK DATA: Activity Log initialized with ${mockLogs.length} mock entries');
  }

  Future<void> _loadUserRole() async {
    final role = await PermissionService.getUserRole(widget.systemId);
    if (mounted) {
      setState(() => userRole = role);
    }
  }

  Future<void> fetchLogs() async {
    setState(() => isLoading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('activity_logs')
          .where('systemId', isEqualTo: widget.systemId);

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!),
        );
      }
      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate!),
        );
      }

      query = query.orderBy('timestamp', descending: true);

      final querySnapshot = await query.get();
      List<DocumentSnapshot> allDocs = querySnapshot.docs;
      
      // Keep only the most recent logs based on maxLogs, delete the rest
      if (allDocs.length > maxLogs) {
        final logsToDelete = allDocs.skip(maxLogs).toList();
        final batch = FirebaseFirestore.instance.batch();
        
        for (var doc in logsToDelete) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        print('Deleted ${logsToDelete.length} old logs');
      }
      
      List<DocumentSnapshot> filtered = allDocs.take(maxLogs).toList();
      
      // Extract unique users for dropdown
      final users = filtered.map((doc) => doc['user']?.toString() ?? '').where((u) => u.isNotEmpty).toSet().toList();
      users.sort();

      if (userFilter.isNotEmpty) {
        filtered = filtered.where((doc) {
          final user = doc['user']?.toString().toLowerCase() ?? '';
          return user.contains(userFilter.toLowerCase());
        }).toList();
      }

      if (keywordFilter.isNotEmpty) {
        filtered = filtered.where((doc) {
          final message = doc['message']?.toString().toLowerCase() ?? '';
          return message.contains(keywordFilter.toLowerCase());
        }).toList();
      }

      if (mounted) {
        setState(() {
          allLogs = filtered;
          availableUsers = users;
          currentPage = 0;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          allLogs = [];
        });
      }
    }
  }

  List<DocumentSnapshot> get paginatedLogs {
    final start = currentPage * pageSize;
    final end = start + pageSize;
    return allLogs.sublist(start, end > allLogs.length ? allLogs.length : end);
  }

  // 🎬 MOCK DATA: Get paginated mock logs
  List<Map<String, dynamic>> get paginatedMockLogs {
    final start = currentPage * pageSize;
    final end = start + pageSize;
    return mockLogs.sublist(start, end > mockLogs.length ? mockLogs.length : end);
  }

  String formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'Unknown time';
    final dt = ts.toDate();
    return DateFormat('MMM dd, yyyy HH:mm').format(dt);
  }

  Future<void> deleteLog(DocumentSnapshot log) async {
    // Only owner can delete
    if (userRole != UserRole.owner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the owner can delete activity logs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        title: const Text('Delete Log', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this activity log?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await log.reference.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity log deleted'),
            backgroundColor: Colors.green,
          ),
        );
        fetchLogs();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting log: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> deleteAllLogs() async {
    // Only owner can delete
    if (userRole != UserRole.owner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the owner can delete activity logs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        title: const Text('Delete All Logs', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete ALL activity logs? This action cannot be undone!',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (var log in allLogs) {
          batch.delete(log.reference);
        }
        await batch.commit();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All activity logs deleted'),
            backgroundColor: Colors.green,
          ),
        );
        fetchLogs();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Title
          const Text(
            'Activity Log',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          // Filter and Delete Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filter Logs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              // Delete All button - Only visible to Owner and Admin
              if (userRole == UserRole.owner || userRole == UserRole.admin) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: deleteAllLogs,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Delete All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // Active Filters Display
          if (startDate != null || endDate != null || userFilter.isNotEmpty || keywordFilter.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Filters Active',
                      style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        startDate = null;
                        endDate = null;
                        userFilter = '';
                        keywordFilter = '';
                      });
                      fetchLogs();
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          
          // Logs List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  )
                : (USE_MOCK_DATA ? mockLogs.isEmpty : allLogs.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 64, color: Colors.grey.shade700),
                              const SizedBox(height: 16),
                              Text(
                                'No activity logs found',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: USE_MOCK_DATA ? () async {} : fetchLogs,
                                child: ListView.builder(
                                  itemCount: USE_MOCK_DATA ? paginatedMockLogs.length : paginatedLogs.length,
                                  itemBuilder: (context, index) {
                              // 🎬 MOCK DATA: Use mock logs or real logs
                              final message = USE_MOCK_DATA 
                                  ? paginatedMockLogs[index]['message'] ?? 'No message'
                                  : paginatedLogs[index]['message'] ?? 'No message';
                              final user = USE_MOCK_DATA
                                  ? paginatedMockLogs[index]['user'] ?? 'Unknown user'
                                  : paginatedLogs[index]['user'] ?? 'Unknown user';
                              final timestamp = USE_MOCK_DATA
                                  ? formatTimestamp(paginatedMockLogs[index]['timestamp'])
                                  : formatTimestamp(paginatedLogs[index]['timestamp']);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2235),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.1),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.history,
                                            color: Colors.amber,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            message,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        // Delete button - Only visible to Owner and Admin
                                        if (!USE_MOCK_DATA && (userRole == UserRole.owner || userRole == UserRole.admin))
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            onPressed: () => deleteLog(paginatedLogs[index]),
                                            tooltip: 'Delete log',
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.person, size: 14, color: Colors.amber.shade700),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            user,
                                            style: TextStyle(
                                              color: Colors.amber.shade700,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Text(
                                          timestamp,
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.devices, size: 14, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Text(
                                          'System: ${widget.systemId}',
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                                  },
                                ),
                              ),
                            ),
                            if ((USE_MOCK_DATA ? mockLogs.length : allLogs.length) > pageSize)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2235),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      onPressed: currentPage > 0 ? () => setState(() => currentPage--) : null,
                                      icon: const Icon(Icons.arrow_back, color: Colors.amber),
                                      tooltip: 'Previous',
                                    ),
                                    Text(
                                      'Page ${currentPage + 1} of ${((USE_MOCK_DATA ? mockLogs.length : allLogs.length) / pageSize).ceil()}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      onPressed: (currentPage + 1) * pageSize < (USE_MOCK_DATA ? mockLogs.length : allLogs.length)
                                          ? () => setState(() => currentPage++)
                                          : null,
                                      icon: const Icon(Icons.arrow_forward, color: Colors.amber),
                                      tooltip: 'Next',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    if (!mounted) return;
    
    final userController = TextEditingController(text: userFilter);
    final keywordController = TextEditingController(text: keywordFilter);
    final tempStartController = TextEditingController(text: startDateController.text);
    final tempEndController = TextEditingController(text: endDateController.text);
    String? selectedUser = userFilter.isNotEmpty ? userFilter : null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2235),
          title: const Text('Filter Logs', style: TextStyle(color: Colors.white)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Searchable Dropdown for User Filter
                const Text(
                  'Filter by User',
                  style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // User email search
                TextField(
                  controller: userController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'User Email',
                    hintText: 'Enter user email to filter',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    prefixIcon: const Icon(Icons.person, color: Colors.amber),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Keyword Search
                TextField(
                  controller: keywordController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Search keyword in message',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search, color: Colors.amber),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Date Range with Text Input
                const Text(
                  'Date Range',
                  style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tempStartController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Start Date (YYYY-MM-DD)',
                    labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.amber, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tempEndController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'End Date (YYYY-MM-DD)',
                    labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.amber, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Format: YYYY-MM-DD (e.g., 2024-10-12)',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontStyle: FontStyle.italic),
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                // Parse dates from text input
                DateTime? parsedStart;
                DateTime? parsedEnd;
                
                if (tempStartController.text.isNotEmpty) {
                  try {
                    parsedStart = DateTime.parse(tempStartController.text);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid start date format. Use YYYY-MM-DD'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }
                
                if (tempEndController.text.isNotEmpty) {
                  try {
                    parsedEnd = DateTime.parse(tempEndController.text);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid end date format. Use YYYY-MM-DD'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }
                
                setState(() {
                  userFilter = userController.text;
                  keywordFilter = keywordController.text;
                  startDate = parsedStart;
                  endDate = parsedEnd;
                  startDateController.text = tempStartController.text;
                  endDateController.text = tempEndController.text;
                });
                fetchLogs();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
