import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ConnectionStatusWidget extends StatefulWidget {
  final String systemId;
  final bool compact;

  const ConnectionStatusWidget({
    Key? key,
    required this.systemId,
    this.compact = false,
  }) : super(key: key);

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  bool megaConnected = false;
  bool esp32Online = false;

  @override
  void initState() {
    super.initState();
    _listenToConnectionStatus();
  }

  void _listenToConnectionStatus() {
    final systemRef = FirebaseDatabase.instance.ref('hardwareSystems/${widget.systemId}');

    // Listen to MEGA connection status
    systemRef.child('status/megaConnected').onValue.listen((event) {
      if (mounted) {
        setState(() {
          megaConnected = event.snapshot.value == true;
        });
      }
    });

    // Listen to ESP32 online status
    systemRef.child('status/online').onValue.listen((event) {
      if (mounted) {
        setState(() {
          esp32Online = event.snapshot.value == true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactView();
    }
    return _buildFullView();
  }

  Widget _buildCompactView() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusDot(esp32Online, 'ESP32'),
        const SizedBox(width: 8),
        _buildStatusDot(megaConnected, 'MEGA'),
      ],
    );
  }

  Widget _buildStatusDot(bool connected, String label) {
    return Tooltip(
      message: '$label: ${connected ? "Connected" : "Disconnected"}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: connected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: connected ? Colors.green : Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullView() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade700,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Connection',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildConnectionRow(
            'ESP32 (WiFi Bridge)',
            esp32Online,
            Icons.wifi,
          ),
          const SizedBox(height: 8),
          _buildConnectionRow(
            'MEGA (Controller)',
            megaConnected,
            Icons.link,
          ),
          const SizedBox(height: 12),
          _buildOverallStatus(),
        ],
      ),
    );
  }

  Widget _buildConnectionRow(String label, bool connected, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: connected ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: connected
                ? Colors.green.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            connected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: connected ? Colors.green : Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStatus() {
    final allConnected = esp32Online && megaConnected;
    final someConnected = esp32Online || megaConnected;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (allConnected) {
      statusColor = Colors.green;
      statusText = 'All Systems Operational';
      statusIcon = Icons.check_circle;
    } else if (someConnected) {
      statusColor = Colors.orange;
      statusText = 'Partial Connection';
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.red;
      statusText = 'System Offline';
      statusIcon = Icons.error;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
