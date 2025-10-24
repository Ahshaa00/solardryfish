import 'dart:async';
import '../barrel.dart';

class SystemMonitorPage extends StatefulWidget {
  final String systemId;
  const SystemMonitorPage({required this.systemId, super.key});

  @override
  State<SystemMonitorPage> createState() => _SystemMonitorPageState();
}

class _SystemMonitorPageState extends State<SystemMonitorPage> {
  late final DatabaseReference systemRef;

  // 🎬 SCREENSHOT MODE: Set to true to use mock data
  static const bool USE_MOCK_DATA = true;  // ⚠️ Change to false for real data

  // Sensor data (NEW structure)
  Map<String, dynamic> tempHumidData = {
    "1": {},
    "2": {},
    "3": {},
    "4": {},
  };
  Map<String, dynamic> rainData = {
    "1": {},
    "2": {},
    "3": {},
    "4": {},
  };
  Map<String, dynamic> lightData = {
    "1": {},
    "2": {},
    "3": {},
    "4": {},
  };

  // Diagnostics removed - data comes directly from sensors

  // Status
  bool lidClosed = false;
  bool heaterOn = false;
  bool heaterOverride = false;
  bool manualOverride = false;  // NEW: Manual override status
  bool megaConnected = false;   // NEW: MEGA connection status
  bool esp32Connected = false;  // NEW: ESP32 connection status
  bool trayFlipped = false;
  bool fanOn = false;           // NEW: Fan status
  int batteryPct = 0;
  double batteryVolt = 0.0;
  String batteryStatus = 'OK';
  bool online = false;
  int lastUpdateTimestamp = 0;
  int lastOnlineTimestamp = 0;  // NEW: Last time system was online
  bool isDataStale = false;
  
  // Last controlled timestamps
  int lidLastControlled = 0;
  int heaterLastControlled = 0;
  int trayLastControlled = 0;
  int fanLastControlled = 0;
  
  String currentPhase = 'Idle';
  String lastAction = '';
  int remainingTime = 0;

  @override
  void initState() {
    super.initState();
    systemRef = FirebaseDatabase.instance.ref(
      'hardwareSystems/${widget.systemId}',
    );
    
    // 🎬 MOCK DATA: Initialize with perfect screenshot data
    if (USE_MOCK_DATA) {
      _initializeMockData();
      return; // Skip Firebase listeners
    }
    
    fetchSensorData();

    // Listen to entire status object for connection status updates
    systemRef.child('status').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        final statusData = event.snapshot.value as Map?;
        if (statusData != null) {
          print('🔍 Monitor: Full status update received: $statusData');
          
          // Update connection status from full status object
          if (statusData.containsKey('esp32Connected')) {
            setState(() => esp32Connected = statusData['esp32Connected'] == true);
            print('🔍 Monitor: ESP32 status updated from full status: ${statusData['esp32Connected']}');
          }
          if (statusData.containsKey('megaConnected')) {
            setState(() => megaConnected = statusData['megaConnected'] == true);
            print('🔍 Monitor: MEGA status updated from full status: ${statusData['megaConnected']}');
          }
        }
      }
    });
    
    // Listen to individual temperature sensors for real-time updates
    for (int i = 1; i <= 4; i++) {
      systemRef.child('sensors/tempHumid/$i').onValue.listen((event) {
        print('🔍 Monitor: Sensor $i listener fired - snapshot exists: ${event.snapshot.exists}, value: ${event.snapshot.value}');
        if (mounted && event.snapshot.value != null) {
          final sensorData = event.snapshot.value as Map?;
          if (sensorData != null) {
            print('🔍 Monitor: Received sensor $i data: $sensorData');
            setState(() {
              tempHumidData[i.toString()] = Map<String, dynamic>.from(sensorData);
            });
          } else {
            print('⚠️ Monitor: Sensor $i data is null after cast');
          }
        } else {
          print('⚠️ Monitor: Sensor $i snapshot value is null or not mounted');
        }
      });
    }
    
    // Listen to individual rain sensors
    for (int i = 1; i <= 4; i++) {
      systemRef.child('sensors/rain/$i').onValue.listen((event) {
        if (mounted && event.snapshot.value != null) {
          final sensorData = event.snapshot.value as Map?;
          if (sensorData != null) {
            setState(() {
              rainData[i.toString()] = Map<String, dynamic>.from(sensorData);
            });
          }
        }
      });
    }
    
    // Listen to individual light sensors
    for (int i = 1; i <= 4; i++) {
      systemRef.child('sensors/light/$i').onValue.listen((event) {
        if (mounted && event.snapshot.value != null) {
          final sensorData = event.snapshot.value as Map?;
          if (sensorData != null) {
            setState(() {
              lightData[i.toString()] = Map<String, dynamic>.from(sensorData);
            });
          }
        }
      });
    }

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

    systemRef.child('status/manualOverride').onValue.listen((event) {
      if (mounted) setState(() => manualOverride = event.snapshot.value == true);
    });

    systemRef.child('status/megaConnected').onValue.listen((event) {
      if (mounted) {
        final value = event.snapshot.value;
        print('🔍 Monitor: MEGA connection status: $value');
        setState(() => megaConnected = value == true);
      }
    });

    systemRef.child('status/trayFlipped').onValue.listen((event) {
      if (mounted) setState(() => trayFlipped = event.snapshot.value == true);
    });

    systemRef.child('sensors/battery/percentage').onValue.listen((event) {
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

    systemRef.child('sensors/battery/status').onValue.listen((event) {
      if (mounted) {
        setState(() {
          batteryStatus = event.snapshot.value?.toString() ?? 'OK';
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

    // Listen to fan status
    systemRef.child('status/fan').onValue.listen((event) {
      if (mounted) setState(() => fanOn = event.snapshot.value == true);
    });

    // Listen to ESP32 connection
    systemRef.child('status/esp32Connected').onValue.listen((event) {
      if (mounted) {
        final value = event.snapshot.value;
        print('🔍 Monitor: ESP32 connection status: $value');
        setState(() => esp32Connected = value == true);
      }
    });

    // Listen to last controlled timestamps
    systemRef.child('status/lidLastControlled').onValue.listen((event) {
      if (mounted) {
        final val = event.snapshot.value;
        setState(() => lidLastControlled = val is int ? val : int.tryParse(val.toString()) ?? 0);
      }
    });

    systemRef.child('status/heaterLastControlled').onValue.listen((event) {
      if (mounted) {
        final val = event.snapshot.value;
        setState(() => heaterLastControlled = val is int ? val : int.tryParse(val.toString()) ?? 0);
      }
    });

    systemRef.child('status/trayLastControlled').onValue.listen((event) {
      if (mounted) {
        final val = event.snapshot.value;
        setState(() => trayLastControlled = val is int ? val : int.tryParse(val.toString()) ?? 0);
      }
    });

    systemRef.child('status/fanLastControlled').onValue.listen((event) {
      if (mounted) {
        final val = event.snapshot.value;
        setState(() => fanLastControlled = val is int ? val : int.tryParse(val.toString()) ?? 0);
      }
    });

    // Listen to lastUpdate timestamp to detect stale data
    systemRef.child('status/lastUpdate').onValue.listen((event) {
      if (mounted) {
        final timestamp = event.snapshot.value;
        if (timestamp != null) {
          setState(() {
            lastUpdateTimestamp = timestamp is int ? timestamp : int.tryParse(timestamp.toString()) ?? 0;
            if (online) lastOnlineTimestamp = lastUpdateTimestamp;
            _checkDataFreshness();
          });
        }
      }
    });

    // Check data freshness every 3 seconds
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkDataFreshness();
    });

    // Fallback: Check connection status every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkConnectionStatus();
    });
  }

  void _checkDataFreshness() {
    if (lastUpdateTimestamp == 0) {
      setState(() => isDataStale = false);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = now - lastUpdateTimestamp;

    // Consider data stale if no update in last 120 seconds (increased for stability)
    final stale = difference > 120000;

    if (isDataStale != stale) {
      setState(() => isDataStale = stale);
      if (stale && online) {
        // Data is stale but online flag is still true - system likely disconnected
        setState(() => online = false);
      }
    }
  }

  void _checkConnectionStatus() async {
    try {
      // Manually fetch the current status to ensure we have the latest data
      final statusSnapshot = await systemRef.child('status').get();
      if (statusSnapshot.exists && statusSnapshot.value != null) {
        final statusData = statusSnapshot.value as Map;
        print('🔍 Monitor: Manual status check - ESP32: ${statusData['esp32Connected']}, MEGA: ${statusData['megaConnected']}');
        
        if (mounted) {
          setState(() {
            esp32Connected = statusData['esp32Connected'] == true;
            megaConnected = statusData['megaConnected'] == true;
          });
        }
      }
    } catch (e) {
      print('⚠️ Monitor: Error checking connection status: $e');
    }
  }

  // 🎬 MOCK DATA: Initialize perfect data for screenshots
  void _initializeMockData() {
    setState(() {
      // All systems online and working
      online = true;
      megaConnected = true;
      esp32Connected = true;
      
      // Status
      lidClosed = false;
      heaterOn = true;
      heaterOverride = false;
      manualOverride = false;
      trayFlipped = false;
      fanOn = true;
      
      // Battery
      batteryPct = 85;
      batteryVolt = 12.4;
      batteryStatus = 'Good';
      
      // Phase info
      currentPhase = 'Drying';
      lastAction = 'Lid opened at 10:15 AM';
      remainingTime = 180;
      
      // Timestamps
      final now = DateTime.now().millisecondsSinceEpoch;
      lastUpdateTimestamp = now;
      lastOnlineTimestamp = now;
      lidLastControlled = now - 300000; // 5 min ago
      heaterLastControlled = now - 600000; // 10 min ago
      trayLastControlled = now - 1800000; // 30 min ago
      fanLastControlled = now - 900000; // 15 min ago
      isDataStale = false;
      
      // Temperature & Humidity sensors - all working perfectly
      tempHumidData = {
        "1": {
          "connected": true,
          "working": true,
          "value": {"temp": 32.5, "hum": 45.0}
        },
        "2": {
          "connected": true,
          "working": true,
          "value": {"temp": 33.2, "hum": 43.5}
        },
        "3": {
          "connected": true,
          "working": true,
          "value": {"temp": 31.8, "hum": 46.2}
        },
        "4": {
          "connected": true,
          "working": true,
          "value": {"temp": 32.9, "hum": 44.8}
        },
      };
      
      // Rain sensors - all working
      rainData = {
        "1": {"working": true, "value": 0},
        "2": {"working": true, "value": 0},
        "3": {"working": true, "value": 0},
        "4": {"working": true, "value": 0},
      };
      
      // Light sensors - all working
      lightData = {
        "1": {"working": true, "value": 850},
        "2": {"working": true, "value": 920},
        "3": {"working": true, "value": 880},
        "4": {"working": true, "value": 905},
      };
    });
    
    print('🎬 MOCK DATA: System Monitor initialized with perfect screenshot data');
  }

  Future<void> fetchSensorData() async {
    final snapshot = await systemRef.child('sensors').get();
    final data = snapshot.value as Map?;
    if (data != null) parseSensorData(data);
  }

  void parseSensorData(Map data) {
    print('🔍 Monitor: parseSensorData called with tempHumid keys: ${(data['tempHumid'] as Map?)?.keys}');
    
    final tempHumid = {"1": {}, "2": {}, "3": {}, "4": {}};
    final rain = {"1": {}, "2": {}, "3": {}, "4": {}};
    final light = {"1": {}, "2": {}, "3": {}, "4": {}};

    // Parse tempHumid sensors (NEW structure: sensors/tempHumid/1/value/temp)
    if (data['tempHumid'] != null) {
      final tempHumidData = data['tempHumid'];
      print('🔍 Monitor: tempHumidData type: ${tempHumidData.runtimeType}, keys: ${tempHumidData is Map ? tempHumidData.keys : "not a map"}');
      
      // Handle both Map and List formats from Firebase
      if (tempHumidData is Map) {
        for (var entry in tempHumidData.entries) {
          final sensorNum = entry.key.toString();
          final sensorData = entry.value;
          if (sensorData is Map) {
            tempHumid[sensorNum] = Map<String, dynamic>.from(sensorData);
          }
        }
      } else if (tempHumidData is List) {
        for (int i = 0; i < tempHumidData.length; i++) {
          final sensorData = tempHumidData[i];
          if (sensorData != null && sensorData is Map) {
            tempHumid[(i + 1).toString()] = Map<String, dynamic>.from(sensorData);
          }
        }
      }
    }

    // Parse rain sensors (NEW structure: sensors/rain/1/value)
    if (data['rain'] != null) {
      final rainDataRaw = data['rain'];
      
      // Handle both Map and List formats from Firebase
      if (rainDataRaw is Map) {
        for (var entry in rainDataRaw.entries) {
          final sensorNum = entry.key.toString();
          final sensorData = entry.value;
          if (sensorData is Map) {
            rain[sensorNum] = Map<String, dynamic>.from(sensorData);
          }
        }
      } else if (rainDataRaw is List) {
        for (int i = 0; i < rainDataRaw.length; i++) {
          final sensorData = rainDataRaw[i];
          if (sensorData != null && sensorData is Map) {
            rain[(i + 1).toString()] = Map<String, dynamic>.from(sensorData);
          }
        }
      }
    }

    // Parse light sensors (NEW structure: sensors/light/1/value)
    if (data['light'] != null) {
      final lightDataRaw = data['light'];
      
      // Handle both Map and List formats from Firebase
      if (lightDataRaw is Map) {
        for (var entry in lightDataRaw.entries) {
          final sensorNum = entry.key.toString();
          final sensorData = entry.value;
          if (sensorData is Map) {
            light[sensorNum] = Map<String, dynamic>.from(sensorData);
          }
        }
      } else if (lightDataRaw is List) {
        for (int i = 0; i < lightDataRaw.length; i++) {
          final sensorData = lightDataRaw[i];
          if (sensorData != null && sensorData is Map) {
            light[(i + 1).toString()] = Map<String, dynamic>.from(sensorData);
          }
        }
      }
    }

    setState(() {
      tempHumidData = tempHumid;
      rainData = rain;
      lightData = light;
    });
  }

  String _formatRelativeTime(int timestamp) {
    if (timestamp == 0) return 'Never';
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp;
    
    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return '${(diff / 60000).floor()}m ago';
    if (diff < 86400000) return '${(diff / 3600000).floor()}h ago';
    return '${(diff / 86400000).floor()}d ago';
  }

  Widget _buildCompactCard({
    required String title,
    required String status,
    String? subtitle,
    required IconData icon,
    required Color color,
    required bool isConnected,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2338),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
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
    if (!online) {
      // System offline - show neutral gray status
      return sensorCard(
        title: "TEMP/HUMIDITY SENSOR $key",
        lines: [
          "System Offline",
          "No sensor data available",
        ],
        color: Colors.grey,
        icon: Icons.cloud_off,
      );
    }

    final data = Map<String, dynamic>.from(tempHumidData[key] ?? {});
    
    // Debug logging
    print('🔍 Monitor: Sensor $key data: $data');
    
    // Check if data is empty first
    if (data.isEmpty) {
      print('⚠️ Monitor: Sensor $key has empty data');
      return sensorCard(
        title: "TEMP/HUMIDITY SENSOR $key",
        lines: [
          "Status: Loading...",
          "Waiting for sensor data",
        ],
        color: Colors.grey,
        icon: Icons.hourglass_empty,
      );
    }
    
    final connectedRaw = data['connected'];
    final connected = connectedRaw == true || connectedRaw == "true";
    
    // Get working and status from sensor data itself (not diagnostics)
    final working = data['working'] == true;
    final status = data['status']?.toString() ?? 'Unknown';

    // NEW structure: data['value']['temp'] and data['value']['hum']
    final valueMap = data['value'] as Map?;
    final tempValue = valueMap?['temp'];
    final humValue = valueMap?['hum'];
    
    print('🔍 Monitor: Sensor $key - connected: $connected, working: $working, valueMap: $valueMap');
    
    // Check if sensor is truly disconnected or has invalid data
    if (!connected || valueMap == null || 
        tempValue == null || tempValue == "null" || 
        humValue == null || humValue == "null") {
      print('❌ Monitor: Sensor $key validation failed - connected: $connected, valueMap: $valueMap, temp: $tempValue, hum: $humValue');
      return sensorCard(
        title: "TEMP/HUMIDITY SENSOR $key",
        lines: [
          "Status: $status",
          "Sensor not connected or no valid data",
        ],
        color: Colors.red,
        icon: Icons.warning,
      );
    }

    final temp = tempValue is double ? tempValue : double.tryParse(tempValue.toString()) ?? 0.0;
    final hum = humValue is double ? humValue : double.tryParse(humValue.toString()) ?? 0.0;

    final lines = [
      "Temp: ${temp.toStringAsFixed(1)}°C",
      "Humidity: ${hum.toStringAsFixed(0)}%",
      "Status: $status",
      working ? "Working ✅" : "Not Working ❌",
    ];

    return sensorCard(
      title: "TEMP/HUMIDITY SENSOR $key",
      lines: lines,
      color: working ? Colors.green : Colors.orange,
      icon: working ? Icons.thermostat : Icons.warning,
    );
  }

  Widget buildAnalogSensor(Map<String, dynamic> data, int index, String type) {
    final color = type == 'rain' ? Colors.blue : Colors.amber;
    final icon = type == 'rain' ? Icons.water_drop : Icons.lightbulb;

    if (!online) {
      // System offline - show neutral gray status
      return sensorCard(
        title: "${type.toUpperCase()} SENSOR $index",
        lines: [
          "System Offline",
          "No sensor data available",
        ],
        color: Colors.grey,
        icon: Icons.cloud_off,
      );
    }

    // NEW structure: data['1']['value'], data['1']['working'], etc.
    final sensorData = data['$index'] as Map?;
    final value = sensorData?['value'] ?? 0;
    final working = sensorData?['working'] == true;
    final status = sensorData?['status']?.toString() ?? 'Unknown';
    final wetDetected = sensorData?['wetDetected'] == true;
    final brightDetected = sensorData?['brightDetected'] == true;

    final lines = [
      "Value: $value",
      "Status: $status",
      if (type == 'rain' && wetDetected) "💧 Wet Detected",
      if (type == 'light' && brightDetected) "☀️ Bright Light Detected",
      working ? "Working ✅" : "Not Working ❌",
    ];

    return sensorCard(
      title: "${type.toUpperCase()} SENSOR $index",
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
                  buildSHTSensor("1"),
                  buildSHTSensor("2"),
                  buildSHTSensor("3"),
                  buildSHTSensor("4"),
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
                border: Border.all(color: Colors.cyan.withOpacity(0.3)),
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.dashboard, color: Colors.cyan, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "System & Hardware Status",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                children: [
                  // System Connection Status
                  sensorCard(
                    title: "System Connection",
                    lines: [
                      online ? "🟢 Online" : "🔴 Offline",
                      online ? "Last update: ${_formatRelativeTime(lastUpdateTimestamp)}" : "Last seen: ${_formatRelativeTime(lastOnlineTimestamp)}",
                    ],
                    color: online ? Colors.green : Colors.red,
                    icon: online ? Icons.cloud_done : Icons.cloud_off,
                  ),
                  
                  // Controllers Row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCompactCard(
                            title: "WiFi Bridge",
                            status: esp32Connected ? "Connected" : "Disconnected",
                            icon: Icons.wifi,
                            color: esp32Connected ? Colors.green : Colors.red,
                            isConnected: esp32Connected,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCompactCard(
                            title: "Controller",
                            status: megaConnected ? "Connected" : "Disconnected",
                            icon: Icons.memory,
                            color: megaConnected ? Colors.green : Colors.red,
                            isConnected: megaConnected,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Battery & System ID
                  sensorCard(
                    title: "Battery",
                    lines: [
                      "$batteryPct% • ${batteryVolt.toStringAsFixed(1)}V",
                      "Status: $batteryStatus",
                    ],
                    color: batteryPct > 50 ? Colors.green : batteryPct > 20 ? Colors.orange : Colors.red,
                    icon: batteryPct > 80 ? Icons.battery_full : batteryPct > 50 ? Icons.battery_5_bar : Icons.battery_3_bar,
                  ),

                  sensorCard(
                    title: "System ID",
                    lines: [widget.systemId],
                    color: Colors.amber,
                    icon: Icons.tag,
                  ),

                  // Lid & Tray Row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCompactCard(
                            title: "Lid",
                            status: lidClosed ? "Closed 🔒" : "Open 🔓",
                            subtitle: "Last: ${_formatRelativeTime(lidLastControlled)}",
                            icon: Icons.door_front_door,
                            color: lidClosed ? Colors.green : Colors.orange,
                            isConnected: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCompactCard(
                            title: "Tray",
                            status: trayFlipped ? "Flipped" : "Normal",
                            subtitle: "Last: ${_formatRelativeTime(trayLastControlled)}",
                            icon: Icons.flip,
                            color: trayFlipped ? Colors.blue : Colors.grey,
                            isConnected: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Heater & Fan Row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCompactCard(
                            title: "Heater",
                            status: heaterOn ? "On 🔥" : "Off ❄️",
                            subtitle: "Last: ${_formatRelativeTime(heaterLastControlled)}",
                            icon: Icons.fireplace,
                            color: heaterOn ? Colors.red : Colors.grey,
                            isConnected: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCompactCard(
                            title: "Fan",
                            status: fanOn ? "On 💨" : "Off",
                            subtitle: "Last: ${_formatRelativeTime(fanLastControlled)}",
                            icon: Icons.air,
                            color: fanOn ? Colors.blue : Colors.grey,
                            isConnected: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Manual Override Warning (if active)
                  if (manualOverride)
                    sensorCard(
                      title: "⚠️ Manual Override Active",
                      lines: [
                        "Automatic control disabled",
                        "Auto-disables after 15 minutes",
                      ],
                      color: Colors.orange,
                      icon: Icons.lock_open,
                    ),

                  // Current Phase (if not idle)
                  if (currentPhase != 'Idle')
                    sensorCard(
                      title: "Current Phase",
                      lines: [
                        currentPhase,
                        if (remainingTime > 0) "Time remaining: ${(remainingTime / 60).floor()}h ${remainingTime % 60}m",
                        if (lastAction.isNotEmpty) "Last action: $lastAction",
                      ],
                      color: Colors.blue,
                      icon: Icons.schedule,
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
