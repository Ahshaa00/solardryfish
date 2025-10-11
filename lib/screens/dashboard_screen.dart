import 'dart:async';
import '../barrel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/login_page.dart';

class DashboardScreen extends StatefulWidget {
  final String systemId;
  const DashboardScreen({required this.systemId, super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DatabaseReference systemRef;
  UserRole? userRole;

  bool lidClosed = false;
  
  // 4 SHT31 sensors
  List<double> temps = [0.0, 0.0, 0.0, 0.0];
  List<double> hums = [0.0, 0.0, 0.0, 0.0];
  List<bool> shtConnected = [false, false, false, false];
  
  // Average temp and humidity for dashboard display
  double avgTemp = 0.0;
  double avgHum = 0.0;
  int workingSensors = 0;
  
  // Additional sensors
  bool raindropConnected = false;
  int raindropValue = 0;
  bool ldrConnected = false;
  int ldrValue = 0;
  
  int batteryPct = 0;
  bool isCharging = false;
  
  // Status
  String currentPhase = 'Idle';
  String lastAction = 'System Started';
  int remainingTime = 0;
  
  // Safety
  bool safetyOK = true;
  String safetyMessage = 'All systems normal';
  bool hasError = false;
  String errorCode = '';
  String errorMessage = '';
  bool online = false;

  // Stream subscriptions for proper disposal
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    systemRef = FirebaseDatabase.instance.ref(
      'hardwareSystems/${widget.systemId}',
    );
    
    // Load user role
    _loadUserRole();

    // Listen to status changes
    _subscriptions.add(
      systemRef.child('status/lidClosed').onValue.listen((event) {
        if (mounted) setState(() => lidClosed = event.snapshot.value == true);
      }),
    );

    _subscriptions.add(
      systemRef.child('status/online').onValue.listen((event) {
        if (mounted) setState(() => online = event.snapshot.value == true);
      }),
    );

    _subscriptions.add(
      systemRef.child('status/phase').onValue.listen((event) {
        if (mounted) setState(() => currentPhase = event.snapshot.value?.toString() ?? 'Idle');
      }),
    );

    _subscriptions.add(
      systemRef.child('status/lastAction').onValue.listen((event) {
        if (mounted) setState(() => lastAction = event.snapshot.value?.toString() ?? '');
      }),
    );

    _subscriptions.add(
      systemRef.child('status/remaining').onValue.listen((event) {
        if (mounted) {
          final val = event.snapshot.value;
          setState(() => remainingTime = val is int ? val : int.tryParse(val.toString()) ?? 0);
        }
      }),
    );

    // Listen to all 4 SHT31 sensors
    for (int i = 0; i < 4; i++) {
      final sensorNum = i + 1;
      
      _subscriptions.add(
        systemRef.child('sensors/sht31_$sensorNum/temp').onValue.listen((event) {
          if (mounted) {
            final temp = event.snapshot.value;
            setState(() {
              temps[i] = temp is double
                  ? temp
                  : double.tryParse(temp.toString()) ?? 0.0;
              _calculateAverages();
            });
          }
        }),
      );

      _subscriptions.add(
        systemRef.child('sensors/sht31_$sensorNum/hum').onValue.listen((event) {
          if (mounted) {
            final hum = event.snapshot.value;
            setState(() {
              hums[i] = hum is double
                  ? hum
                  : double.tryParse(hum.toString()) ?? 0.0;
              _calculateAverages();
            });
          }
        }),
      );

      _subscriptions.add(
        systemRef.child('sensors/sht31_$sensorNum/connected').onValue.listen((event) {
          if (mounted) {
            setState(() {
              shtConnected[i] = event.snapshot.value == true;
              _calculateAverages();
            });
          }
        }),
      );
    }

    // Battery
    _subscriptions.add(
      systemRef.child('status/battery').onValue.listen((event) {
        if (mounted) {
          final battery = event.snapshot.value;
          setState(() {
            batteryPct = battery is int
                ? battery
                : int.tryParse(battery.toString()) ?? 0;
          });
        }
      }),
    );

    _subscriptions.add(
      systemRef.child('status/isCharging').onValue.listen((event) {
        if (mounted) {
          setState(() {
            isCharging = event.snapshot.value == true;
          });
        }
      }),
    );

    // Raindrop sensor
    _subscriptions.add(
      systemRef.child('sensors/raindrop/connected').onValue.listen((event) {
        if (mounted) {
          setState(() {
            raindropConnected = event.snapshot.value == true;
          });
        }
      }),
    );

    _subscriptions.add(
      systemRef.child('sensors/raindrop/value').onValue.listen((event) {
        if (mounted) {
          final val = event.snapshot.value;
          setState(() {
            raindropValue = val is int ? val : int.tryParse(val.toString()) ?? 0;
          });
        }
      }),
    );

    // LDR sensor
    _subscriptions.add(
      systemRef.child('sensors/ldr/connected').onValue.listen((event) {
        if (mounted) {
          setState(() {
            ldrConnected = event.snapshot.value == true;
          });
        }
      }),
    );

    _subscriptions.add(
      systemRef.child('sensors/ldr/value').onValue.listen((event) {
        if (mounted) {
          final val = event.snapshot.value;
          setState(() {
            ldrValue = val is int ? val : int.tryParse(val.toString()) ?? 0;
          });
        }
      }),
    );

    // Safety status
    _subscriptions.add(
      systemRef.child('status/safetyOK').onValue.listen((event) {
        if (mounted) setState(() => safetyOK = event.snapshot.value == true);
      }),
    );

    _subscriptions.add(
      systemRef.child('status/safetyMessage').onValue.listen((event) {
        if (mounted) setState(() => safetyMessage = event.snapshot.value?.toString() ?? '');
      }),
    );

    // Error status
    _subscriptions.add(
      systemRef.child('status/hasError').onValue.listen((event) {
        if (mounted) setState(() => hasError = event.snapshot.value == true);
      }),
    );

    _subscriptions.add(
      systemRef.child('status/errorCode').onValue.listen((event) {
        if (mounted) setState(() => errorCode = event.snapshot.value?.toString() ?? '');
      }),
    );

    _subscriptions.add(
      systemRef.child('status/errorMessage').onValue.listen((event) {
        if (mounted) setState(() => errorMessage = event.snapshot.value?.toString() ?? '');
      }),
    );
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final role = await PermissionService.getUserRole(widget.systemId);
    if (mounted) {
      setState(() => userRole = role);
    }
  }

  void _calculateAverages() {
    // Calculate average temp and humidity from working sensors only
    double totalTemp = 0.0;
    double totalHum = 0.0;
    int working = 0;
    
    for (int i = 0; i < 4; i++) {
      if (shtConnected[i]) {
        totalTemp += temps[i];
        totalHum += hums[i];
        working++;
      }
    }
    
    workingSensors = working;
    if (working > 0) {
      avgTemp = totalTemp / working;
      avgHum = totalHum / working;
    } else {
      avgTemp = 0.0;
      avgHum = 0.0;
    }
  }

  Future<void> toggleLid() async {
    if (userRole == null || !userRole!.canControl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You don't have permission to control this system"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    systemRef.child('controls/mode').set(lidClosed ? 'open' : 'close');
  }


  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Page Title
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          
          // System ID Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade700, Colors.amber],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny, size: 32, color: Colors.black87),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'System ID',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        widget.systemId,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // View-Only Banner
          if (userRole != null && !userRole!.canControl)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'View-Only Access',
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You have ${userRole!.displayName} role. Contact the owner for control permissions.',
                          style: const TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Error Banner
          if (hasError)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          errorCode,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),

          // Safety Warning
          if (!safetyOK)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      safetyMessage,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),


          // Current Phase
          if (currentPhase != 'Idle')
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        currentPhase,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  if (remainingTime > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Time Remaining: ${(remainingTime / 60).floor()}h ${remainingTime % 60}m',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  if (lastAction.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      lastAction,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),

          // Controls Section
          _sectionTitle('Controls'),
          const SizedBox(height: 12),
          _controlCard(
            'Lid',
            !lidClosed,
            Icons.door_front_door,
            toggleLid,
          ),
          const SizedBox(height: 24),

          // Sensors Section
          _sectionTitle('Sensors'),
          const SizedBox(height: 12),
          
          // Temperature & Humidity Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2235),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: workingSensors > 0 ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.thermostat, color: Colors.amber, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Temperature & Humidity',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Average Values
                if (workingSensors > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avg Temperature',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${avgTemp.toStringAsFixed(1)}°C',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avg Humidity',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${avgHum.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Status message for temp/humidity sensors
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: workingSensors == 4 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: workingSensors == 4 
                          ? Colors.green.withOpacity(0.3) 
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        workingSensors == 4 ? Icons.check_circle : Icons.warning,
                        color: workingSensors == 4 ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          workingSensors == 4
                              ? 'All sensors working'
                              : workingSensors == 0
                                  ? 'All sensors are not working'
                                  : '${4 - workingSensors} ${4 - workingSensors == 1 ? 'sensor is' : 'sensors are'} not working',
                          style: TextStyle(
                            color: workingSensors == 4 ? Colors.green : Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Raindrop Sensor Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2235),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: raindropConnected ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.water_drop, color: Colors.blue, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Raindrop Sensor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Status message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: raindropConnected 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: raindropConnected 
                          ? Colors.green.withOpacity(0.3) 
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        raindropConnected ? Icons.check_circle : Icons.warning,
                        color: raindropConnected ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          raindropConnected ? 'Sensor working' : 'Sensor is not working',
                          style: TextStyle(
                            color: raindropConnected ? Colors.green : Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // LDR Sensor Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2235),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ldrConnected ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.yellow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.light_mode, color: Colors.yellow, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Light Sensor (LDR)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Status message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ldrConnected 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ldrConnected 
                          ? Colors.green.withOpacity(0.3) 
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        ldrConnected ? Icons.check_circle : Icons.warning,
                        color: ldrConnected ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ldrConnected ? 'Sensor working' : 'Sensor is not working',
                          style: TextStyle(
                            color: ldrConnected ? Colors.green : Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // System Status Section
          _sectionTitle('System Status'),
          const SizedBox(height: 12),
          
          // System Online Status
          _statusCard(
            'System Status',
            online ? 'Online' : 'Offline',
            online ? Icons.cloud_done : Icons.cloud_off,
            online ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 12),
          
          // Battery Status
          _statusCard(
            'Battery',
            '$batteryPct% ${isCharging ? "(Charging)" : ""}',
            isCharging 
                ? Icons.battery_charging_full 
                : batteryPct > 80 ? Icons.battery_full 
                : batteryPct > 50 ? Icons.battery_5_bar 
                : batteryPct > 20 ? Icons.battery_3_bar 
                : Icons.battery_1_bar,
            isCharging 
                ? Colors.blue 
                : batteryPct > 50 ? Colors.green 
                : batteryPct > 20 ? Colors.orange 
                : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _controlCard(
    String label,
    bool state,
    IconData icon,
    VoidCallback onToggle,
  ) {
    return GestureDetector(
      onTap: online ? onToggle : null,
      child: Opacity(
        opacity: online ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: state ? Colors.amber : const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: state ? Colors.amber.shade700 : Colors.grey.shade700,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: state ? Colors.black87 : Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: state ? Colors.black87 : Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state ? 'ON' : 'OFF',
                style: TextStyle(
                  color: state ? Colors.black54 : Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sensorCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
