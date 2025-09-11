import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

  double temperature = 0.0;
  int rainLevel = 0;
  bool ledState = false;

  bool wifiConnected = false;
  bool internetConnected = false;
  bool firebaseConnected = false;

  @override
  void initState() {
    super.initState();
    dbRef.child('sensors/temperature').onValue.listen((event) {
      final temp = event.snapshot.value;
      setState(() {
        temperature = temp is double
            ? temp
            : double.tryParse(temp.toString()) ?? 0.0;
      });
    });

    dbRef.child('sensors/rain').onValue.listen((event) {
      final rain = event.snapshot.value;
      setState(() {
        rainLevel = rain is int ? rain : int.tryParse(rain.toString()) ?? 0;
      });
    });

    dbRef.child('controls/led').onValue.listen((event) {
      final state = event.snapshot.value;
      setState(() {
        ledState = state == true || state.toString() == "true";
      });
    });

    dbRef.child('system/wifiConnected').onValue.listen((event) {
      setState(() {
        wifiConnected = event.snapshot.value == true;
      });
    });

    dbRef.child('system/internetConnected').onValue.listen((event) {
      setState(() {
        internetConnected = event.snapshot.value == true;
      });
    });

    dbRef.child('system/firebaseConnected').onValue.listen((event) {
      setState(() {
        firebaseConnected = event.snapshot.value == true;
      });
    });
  }

  void toggleLED() {
    dbRef.child('controls/led').set(!ledState);
  }

  Widget statusTile(String label, bool status, IconData icon) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Card(
        key: ValueKey(status),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: Icon(icon, color: status ? Colors.green : Colors.red),
          title: Text(label),
          trailing: Text(
            status ? "Connected ✅" : "Disconnected ❌",
            style: TextStyle(color: status ? Colors.green : Colors.red),
          ),
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.3),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Card(
        key: ValueKey(value),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: Icon(icon, color: iconColor),
          title: Text(label),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
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
                  FadeRoute(page: const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.lightBlueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "📡 Connection Status",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            statusTile("WiFi", wifiConnected, Icons.wifi),
            statusTile("Internet", internetConnected, Icons.public),
            statusTile("Firebase", firebaseConnected, Icons.fireplace),

            const SizedBox(height: 20),
            const Text(
              "🌡️ Sensors",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            sensorTile(
              "Temperature",
              "${temperature.toStringAsFixed(1)} °C",
              Icons.thermostat,
              Colors.orange,
            ),
            sensorTile(
              "Rain",
              rainLevel > 0 ? "Activated ✅" : "Deactivated ❌",
              Icons.water_drop,
              rainLevel > 0 ? Colors.green : Colors.red,
            ),

            const SizedBox(height: 20),
            const Text(
              "💡 Controls",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: ledState ? Colors.red : Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: toggleLED,
                icon: Icon(
                  ledState ? Icons.lightbulb : Icons.lightbulb_outline,
                ),
                label: Text(ledState ? "Turn OFF LED" : "Turn ON LED"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
