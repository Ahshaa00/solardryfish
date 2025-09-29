import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsPage extends StatefulWidget {
  final String systemId;
  const NotificationsPage({required this.systemId, super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final DatabaseReference notifRef;
  List<String> notifications = [];

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    initializeNotifications();

    notifRef = FirebaseDatabase.instance.ref(
      'hardwareSystems/${widget.systemId}/notifications',
    );

    notifRef.onValue.listen((event) {
      final snapshot = event.snapshot.value;
      List<String> newNotifications = [];

      if (snapshot is List) {
        newNotifications = snapshot.reversed.map((e) => e.toString()).toList();
      } else if (snapshot is Map) {
        newNotifications = snapshot.entries
            .map((e) {
              final value = e.value;
              if (value is Map && value['message'] != null) {
                return value['message'].toString();
              }
              return value.toString();
            })
            .toList()
            .reversed
            .toList();
      }

      final unseen = newNotifications.where(
        (msg) => !notifications.contains(msg),
      );
      for (final msg in unseen) {
        showLocalNotification(msg);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      backgroundColor: const Color(0xFF141829),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) => Card(
          color: const Color(0xFF1E2338),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.notifications, color: Colors.amber),
            title: Text(
              notifications[index],
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
