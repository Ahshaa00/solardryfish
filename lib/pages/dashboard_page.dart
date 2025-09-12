// dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'sensor_overview_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final dbRef = FirebaseDatabase.instance.ref();

  double temperature = 0.0;
  int rainLevel = 0;
  bool lidState = false;
  bool heaterState = false;

  bool wifiConnected = false;
  bool internetConnected = false;
  bool firebaseConnected = false;
  bool megaConnected = false;

  @override
  void initState() {
    super.initState();

    dbRef.child('sensors/sht31_1/temp').onValue.listen((event) {
      final temp = event.snapshot.value;
      setState(() {
        temperature = temp is double
            ? temp
            : double.tryParse(temp.toString()) ?? 0.0;
      });
    });

    dbRef.child('sensors/rain/1').onValue.listen((event) {
      final rain = event.snapshot.value;
      setState(() {
        rainLevel = rain is int ? rain : int.tryParse(rain.toString()) ?? 0;
      });
    });

    dbRef.child('controls/lid').onValue.listen((event) {
      setState(() {
        lidState = event.snapshot.value == "open";
      });
    });

    dbRef.child('controls/heater').onValue.listen((event) {
      setState(() {
        heaterState = event.snapshot.value == "on";
      });
    });

    dbRef.child('status/wifi').onValue.listen((event) {
      setState(() {
        wifiConnected = event.snapshot.value == true;
      });
    });

    dbRef.child('status/internet').onValue.listen((event) {
      setState(() {
        internetConnected = event.snapshot.value == true;
      });
    });

    dbRef.child('status/firebase').onValue.listen((event) {
      setState(() {
        firebaseConnected = event.snapshot.value == true;
      });
    });

    dbRef.child('status/mega').onValue.listen((event) {
      setState(() {
        megaConnected = event.snapshot.value == true;
      });
    });
  }

  void toggleLid() {
    dbRef.child('controls/lid').set(lidState ? "close" : "open");
  }

  void toggleHeater() {
    dbRef.child('controls/heater').set(heaterState ? "off" : "on");
  }

  Widget statusTile(String label, bool status, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: status ? Colors.green : Colors.red),
        title: Text(label),
        trailing: Text(
          status ? "Connected ✅" : "Disconnected ❌",
          style: TextStyle(color: status ? Colors.green : Colors.red),
        ),
      ),
    );
  }

  Widget sensorTile(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  Widget controlButton(
    String label,
    bool state,
    IconData activeIcon,
    IconData inactiveIcon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(state ? activeIcon : inactiveIcon),
      label: Text(state ? "Turn OFF $label" : "Turn ON $label"),
      style: ElevatedButton.styleFrom(
        backgroundColor: state ? Colors.red : Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SolarDryFish Dashboard'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "📡 Connection Status",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          statusTile("WiFi", wifiConnected, Icons.wifi),
          statusTile("Internet", internetConnected, Icons.public),
          statusTile("Firebase", firebaseConnected, Icons.fireplace),
          statusTile("Mega", megaConnected, Icons.usb),

          const SizedBox(height: 20),
          const Text(
            "🌡️ Sensors",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          sensorTile(
            "SHT31 #1 Temp",
            "${temperature.toStringAsFixed(1)} °C",
            Icons.thermostat,
            Colors.orange,
          ),
          sensorTile(
            "Rain Sensor #1",
            rainLevel > 0 ? "Activated ✅" : "Deactivated ❌",
            Icons.water_drop,
            rainLevel > 0 ? Colors.green : Colors.red,
          ),

          const SizedBox(height: 20),
          const Text(
            "⚙️ Controls",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          controlButton(
            "Lid",
            lidState,
            Icons.lock,
            Icons.lock_open,
            toggleLid,
          ),
          const SizedBox(height: 10),
          controlButton(
            "Heater",
            heaterState,
            Icons.local_fire_department,
            Icons.fireplace,
            toggleHeater,
          ),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.sensors),
            label: const Text("View All Sensors"),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SensorOverviewPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
