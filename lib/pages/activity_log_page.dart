import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ActivityLogPage extends StatefulWidget {
  final String systemId;
  const ActivityLogPage({required this.systemId, super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  final int pageSize = 5;
  List<DocumentSnapshot> allLogs = [];
  int currentPage = 0;
  bool isLoading = true;

  DateTime? startDate;
  DateTime? endDate;
  String userFilter = '';
  String keywordFilter = '';

  @override
  void initState() {
    super.initState();
    fetchLogs();
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
      List<DocumentSnapshot> filtered = querySnapshot.docs;

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
          currentPage = 0;
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print("🔥 Firestore fetchLogs error: $e");
      print("📍 Stack trace:\n$stackTrace");

      if (mounted) {
        setState(() {
          isLoading = false;
          allLogs = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading logs: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<DocumentSnapshot> get paginatedLogs {
    final start = currentPage * pageSize;
    final end = start + pageSize;
    return allLogs.sublist(start, end > allLogs.length ? allLogs.length : end);
  }

  String formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'Unknown time';
    final dt = ts.toDate();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      fetchLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Activity Log")),
      backgroundColor: const Color(0xFF141829),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: "Filter by user email",
                                filled: true,
                                fillColor: Color(0xFF1E2338),
                                labelStyle: TextStyle(color: Colors.amber),
                              ),
                              style: const TextStyle(color: Colors.white),
                              onChanged: (value) {
                                userFilter = value;
                                fetchLogs();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 140,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: pickDateRange,
                              icon: const Icon(Icons.date_range),
                              label: const Text("Filter by Date"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Search keyword in message",
                          filled: true,
                          fillColor: Color(0xFF1E2338),
                          labelStyle: TextStyle(color: Colors.amber),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) {
                          keywordFilter = value;
                          fetchLogs();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: allLogs.isEmpty
                      ? const Center(
                          child: Text(
                            "No logs found for this system.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: paginatedLogs.length,
                          itemBuilder: (context, index) {
                            final log = paginatedLogs[index];
                            final message = log['message'] ?? 'No message';
                            final user = log['user'] ?? 'Unknown user';
                            final timestamp = formatTimestamp(log['timestamp']);
                            return Card(
                              color: const Color(0xFF1E2338),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.history,
                                  color: Colors.amber,
                                ),
                                title: Text(
                                  message,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  "🗓️ $timestamp\n👤 $user",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            );
                          },
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
                          onPressed:
                              (currentPage + 1) * pageSize < allLogs.length
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
