import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationsPage extends StatefulWidget {
  final String systemId;
  const NotificationsPage({required this.systemId, super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final DatabaseReference notifRef;
  List<String> notifications = [];

  @override
  void initState() {
    super.initState();
    notifRef = FirebaseDatabase.instance.ref(
      'hardwareSystems/${widget.systemId}/notifications',
    );

    notifRef.onValue.listen((event) {
      final snapshot = event.snapshot.value;
      if (snapshot is List) {
        setState(() {
          notifications = snapshot.reversed.map((e) => e.toString()).toList();
        });
      } else if (snapshot is Map) {
        final entries = snapshot.entries.map((e) {
          final value = e.value;
          if (value is Map && value['message'] != null) {
            return value['message'].toString();
          }
          return value.toString();
        }).toList();
        setState(() {
          notifications = entries.reversed.toList();
        });
      }
    });
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
