import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  List<String> allLogs = [];
  int currentPage = 0;
  final int pageSize = 5;

  @override
  void initState() {
    super.initState();
    dbRef.child('logs').onValue.listen((event) {
      final data = event.snapshot.value as List?;
      if (data != null) {
        setState(() {
          allLogs = data.reversed.map((e) => e.toString()).toList();
        });
      }
    });
  }

  List<String> get paginatedLogs {
    final start = currentPage * pageSize;
    final end = start + pageSize;
    return allLogs.sublist(start, end > allLogs.length ? allLogs.length : end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Activity Log")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: paginatedLogs.length,
              itemBuilder: (context, index) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.blue),
                  title: Text(paginatedLogs[index]),
                ),
              ),
            ),
          ),
          if (allLogs.length > pageSize)
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
                    onPressed: (currentPage + 1) * pageSize < allLogs.length
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
