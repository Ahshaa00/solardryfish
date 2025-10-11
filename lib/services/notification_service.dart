import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  DatabaseReference? _notifRef;
  Set<String> _seenNotificationIds = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(initSettings);
    _isInitialized = true;

    // Start listening for notifications
    _startListening();
  }

  void _startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notifRef = FirebaseDatabase.instance.ref('users/${user.uid}/notifications');

    _notifRef!.onValue.listen((event) {
      final snapshot = event.snapshot.value;
      
      if (snapshot is Map) {
        snapshot.entries.forEach((entry) {
          final notificationId = entry.key.toString();
          
          // Skip if already seen
          if (_seenNotificationIds.contains(notificationId)) {
            return;
          }
          
          // Mark as seen
          _seenNotificationIds.add(notificationId);
          
          // Show notification
          final value = entry.value;
          if (value is Map) {
            final message = value['message']?.toString() ?? '';
            if (message.isNotEmpty) {
              _showLocalNotification(message);
            }
          }
        });
      }
    });
  }

  Future<void> _showLocalNotification(String message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'notif_channel_id',
          'Notifications',
          channelDescription: 'User notifications',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'SolarDryFish',
      message,
      platformDetails,
    );
  }

  void dispose() {
    _notifRef = null;
    _seenNotificationIds.clear();
  }
}
