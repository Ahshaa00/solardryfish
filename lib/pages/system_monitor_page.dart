import '../barrel.dart';

class SystemMonitorPage extends StatefulWidget {
  final String systemId;
  const SystemMonitorPage({required this.systemId, super.key});

  @override
  State<SystemMonitorPage> createState() => _SystemMonitorPageState();
}

class _SystemMonitorPageState extends State<SystemMonitorPage> {
  late final DatabaseReference systemRef;

  // Sensor data
  Map<String, dynamic> shtData = {
    "sht31_1": {},
    "sht31_2": {},
    "sht31_3": {},
    "sht31_4": {},
  };
  Map<String, dynamic> rainData = {};
  Map<String, dynamic> lightData = {};

  // Diagnostics data from ESP32
  Map<String, dynamic> shtDiagnostics = {};
  Map<String, dynamic> rainDiagnostics = {};
  Map<String, dynamic> lightDiagnostics = {};
  Map<String, dynamic> batteryDiagnostics = {};

  // Status
  bool lidClosed = false;
  bool heaterOn = false;
  bool heaterOverride = false;
  bool trayFlipped = false;
  int batteryPct = 0;
  double batteryVolt = 0.0;
  bool online = false;
  
  String currentPhase = 'Idle';
  String lastAction = '';
  int remainingTime = 0;

  @override
  void initState() {
    super.initState();
    systemRef = FirebaseDatabase.instance.ref(
      'hardwareSystems/${widget.systemId}',
    );
    fetchSensorData();
    fetchDiagnostics();

    // Listen to sensor data
    systemRef.child('sensors').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) parseSensorData(data);
    });

    // Listen to diagnostics
    systemRef.child('diagnostics').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && mounted) {
        setState(() {
          for (int i = 1; i <= 4; i++) {
            shtDiagnostics['sht31_$i'] = data['sht31_$i'] ?? {};
            rainDiagnostics['rain_$i'] = data['rain_$i'] ?? {};
            lightDiagnostics['light_$i'] = data['light_$i'] ?? {};
          }
          batteryDiagnostics = Map<String, dynamic>.from(data['battery'] ?? {});
        });
      }
    });

    // Listen to status
    systemRef.child('status/lidClosed').onValue.listen((event) {
      if (mounted) setState(() => lidClosed = event.snapshot.value == true);
    });

    systemRef.child('status/heater').onValue.listen((event) {
      if (mounted) setState(() => heaterOn = event.snapshot.value == true);
    });

    systemRef.child('status/heaterOverride').onValue.listen((event) {
      if (mounted) setState(() => heaterOverride = event.snapshot.value == true);
    });

    systemRef.child('status/trayFlipped').onValue.listen((event) {
      if (mounted) setState(() => trayFlipped = event.snapshot.value == true);
    });

    systemRef.child('status/battery').onValue.listen((event) {
      if (mounted) {
        final battery = event.snapshot.value;
        setState(() {
          batteryPct = battery is int
              ? battery
              : int.tryParse(battery.toString()) ?? 0;
        });
      }
    });

    systemRef.child('status/batteryVolt').onValue.listen((event) {
      if (mounted) {
        final volt = event.snapshot.value;
        setState(() {
          batteryVolt = volt is double
              ? volt
              : double.tryParse(volt.toString()) ?? 0.0;
        });
      }
    });

    systemRef.child('status/online').onValue.listen((event) {
      if (mounted) setState(() => online = event.snapshot.value == true);
    });

    systemRef.child('status/phase').onValue.listen((event) {
      if (mounted) setState(() => currentPhase = event.snapshot.value?.toString() ?? 'Idle');
    });

    systemRef.child('status/lastAction').onValue.listen((event) {
      if (mounted) setState(() => lastAction = event.snapshot.value?.toString() ?? '');
    });

    systemRef.child('status/remaining').onValue.listen((event) {
      if (mounted) {
        final val = event.snapshot.value;
        setState(() => remainingTime = val is int ? val : int.tryParse(val.toString()) ?? 0);
      }
    });
  }

  Future<void> fetchSensorData() async {
    final snapshot = await systemRef.child('sensors').get();
    final data = snapshot.value as Map?;
    if (data != null) parseSensorData(data);
  }

  Future<void> fetchDiagnostics() async {
    final snapshot = await systemRef.child('diagnostics').get();
    final data = snapshot.value as Map?;
    if (data != null && mounted) {
      setState(() {
        for (int i = 1; i <= 4; i++) {
          shtDiagnostics['sht31_$i'] = data['sht31_$i'] ?? {};
          rainDiagnostics['rain_$i'] = data['rain_$i'] ?? {};
          lightDiagnostics['light_$i'] = data['light_$i'] ?? {};
        }
        batteryDiagnostics = Map<String, dynamic>.from(data['battery'] ?? {});
      });
    }
  }

  void parseSensorData(Map data) {
    final sht = {"sht31_1": {}, "sht31_2": {}, "sht31_3": {}, "sht31_4": {}};
    final rain = <String, dynamic>{};
    final light = <String, dynamic>{};

    for (var entry in data.entries) {
      if (entry.key.startsWith('sht31_')) {
        final sensorMap = entry.value;
        if (sensorMap is Map) {
          sht[entry.key] = Map<String, dynamic>.from(sensorMap);
        } else {
          debugPrint("Missing or invalid data for ${entry.key}");
        }
      } else if (entry.key == 'rain' || entry.key == 'light') {
        final list = entry.value as List?;
        if (list != null) {
          final mapped = {
            for (int i = 1; i < list.length; i++) "$i": list[i] ?? 0,
          };
          if (entry.key == 'rain') {
            rain.addAll(mapped);
          } else {
            light.addAll(mapped);
          }
        }
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
    final diagnostics = Map<String, dynamic>.from(shtDiagnostics[key] ?? {});
    
    final connectedRaw = data['connected'];
    final connected = connectedRaw == true || connectedRaw == "true";
    final working = diagnostics['working'] == true;
    final diagStatus = diagnostics['status']?.toString() ?? 'Unknown';

    if (!connected || data.isEmpty) {
      return sensorCard(
        title: key.replaceAll('_', ' ').toUpperCase(),
        lines: [
          "Status: $diagStatus",
          "Sensor not connected",
        ],
        color: Colors.red,
        icon: Icons.warning,
      );
    }

    final temp = double.tryParse(data['temp'].toString()) ?? 0.0;
    final hum = double.tryParse(data['hum'].toString()) ?? 0.0;

    final lines = [
      "Temperature: ${temp.toStringAsFixed(1)} °C",
      "Humidity: ${hum.toStringAsFixed(0)} %",
      "Diagnostic: $diagStatus",
      working ? "Status: Working ✅" : "Status: Error ❌",
    ];

    return sensorCard(
      title: key.replaceAll('_', ' ').toUpperCase(),
      lines: lines,
      color: working ? Colors.green : Colors.orange,
      icon: working ? Icons.thermostat : Icons.warning,
    );
  }

  Widget buildAnalogSensor(Map<String, dynamic> data, int index, String type) {
    final value = data['$index'] ?? 0;
    final diagnosticsMap = type == 'rain' ? rainDiagnostics : lightDiagnostics;
    final diagnostics = Map<String, dynamic>.from(diagnosticsMap['${type}_$index'] ?? {});
    
    final working = diagnostics['working'] == true;
    final diagStatus = diagnostics['status']?.toString() ?? 'Unknown';
    final wetDetected = diagnostics['wetDetected'] == true;
    final brightDetected = diagnostics['brightDetected'] == true;
    
    final color = type == 'rain' ? Colors.blue : Colors.amber;
    final icon = type == 'rain' ? Icons.water_drop : Icons.lightbulb;

    final lines = [
      "Diagnostic: $diagStatus",
      if (type == 'rain' && wetDetected) "💧 Wet Detected",
      if (type == 'light' && brightDetected) "☀️ Bright Light Detected",
      working ? "Status: Working ✅" : "Status: Error ❌",
    ];

    return sensorCard(
      title: "$type Sensor $index".toUpperCase(),
      lines: lines,
      color: working ? color : Colors.grey,
      icon: working ? icon : Icons.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2235),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "System Monitor",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: const Color(0xFF141829),
      body: RefreshIndicator(
        onRefresh: fetchSensorData,
        color: Colors.amber,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Page Title
            const Text(
              'System Monitor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time hardware monitoring',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.thermostat, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Temperature & Humidity",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                children: [
                  buildSHTSensor("sht31_1"),
                  buildSHTSensor("sht31_2"),
                  buildSHTSensor("sht31_3"),
                  buildSHTSensor("sht31_4"),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.water_drop, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Raindrop Sensors",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                children: List.generate(
                  4,
                  (i) => buildAnalogSensor(rainData, i + 1, 'rain'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Photoresistor Sensors",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                children: List.generate(
                  4,
                  (i) => buildAnalogSensor(lightData, i + 1, 'light'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.settings, color: Colors.green, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Machine Status",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                children: [
                  sensorCard(
                    title: "Battery",
                    lines: [
                      "$batteryPct%",
                      "${batteryVolt.toStringAsFixed(1)}V",
                      "Diagnostic: ${batteryDiagnostics['status'] ?? 'Unknown'}",
                    ],
                    color: batteryPct > 50 ? Colors.green : Colors.red,
                    icon: Icons.battery_full,
                  ),
                  sensorCard(
                    title: "Lid Status",
                    lines: [lidClosed ? "Closed 🔒" : "Open 🔓"],
                    color: lidClosed ? Colors.green : Colors.orange,
                    icon: Icons.door_front_door,
                  ),
                  sensorCard(
                    title: "Heater Status",
                    lines: [
                      heaterOn ? "On 🔥" : "Off ❄️",
                      if (heaterOn && heaterOverride) "⚠️ Override Active",
                      if (heaterOn && !lidClosed && heaterOverride) "Lid Open - Manual Override",
                    ],
                    color: heaterOn ? Colors.red : Colors.grey,
                    icon: Icons.fireplace,
                  ),
                  sensorCard(
                    title: "Tray Status",
                    lines: [trayFlipped ? "Flipped" : "Normal Position"],
                    color: trayFlipped ? Colors.blue : Colors.grey,
                    icon: Icons.flip,
                  ),
                  if (currentPhase != 'Idle')
                    sensorCard(
                      title: "Current Phase",
                      lines: [
                        currentPhase,
                        if (remainingTime > 0) "Time: ${(remainingTime / 60).floor()}h ${remainingTime % 60}m",
                        if (lastAction.isNotEmpty) lastAction,
                      ],
                      color: Colors.blue,
                      icon: Icons.schedule,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cloud, color: Colors.purple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "System Status",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                children: [
                  statusCard("System Online", online, Icons.power),
                  sensorCard(
                    title: "System ID",
                    lines: [widget.systemId],
                    color: Colors.amber,
                    icon: Icons.tag,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
