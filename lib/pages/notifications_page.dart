import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../barrel.dart';
import 'notification_test_page.dart';

class NotificationsPage extends StatefulWidget {
  final String systemId;
  const NotificationsPage({required this.systemId, super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final DatabaseReference notifRef;
  List<Map<String, dynamic>> notifications = [];

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    initializeNotifications();

    // Get user-specific notifications
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    notifRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/notifications',
    );

    notifRef.onValue.listen((event) {
      final snapshot = event.snapshot.value;
      List<Map<String, dynamic>> newNotifications = [];

      if (snapshot is Map) {
        newNotifications = snapshot.entries
            .map((e) {
              final value = e.value;
              if (value is Map) {
                return {
                  'id': e.key.toString(),
                  'message': value['message']?.toString() ?? '',
                  'timestamp': value['timestamp'] ?? 0,
                  'type': value['type']?.toString() ?? 'info',
                  'systemId': value['systemId']?.toString() ?? '',
                  'isTest': value['isTest'] == true,
                };
              }
              return {
                'id': e.key.toString(),
                'message': value.toString(),
                'timestamp': 0,
                'type': 'info',
                'systemId': '',
                'isTest': false,
              };
            })
            .toList();
        
        // Sort by timestamp (newest first)
        newNotifications.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      }

      // Show local notification for new messages
      final existingIds = notifications.map((n) => n['id']).toSet();
      final newMessages = newNotifications.where((n) => !existingIds.contains(n['id']));
      
      for (final notif in newMessages) {
        showLocalNotification(notif['message'] as String);
      }

      setState(() {
        notifications = newNotifications;
      });
    });
  }

  Future<void> initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> showLocalNotification(String message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'notif_channel_id',
          'Notifications',
          channelDescription: 'Realtime alerts from Firebase',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFF1E2338),
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'New Notification',
      message,
      platformDetails,
    );
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'Just now';
    
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await notifRef.child(notificationId).remove();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        title: const Text(
          'Clear All Notifications?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all notifications. This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notifRef.remove();
      setState(() {
        notifications.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E2235),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // TEST: Notification Test Button (Remove before production)
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orange),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationTestPage(systemId: widget.systemId),
                ),
              );
            },
            tooltip: 'Test Notifications',
          ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: clearAllNotifications,
              tooltip: 'Clear All',
            ),
        ],
      ),
      backgroundColor: const Color(0xFF141829),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${notifications.length} notification${notifications.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          
          // Notifications List
          Expanded(
            child: notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off,
                          size: 64,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2235),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (notifications[index]['isTest'] == true 
                                  ? Colors.orange 
                                  : Colors.amber).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              notifications[index]['isTest'] == true 
                                  ? Icons.bug_report 
                                  : Icons.notifications_active,
                              color: notifications[index]['isTest'] == true 
                                  ? Colors.orange 
                                  : Colors.amber,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notifications[index]['message'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTimestamp(notifications[index]['timestamp'] as int),
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (notifications[index]['isTest'] == true) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.orange, width: 1),
                                        ),
                                        child: const Text(
                                          'TEST',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => deleteNotification(notifications[index]['id'] as String),
                            tooltip: 'Delete',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
