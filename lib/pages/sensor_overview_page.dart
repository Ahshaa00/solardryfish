import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SensorOverviewPage extends StatefulWidget {
  const SensorOverviewPage({super.key});

  @override
  State<SensorOverviewPage> createState() => _SensorOverviewPageState();
}

class _SensorOverviewPageState extends State<SensorOverviewPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic> shtData = {};
  Map<String, dynamic> rainData = {};
  Map<String, dynamic> lightData = {};

  @override
  void initState() {
    super.initState();
    dbRef.child('sensors').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final sht = <String, dynamic>{};
        final rain = <String, dynamic>{};
        final light = <String, dynamic>{};

        for (var entry in data.entries) {
          if (entry.key.startsWith('sht31_')) {
            sht[entry.key] = entry.value;
          } else if (entry.key == 'rain') {
            rain.addAll(Map<String, dynamic>.from(entry.value));
          } else if (entry.key == 'light') {
            light.addAll(Map<String, dynamic>.from(entry.value));
          }
        }

        setState(() {
          shtData = sht;
          rainData = rain;
          lightData = light;
        });
      }
    });
  }

  Widget sensorCard({
    required String title,
    required List<String> lines,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(line),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget buildSHTSensor(int index) {
    final key = 'sht31_$index';
    final data = Map<String, dynamic>.from(shtData[key] ?? {});
    final temp = data['temp']?.toStringAsFixed(1) ?? 'N/A';
    final hum = data['hum']?.toStringAsFixed(0) ?? 'N/A';
    return sensorCard(
      title: "Sensor $index",
      lines: ["Temperature: $temp °C", "Humidity: $hum %"],
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
      title: "Sensor $index",
      lines: ["Value: $value", "Status: $status"],
      color: color,
      icon: icon,
    );
  }

  Widget expandableSection({
    required String title,
    required Widget sensor1,
    required List<Widget> expandedSensors,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: Icon(icon, color: color),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12),
        children: expandedSensors,
        subtitle: sensor1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sensor Overview"),
        backgroundColor: Colors.teal,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          expandableSection(
            title: "🌡️ Temperature & Humidity",
            sensor1: buildSHTSensor(1),
            expandedSensors: List.generate(3, (i) => buildSHTSensor(i + 2)),
            icon: Icons.device_thermostat,
            color: Colors.orange,
          ),
          expandableSection(
            title: "🌧️ Raindrop Sensor",
            sensor1: buildAnalogSensor(rainData, 1, 'rain'),
            expandedSensors: List.generate(
              3,
              (i) => buildAnalogSensor(rainData, i + 2, 'rain'),
            ),
            icon: Icons.water_drop,
            color: Colors.blue,
          ),
          expandableSection(
            title: "💡 Photoresistor Sensor",
            sensor1: buildAnalogSensor(lightData, 1, 'light'),
            expandedSensors: List.generate(
              3,
              (i) => buildAnalogSensor(lightData, i + 2, 'light'),
            ),
            icon: Icons.lightbulb,
            color: Colors.amber,
          ),
        ],
      ),
    );
  }
}
