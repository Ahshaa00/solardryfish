import 'dart:async';
import '../barrel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/login_page.dart';
import '../widgets/connection_status_widget.dart';

class DashboardScreen extends StatefulWidget {
  final String systemId;
  const DashboardScreen({required this.systemId, super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DatabaseReference systemRef;
  UserRole? userRole;

  // 🎬 SCREENSHOT MODE: Set to true to use mock data for all sensors/controllers
  static const bool USE_MOCK_DATA = true;  // ⚠️ Change to false for real data

  bool lidClosed = false;
  bool manualOverride = false;  // NEW: Manual override status
  bool megaConnected = false;   // NEW: MEGA connection status
  
  // 4 SHT31 sensors
  List<double> temps = [0.0, 0.0, 0.0, 0.0];
  List<double> hums = [0.0, 0.0, 0.0, 0.0];
  List<bool> shtConnected = [false, false, false, false];
  List<bool> shtWorking = [false, false, false, false];  // Track working status separately
  
  // Average temp and humidity for dashboard display
  double avgTemp = 0.0;
  double avgHum = 0.0;
  int workingSensors = 0;
  
  // Rain sensors (4 sensors)
  List<bool> rainWorking = [false, false, false, false];
  int workingRainSensors = 0;
  
  // Light sensors (4 sensors)
  List<bool> lightWorking = [false, false, false, false];
  int workingLightSensors = 0;
  
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
  int lastUpdateTimestamp = 0;
  bool isDataStale = false;

  // Stream subscriptions for proper disposal
  final List<StreamSubscription> _subscriptions = [];

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

    // Listen to all 4 SHT31 sensors (NEW structure: sensors/tempHumid/1/value/temp)
    for (int i = 0; i < 4; i++) {
      final sensorNum = i + 1;
      
      _subscriptions.add(
        systemRef.child('sensors/tempHumid/$sensorNum/value/temp').onValue.listen((event) {
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
        systemRef.child('sensors/tempHumid/$sensorNum/value/hum').onValue.listen((event) {
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
        systemRef.child('sensors/tempHumid/$sensorNum/connected').onValue.listen((event) {
          if (mounted) {
            setState(() {
              shtConnected[i] = event.snapshot.value == true;
              _calculateAverages();
            });
          }
        }),
      );

      _subscriptions.add(
        systemRef.child('sensors/tempHumid/$sensorNum/working').onValue.listen((event) {
          if (mounted) {
            setState(() {
              shtWorking[i] = event.snapshot.value == true;
              _calculateAverages();
            });
          }
        }),
      );
    }

    // Battery (NEW structure: sensors/battery/percentage)
    _subscriptions.add(
      systemRef.child('sensors/battery/percentage').onValue.listen((event) {
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
      systemRef.child('sensors/battery/charging').onValue.listen((event) {
        if (mounted) {
          setState(() {
            isCharging = event.snapshot.value == true;
          });
        }
      }),
    );

    // NEW: Listen to manual override status
    _subscriptions.add(
      systemRef.child('status/manualOverride').onValue.listen((event) {
        if (mounted) {
          setState(() {
            manualOverride = event.snapshot.value == true;
          });
        }
      }),
    );

    // NEW: Listen to MEGA connection status
    _subscriptions.add(
      systemRef.child('status/megaConnected').onValue.listen((event) {
        if (mounted) {
          setState(() {
            megaConnected = event.snapshot.value == true;
          });
        }
      }),
    );

    // Listen to all 4 Rain sensors
    for (int i = 0; i < 4; i++) {
      final sensorNum = i + 1;
      _subscriptions.add(
        systemRef.child('sensors/rain/$sensorNum/working').onValue.listen((event) {
          if (mounted) {
            setState(() {
              rainWorking[i] = event.snapshot.value == true;
              workingRainSensors = rainWorking.where((w) => w).length;
            });
          }
        }),
      );
    }

    // Listen to all 4 Light sensors
    for (int i = 0; i < 4; i++) {
      final sensorNum = i + 1;
      _subscriptions.add(
        systemRef.child('sensors/light/$sensorNum/working').onValue.listen((event) {
          if (mounted) {
            setState(() {
              lightWorking[i] = event.snapshot.value == true;
              workingLightSensors = lightWorking.where((w) => w).length;
            });
          }
        }),
      );
    }

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

    // Listen to lastUpdate timestamp to detect stale data
    _subscriptions.add(
      systemRef.child('status/lastUpdate').onValue.listen((event) {
        if (mounted) {
          final timestamp = event.snapshot.value;
          if (timestamp != null) {
            setState(() {
              lastUpdateTimestamp = timestamp is int ? timestamp : int.tryParse(timestamp.toString()) ?? 0;
              _checkDataFreshness();
            });
          }
        }
      }),
    );

    // Check data freshness every 3 seconds
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkDataFreshness();
    });
  }

  // 🎬 MOCK DATA: Initialize perfect data for screenshots
  void _initializeMockData() {
    setState(() {
      // System status - all online and working
      online = true;
      megaConnected = true;
      lidClosed = false;
      manualOverride = false;
      
      // Current operation
      currentPhase = 'Drying';
      lastAction = 'Lid opened at 10:15 AM';
      remainingTime = 180; // 3 hours remaining
      
      // All 4 temperature & humidity sensors working perfectly
      temps = [32.5, 33.2, 31.8, 32.9];
      hums = [45.0, 43.5, 46.2, 44.8];
      shtConnected = [true, true, true, true];
      shtWorking = [true, true, true, true];
      
      // All 4 rain sensors working
      rainWorking = [true, true, true, true];
      workingRainSensors = 4;
      
      // All 4 light sensors working
      lightWorking = [true, true, true, true];
      workingLightSensors = 4;
      
      // Battery at good level and charging
      batteryPct = 85;
      isCharging = true;
      
      // Safety - all good
      safetyOK = true;
      safetyMessage = 'All systems normal';
      hasError = false;
      errorCode = '';
      errorMessage = '';
      
      // Fresh data
      lastUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
      isDataStale = false;
      
      // Calculate averages
      _calculateAverages();
    });
    
    // Mock user role with full control
    userRole = UserRole.owner;
    
    print('🎬 MOCK DATA: Dashboard initialized with perfect screenshot data');
  }

  void _checkDataFreshness() {
    if (lastUpdateTimestamp == 0) {
      print('⚠️ Dashboard: No timestamp received yet');
      setState(() => isDataStale = false);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final lastUpdate = DateTime.fromMillisecondsSinceEpoch(lastUpdateTimestamp);
    final difference = now - lastUpdateTimestamp;

    print('🔍 Dashboard: Last update ${(difference / 1000).toStringAsFixed(1)}s ago | Online: $online | Stale: ${difference > 120000}');

    // Consider data stale if no update in last 120 seconds (increased for stability)
    final stale = difference > 120000;

    if (isDataStale != stale) {
      setState(() {
        isDataStale = stale;
        if (stale) {
          // Data is stale - mark as offline
          print('❌ Dashboard: Marking system as OFFLINE (stale data)');
          online = false;
        } else if (!stale && !online) {
          // Data is fresh again - mark as online
          print('✅ Dashboard: Marking system as ONLINE (fresh data)');
          online = true;
        }
      });
    }
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
    print('🔐 Dashboard - User Role: $role');
    print('🔐 Dashboard - Can Control: ${role.canControl}');
    print('🔐 Dashboard - System ID: ${widget.systemId}');
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
      // Sensor must be both connected AND working to count
      if (shtConnected[i] && shtWorking[i]) {
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
    print('🔘 Lid button clicked!');
    print('🔐 User Role: $userRole');
    print('🔐 Can Control: ${userRole?.canControl}');
    print('🌐 Online: $online');
    
    if (userRole == null || !userRole!.canControl) {
      print('❌ Permission denied: userRole=${userRole}, canControl=${userRole?.canControl}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You don't have permission to control this system"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final newMode = lidClosed ? 'open' : 'close';
    print('📤 Sending lid command: $newMode');
    await systemRef.child('controls/mode').set(newMode);
    print('✅ Lid command sent successfully');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lid ${newMode == "open" ? "opening" : "closing"} command sent'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // NEW: Toggle manual override
  Future<void> toggleManualOverride() async {
    print('🔓 Manual Override button clicked!');
    print('🔐 User Role: $userRole');
    
    if (userRole == null || !userRole!.canControl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You don't have permission to control this system"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final newState = manualOverride ? 'disable' : 'enable';
    print('📤 Sending manual override command: $newState');
    await systemRef.child('controls/override').set(newState);
    print('✅ Manual override command sent successfully');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            manualOverride 
              ? '🔒 Manual Override DISABLED' 
              : '🔓 Manual Override ENABLED - Auto control disabled'
          ),
          backgroundColor: manualOverride ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
          
          // Manual Override Warning Banner
          if (manualOverride)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_open, color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔓 Manual Override Active',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Automatic control disabled • Auto-disables after 15 min',
                          style: TextStyle(
                            color: Colors.orange.shade300,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          _controlCard(
            'Lid',
            !lidClosed,
            Icons.door_front_door,
            toggleLid,
          ),
          const SizedBox(height: 12),
          
          // NEW: Manual Override Control
          _controlCard(
            'Manual Override',
            manualOverride,
            manualOverride ? Icons.lock : Icons.lock_open,
            toggleManualOverride,
            subtitle: manualOverride 
              ? 'Tap to disable' 
              : 'Tap to enable - Disables auto control',
            color: manualOverride ? Colors.orange : Colors.blue,
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
                    color: !online
                        ? Colors.grey.withOpacity(0.1)
                        : workingSensors == 4 
                            ? Colors.green.withOpacity(0.1) 
                            : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: !online
                          ? Colors.grey.withOpacity(0.3)
                          : workingSensors == 4 
                              ? Colors.green.withOpacity(0.3) 
                              : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        !online 
                            ? Icons.cloud_off
                            : workingSensors == 4 ? Icons.check_circle : Icons.warning,
                        color: !online
                            ? Colors.grey
                            : workingSensors == 4 ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          !online
                              ? 'System offline - No sensor data'
                              : workingSensors == 4
                                  ? 'All sensors working'
                                  : workingSensors == 0
                                      ? 'All sensors are not working'
                                      : '${4 - workingSensors} ${4 - workingSensors == 1 ? 'sensor is' : 'sensors are'} not working',
                          style: TextStyle(
                            color: !online
                                ? Colors.grey
                                : workingSensors == 4 ? Colors.green : Colors.red,
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
          
          // Other Sensors - Compact Status Row
          Row(
            children: [
              // Rain Sensors Status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2235),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: workingRainSensors == 4 
                          ? Colors.green.withOpacity(0.3) 
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.water_drop,
                        color: !online ? Colors.grey : (workingRainSensors == 4 ? Colors.blue : Colors.orange),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rain Sensors',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!online)
                        Text(
                          'Offline',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$workingRainSensors',
                              style: TextStyle(
                                color: workingRainSensors == 4 ? Colors.green : Colors.orange,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '/4',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Text(
                        !online ? 'System Offline' : (workingRainSensors == 4 ? 'All Online' : 'Some Offline'),
                        style: TextStyle(
                          color: !online ? Colors.grey.shade600 : (workingRainSensors == 4 ? Colors.green : Colors.orange),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Light Sensors Status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2235),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: workingLightSensors == 4 
                          ? Colors.green.withOpacity(0.3) 
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.light_mode,
                        color: !online ? Colors.grey : (workingLightSensors == 4 ? Colors.yellow : Colors.orange),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Light Sensors',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!online)
                        Text(
                          'Offline',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$workingLightSensors',
                              style: TextStyle(
                                color: workingLightSensors == 4 ? Colors.green : Colors.orange,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '/4',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Text(
                        !online ? 'System Offline' : (workingLightSensors == 4 ? 'All Online' : 'Some Offline'),
                        style: TextStyle(
                          color: !online ? Colors.grey.shade600 : (workingLightSensors == 4 ? Colors.green : Colors.orange),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
            !online ? 'Offline' : '$batteryPct% ${isCharging ? "(Charging)" : ""}',
            !online 
                ? Icons.battery_unknown
                : isCharging 
                    ? Icons.battery_charging_full 
                    : batteryPct > 80 ? Icons.battery_full 
                    : batteryPct > 50 ? Icons.battery_5_bar 
                    : batteryPct > 20 ? Icons.battery_3_bar 
                    : Icons.battery_1_bar,
            !online
                ? Colors.grey
                : isCharging 
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
    VoidCallback onToggle, {
    String? subtitle,
    Color? color,
  }) {
    final activeColor = color ?? Colors.amber;
    final displaySubtitle = subtitle ?? (state ? 'ON' : 'OFF');
    
    return GestureDetector(
      onTap: online ? () {
        print('👆 Control card tapped: $label | Online: $online');
        onToggle();
      } : null,
      child: Opacity(
        opacity: online ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: state ? activeColor : const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: state ? activeColor.withOpacity(0.7) : Colors.grey.shade700,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: state ? Colors.white : Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: state ? Colors.white : Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                displaySubtitle,
                style: TextStyle(
                  color: state ? Colors.white70 : Colors.grey.shade500,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
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
