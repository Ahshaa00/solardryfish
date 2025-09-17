import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  List<String> allNotifications = [];
  int currentPage = 0;
  final int pageSize = 5;

  @override
  void initState() {
    super.initState();
    dbRef.child('notifications').onValue.listen((event) {
      final data = event.snapshot.value as List?;
      if (data != null) {
        setState(() {
          allNotifications = data.reversed.map((e) => e.toString()).toList();
        });
      }
    });
  }

  List<String> get paginatedNotifications {
    final start = currentPage * pageSize;
    final end = start + pageSize;
    return allNotifications.sublist(
      start,
      end > allNotifications.length ? allNotifications.length : end,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: paginatedNotifications.length,
              itemBuilder: (context, index) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(
                    Icons.notification_important,
                    color: Colors.orange,
                  ),
                  title: Text(paginatedNotifications[index]),
                ),
              ),
            ),
          ),
          if (allNotifications.length > pageSize)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: currentPage > 0
                        ? () => setState(() => currentPage--)
                        : null,
                    child: const Text("Previous"),
                  ),
                  ElevatedButton(
                    onPressed:
                        (currentPage + 1) * pageSize < allNotifications.length
                        ? () => setState(() => currentPage++)
                        : null,
                    child: const Text("Next"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
