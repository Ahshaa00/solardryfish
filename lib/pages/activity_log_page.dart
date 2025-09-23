import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ActivityLogPage extends StatefulWidget {
  final String systemId;
  const ActivityLogPage({required this.systemId, super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  late final DatabaseReference logRef;
  List<String> allLogs = [];
  int currentPage = 0;
  final int pageSize = 5;

  @override
  void initState() {
    super.initState();
    logRef = FirebaseDatabase.instance.ref(
      'hardwareSystems/${widget.systemId}/logs',
    );

    logRef.onValue.listen((event) {
      final snapshot = event.snapshot.value;
      if (snapshot is List) {
        setState(() {
          allLogs = snapshot.reversed.map((e) => e.toString()).toList();
        });
      } else if (snapshot is Map) {
        final entries = snapshot.entries
            .map((e) => e.value.toString())
            .toList();
        setState(() {
          allLogs = entries.reversed.toList();
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
      backgroundColor: const Color(0xFF141829),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: paginatedLogs.length,
              itemBuilder: (context, index) => Card(
                color: const Color(0xFF1E2338),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.blue),
                  title: Text(
                    paginatedLogs[index],
                    style: const TextStyle(color: Colors.white),
                  ),
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
