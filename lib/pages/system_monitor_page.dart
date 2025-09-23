import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class SystemMonitorPage extends StatefulWidget {
  final String systemId;
  const SystemMonitorPage({required this.systemId, super.key});

  @override
  State<SystemMonitorPage> createState() => _SystemMonitorPageState();
}

class _SystemMonitorPageState extends State<SystemMonitorPage> {
  late final DatabaseReference systemRef;

  Map<String, dynamic> shtData = {
    "sht31_1": {},
    "sht31_2": {},
    "sht31_3": {},
    "sht31_4": {},
  };
  Map<String, dynamic> rainData = {};
  Map<String, dynamic> lightData = {};

  bool lidState = false;
  bool heaterState = false;

  double batteryLevel = 0.0;
  bool isCharging = false;
  bool wifiConnected = false;
  bool internetConnected = false;
  bool firebaseConnected = false;
  bool megaConnected = false;

  @override
  void initState() {
    super.initState();
    systemRef = FirebaseDatabase.instance.ref(
      'hardwareSystems/${widget.systemId}',
    );
    fetchSensorData();

    systemRef.child('sensors').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) parseSensorData(data);
    });

    systemRef.child('controls/lid').onValue.listen((event) {
      setState(() => lidState = event.snapshot.value == "open");
    });

    systemRef.child('controls/heater').onValue.listen((event) {
      setState(() => heaterState = event.snapshot.value == "on");
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
      setState(() => isCharging = event.snapshot.value == true);
    });

    systemRef.child('status/wifi').onValue.listen((event) {
      setState(() => wifiConnected = event.snapshot.value == true);
    });

    systemRef.child('status/internet').onValue.listen((event) {
      setState(() => internetConnected = event.snapshot.value == true);
    });

    systemRef.child('status/firebase').onValue.listen((event) {
      setState(() => firebaseConnected = event.snapshot.value == true);
    });

    systemRef.child('status/mega').onValue.listen((event) {
      setState(() => megaConnected = event.snapshot.value == true);
    });
  }

  Future<void> fetchSensorData() async {
    final snapshot = await systemRef.child('sensors').get();
    final data = snapshot.value as Map?;
    if (data != null) parseSensorData(data);
  }

  void parseSensorData(Map data) {
    final sht = {"sht31_1": {}, "sht31_2": {}, "sht31_3": {}, "sht31_4": {}};
    final rain = <String, dynamic>{};
    final light = <String, dynamic>{};

    for (var entry in data.entries) {
      if (entry.key.startsWith('sht31_')) {
        sht[entry.key] = Map<String, dynamic>.from(entry.value ?? {});
      } else if (entry.key == 'rain') {
        rain.addAll(Map<String, dynamic>.from(entry.value ?? {}));
      } else if (entry.key == 'light') {
        light.addAll(Map<String, dynamic>.from(entry.value ?? {}));
      }
    }

    setState(() {
      shtData = sht;
      rainData = rain;
      lightData = light;
    });
  }

  Widget statusCard(String label, bool status, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1E2338),
      child: ListTile(
        leading: Icon(icon, color: status ? Colors.green : Colors.red),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: Text(
          status ? "Connected" : "Disconnected",
          style: TextStyle(
            color: status ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget sensorCard({
    required String title,
    required List<String> lines,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF1E2338),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    line,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget buildSHTSensor(String key) {
    final data = Map<String, dynamic>.from(shtData[key] ?? {});
    final temp = (data['temp'] ?? 0).toDouble();
    final hum = (data['hum'] ?? 0).toDouble();
    final timestamp = data['timestamp'];
    final time = timestamp != null
        ? DateFormat(
            'hh:mm a',
          ).format(DateTime.fromMillisecondsSinceEpoch(timestamp))
        : null;

    final lines = [
      "Temperature: ${temp.toStringAsFixed(1)} °C",
      "Humidity: ${hum.toStringAsFixed(0)} %",
      if (time != null) "Last updated: $time",
    ];

    return sensorCard(
      title: key.replaceAll('_', ' ').toUpperCase(),
      lines: lines,
      color: Colors.orange,
      icon: Icons.thermostat,
    );
  }

  Widget buildAnalogSensor(Map<String, dynamic> data, int index, String type) {
    final value = data['$index'] ?? 0;
    final activated = value > 0;
    final status = activated ? "Activated ✅" : "Deactivated ❌";
    final color = type == 'rain' ? Colors.blue : Colors.amber;
    final icon = type == 'rain' ? Icons.water_drop : Icons.lightbulb;

    return sensorCard(
      title: "$type Sensor $index".toUpperCase(),
      lines: ["Value: $value", "Status: $status"],
      color: color,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("System Monitor"),
      ),
      backgroundColor: const Color(0xFF141829),
      body: RefreshIndicator(
        onRefresh: fetchSensorData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ExpansionTile(
              initiallyExpanded: true,
              collapsedBackgroundColor: const Color(0xFF1E2338),
              backgroundColor: const Color(0xFF1E2338),
              title: const Text(
                "🌡️ Temperature & Humidity",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              children: [
                buildSHTSensor("sht31_1"),
                buildSHTSensor("sht31_2"),
                buildSHTSensor("sht31_3"),
                buildSHTSensor("sht31_4"),
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              collapsedBackgroundColor: const Color(0xFF1E2338),
              backgroundColor: const Color(0xFF1E2338),
              title: const Text(
                "🌧️ Raindrop Sensors",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              children: List.generate(
                4,
                (i) => buildAnalogSensor(rainData, i + 1, 'rain'),
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              collapsedBackgroundColor: const Color(0xFF1E2338),
              backgroundColor: const Color(0xFF1E2338),
              title: const Text(
                "💡 Photoresistor Sensors",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              children: List.generate(
                4,
                (i) => buildAnalogSensor(lightData, i + 1, 'light'),
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              collapsedBackgroundColor: const Color(0xFF1E2338),
              backgroundColor: const Color(0xFF1E2338),
              title: const Text(
                "🔋 Machine Status",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              children: [
                sensorCard(
                  title: "Battery",
                  lines: ["${batteryLevel.toStringAsFixed(0)}%"],
                  color: batteryLevel > 50 ? Colors.green : Colors.red,
                  icon: Icons.battery_full,
                ),
                sensorCard(
                  title: "Charging",
                  lines: [isCharging ? "Charging ⚡" : "Not Charging"],
                  color: isCharging ? Colors.green : Colors.grey,
                  icon: Icons.power,
                ),
                sensorCard(
                  title: "Lid Status",
                  lines: [lidState ? "Open 🔓" : "Closed 🔒"],
                  color: lidState ? Colors.orange : Colors.green,
                  icon: Icons.door_front_door,
                ),
                sensorCard(
                  title: "Heater Status",
                  lines: [heaterState ? "On 🔥" : "Off ❄️"],
                  color: heaterState ? Colors.red : Colors.grey,
                  icon: Icons.fireplace,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              collapsedBackgroundColor: const Color(0xFF1E2338),
              backgroundColor: const Color(0xFF1E2338),
              title: const Text(
                "📡 Connection Status",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              children: [
                statusCard("WiFi", wifiConnected, Icons.wifi),
                statusCard("Internet", internetConnected, Icons.public),
                statusCard("Firebase", firebaseConnected, Icons.cloud),
                statusCard("Mega", megaConnected, Icons.usb),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
