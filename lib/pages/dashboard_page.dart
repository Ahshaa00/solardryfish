import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  final String systemId;
  const DashboardPage({required this.systemId, super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DatabaseReference systemRef;

  bool lidState = false;
  bool heaterState = false;
  double temperature = 0.0;
  double humidity = 0.0;
  double batteryLevel = 0.0;
  bool isCharging = false;

  @override
  void initState() {
    super.initState();
    systemRef = FirebaseDatabase.instance.ref(
      'hardwareSystems/${widget.systemId}',
    );

    systemRef.child('controls/lid').onValue.listen((event) {
      setState(() {
        lidState = event.snapshot.value == "open";
      });
    });

    systemRef.child('controls/heater').onValue.listen((event) {
      setState(() {
        heaterState = event.snapshot.value == "on";
      });
    });

    systemRef.child('sensors/sht31_1/temp').onValue.listen((event) {
      final temp = event.snapshot.value;
      setState(() {
        temperature = temp is double
            ? temp
            : double.tryParse(temp.toString()) ?? 0.0;
      });
    });

    systemRef.child('sensors/sht31_1/hum').onValue.listen((event) {
      final hum = event.snapshot.value;
      setState(() {
        humidity = hum is double ? hum : double.tryParse(hum.toString()) ?? 0.0;
      });
    });

    systemRef.child('status/battery').onValue.listen((event) {
      final battery = event.snapshot.value;
      setState(() {
        batteryLevel = battery is double
            ? battery
            : double.tryParse(battery.toString()) ?? 0.0;
      });
    });

    systemRef.child('status/charging').onValue.listen((event) {
      setState(() {
        isCharging = event.snapshot.value == true;
      });
    });
  }

  void toggleLid() {
    final newState = lidState ? "close" : "open";
    systemRef.child('controls/lid').set(newState);
  }

  void toggleHeater() {
    final newState = heaterState ? "off" : "on";
    systemRef.child('controls/heater').set(newState);
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget controlSwitch(String label, bool state, VoidCallback onToggle) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Switch(
            value: state,
            onChanged: (_) => onToggle(),
            activeThumbColor: Colors.black,
          ),
        ],
      ),
    );
  }

  Widget statusBlock({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2338),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget statusRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E2338),
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.amber),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SolarDryFish",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "System ID: ${widget.systemId}",
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.white),
              title: const Text(
                "Account",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pushNamed(
                context,
                '/schedule',
                arguments: widget.systemId,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.white),
              title: const Text(
                "Schedule Flip",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pushNamed(
                context,
                '/schedule',
                arguments: widget.systemId,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white),
              title: const Text(
                "Activity Log",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pushNamed(
                context,
                '/log',
                arguments: widget.systemId,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications, color: Colors.white),
              title: const Text(
                "Notifications",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pushNamed(
                context,
                '/notifications',
                arguments: widget.systemId,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sensors, color: Colors.white),
              title: const Text(
                "Monitor",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pushNamed(
                context,
                '/monitor',
                arguments: widget.systemId,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text("Logout"),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("SolarDryFish"),
      ),
      backgroundColor: const Color(0xFF141829),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          sectionTitle("Dashboard"),
          controlSwitch("Lid Control", lidState, toggleLid),
          controlSwitch("Air Heater Fan", heaterState, toggleHeater),
          sectionTitle("Drying Status"),
          statusBlock(
            children: [
              statusRow(
                "Temperature",
                "${temperature.toStringAsFixed(1)}°",
                Icons.thermostat,
                Colors.orange,
              ),
              statusRow(
                "Humidity",
                "${humidity.toStringAsFixed(0)}%",
                Icons.water_drop,
                Colors.blue,
              ),
            ],
          ),
          sectionTitle("Machine Status"),
          statusBlock(
            children: [
              statusRow(
                "Battery",
                "${batteryLevel.toStringAsFixed(0)}%",
                Icons.battery_full,
                batteryLevel > 50 ? Colors.green : Colors.red,
              ),
              statusRow(
                "Charging",
                isCharging ? "Charging" : "Not Charging",
                Icons.power,
                isCharging ? Colors.green : Colors.grey,
              ),
              statusRow(
                "Lid Status",
                lidState ? "Closed" : "Open",
                Icons.door_front_door,
                lidState ? Colors.green : Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
