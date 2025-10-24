import '../barrel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/schedule_service.dart';

class ScheduleScreen extends StatefulWidget {
  final String systemId;
  const ScheduleScreen({required this.systemId, super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final DatabaseReference systemRef;
  late final ScheduleService scheduleService;
  UserRole? userRole;

  // 🎬 SCREENSHOT MODE: Set to true to use mock data
  static const bool USE_MOCK_DATA = true;  // ⚠️ Change to false for real data

  final user = FirebaseAuth.instance.currentUser;
  late final String userEmail;

  int phase1Duration = 3600;
  int phase2Duration = 1800;
  int remainingSeconds = 0;
  String currentPhase = 'Phase 1';
  int batchCount = 0;
  bool isBatchActive = false;
  bool isScheduleStarting = false; // NEW: Track when schedule is starting

  bool lidOpen = false;
  bool heaterOn = false;
  bool systemOnline = false;
  int lastUpdateTimestamp = 0;
  bool isDataStale = false;

  double targetTemp = 35.0;
  double targetHum = 50.0;

  final phase1H = TextEditingController();
  final phase1M = TextEditingController();
  final phase1S = TextEditingController();
  final phase2H = TextEditingController();
  final phase2M = TextEditingController();
  final phase2S = TextEditingController();
  final tempController = TextEditingController();
  final humController = TextEditingController();

  Timer? countdownTimer;

  @override
  void initState() {
    super.initState();
    userEmail = user?.email ?? 'unknown';
    systemRef = FirebaseDatabase.instance.ref('hardwareSystems/${widget.systemId}');
    scheduleService = ScheduleService(systemRef);
    
    // 🎬 MOCK DATA: Initialize with perfect screenshot data
    if (USE_MOCK_DATA) {
      _initializeMockData();
      return; // Skip Firebase listeners
    }
    
    // Load user role
    _loadUserRole();

    // Listen to remaining time from MEGA (via ESP32/Firebase)
    systemRef.child('status/remaining').onValue.listen((event) {
      if (mounted) {
        final val = event.snapshot.value;
        setState(() {
          remainingSeconds = val is int ? val : int.tryParse(val.toString()) ?? 0;
          isBatchActive = remainingSeconds > 0;
          // Clear starting flag when we get actual remaining time
          if (remainingSeconds > 0) {
            isScheduleStarting = false;
          }
        });
      }
    });

    // Listen to phase from MEGA
    systemRef.child('status/phase').onValue.listen((event) {
      if (mounted) {
        final phase = event.snapshot.value?.toString() ?? 'Idle';
        setState(() {
          currentPhase = phase;
          // If phase is not 'Idle', schedule is active
          if (phase != 'Idle') {
            isScheduleStarting = false;
          }
        });
      }
    });

    // Listen to system online status
    systemRef.child('status/online').onValue.listen((event) {
      if (mounted) {
        setState(() => systemOnline = event.snapshot.value == true);
      }
    });

    // Listen to lastUpdate timestamp for stale detection
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
    });

    // Check data freshness every 3 seconds
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkDataFreshness();
    });

    scheduleService.listenToSchedule(
      onRemainingUpdate: (seconds) {
        // This is now redundant since we listen directly above
      },
      onPhaseUpdate: (phase) {
        // This is now redundant since we listen directly above
      },
      onBatchUpdate: (count) {
        if (mounted) setState(() => batchCount = count);
      },
      onTargetUpdate: (temp, hum) {
        if (mounted) {
          setState(() {
            targetTemp = temp;
            targetHum = hum;
            tempController.text = temp.toString();
            humController.text = hum.toString();
          });
        }
      },
    );

    scheduleService.listenToControls(
      onLidUpdate: (open) {
        if (mounted) setState(() => lidOpen = open);
      },
      onHeaterUpdate: (on) {
        if (mounted) setState(() => heaterOn = on);
      },
    );
  }

  // 🎬 MOCK DATA: Initialize perfect data for screenshots
  void _initializeMockData() {
    setState(() {
      // System online and working
      systemOnline = true;
      lidOpen = true;
      heaterOn = true;
      
      // Active batch in progress
      isBatchActive = true;
      isScheduleStarting = false;
      currentPhase = 'Phase 1: Drying';
      remainingSeconds = 5400; // 1h 30m remaining
      batchCount = 3; // 3 batches completed
      
      // Schedule durations (2 hours and 1 hour)
      phase1Duration = 7200; // 2 hours
      phase2Duration = 3600; // 1 hour
      
      // Target values
      targetTemp = 35.0;
      targetHum = 45.0;
      
      // Fresh data
      lastUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
      isDataStale = false;
      
      // Set text controllers
      phase1H.text = '2';
      phase1M.text = '0';
      phase1S.text = '0';
      phase2H.text = '1';
      phase2M.text = '0';
      phase2S.text = '0';
      tempController.text = '35.0';
      humController.text = '45.0';
    });
    
    // Mock user role with full permissions
    userRole = UserRole.owner;
    
    print('🎬 MOCK DATA: Schedule initialized with perfect screenshot data');
  }

  void _checkDataFreshness() {
    if (lastUpdateTimestamp == 0) {
      print('⚠️ Schedule: No timestamp received yet');
      setState(() => isDataStale = false);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = now - lastUpdateTimestamp;

    print('🔍 Schedule: Last update ${(difference / 1000).toStringAsFixed(1)}s ago | Online: $systemOnline | Stale: ${difference > 120000}');

    // Consider data stale if no update in last 120 seconds (increased for stability)
    final stale = difference > 120000;

    if (isDataStale != stale) {
      setState(() {
        isDataStale = stale;
        if (stale) {
          // Data is stale - mark as offline
          print('❌ Schedule: Marking system as OFFLINE (stale data)');
          systemOnline = false;
        } else if (!stale && !systemOnline) {
          // Data is fresh again - mark as online
          print('✅ Schedule: Marking system as ONLINE (fresh data)');
          systemOnline = true;
        }
      });
    }
  }

  Future<void> _loadUserRole() async {
    final role = await PermissionService.getUserRole(widget.systemId);
    print('🔐 Schedule - User Role: $role');
    print('🔐 Schedule - Can Schedule: ${role.canSchedule}');
    print('🔐 Schedule - System ID: ${widget.systemId}');
    if (mounted) {
      setState(() => userRole = role);
    }
  }

  void logAction(String message) {
    FirebaseFirestore.instance.collection('activity_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'user': userEmail,
      'systemId': widget.systemId,
      'message': message,
    });
  }

  // Removed local countdown - MEGA controls the countdown
  // App just displays the remaining time from Firebase

  void scheduleNewBatch() {
    print('🔘 Start Schedule button clicked!');
    print('🔐 User Role: $userRole');
    print('🔐 Can Schedule: ${userRole?.canSchedule}');
    print('🌐 System Online: $systemOnline');
    
    if (userRole == null || !userRole!.canSchedule) {
      print('❌ Permission denied: userRole=${userRole}, canSchedule=${userRole?.canSchedule}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You don't have permission to schedule drying sessions"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (!systemOnline) {
      print('❌ System offline: Cannot start schedule');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Cannot start schedule: System is offline')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('✅ Starting schedule...');

    final p1h = int.tryParse(phase1H.text) ?? 0;
    final p1m = int.tryParse(phase1M.text) ?? 0;
    final p1s = int.tryParse(phase1S.text) ?? 0;
    final p2h = int.tryParse(phase2H.text) ?? 0;
    final p2m = int.tryParse(phase2M.text) ?? 0;
    final p2s = int.tryParse(phase2S.text) ?? 0;

    phase1Duration = p1h * 3600 + p1m * 60 + p1s;
    phase2Duration = p2h * 3600 + p2m * 60 + p2s;

    final temp = double.tryParse(tempController.text) ?? targetTemp;
    final hum = double.tryParse(humController.text) ?? targetHum;

    // Send START_SCHEDULE command to MEGA via Firebase
    systemRef.child('controls/schedule').set('start');

    scheduleService.updateSchedule(
      phase1Duration: phase1Duration,
      phase2Duration: phase2Duration,
      batchCount: batchCount,
      temp: temp,
      hum: hum,
    );

    logAction(
      "Started drying schedule - Phase 1: $phase1Duration sec, Phase 2: $phase2Duration sec, Temp: $temp°C, Humidity: $hum%",
    );
    scheduleService.notify("Drying schedule started");
    
    print('✅ Schedule command sent to Firebase');
    
    // Set starting flag to show control panel immediately
    setState(() {
      isScheduleStarting = true;
    });
    
    // Set a timeout to clear the starting flag if no response
    Timer(const Duration(seconds: 10), () {
      if (mounted && isScheduleStarting && remainingSeconds == 0) {
        print('⚠️ Schedule: Timeout - no response from MEGA, clearing starting flag');
        setState(() {
          isScheduleStarting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule command sent but no response from system. Please check system status.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
    
    // Show success dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E2235),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('Schedule Started', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Drying schedule has been started successfully!',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Text(
                'Phase 1: ${(phase1Duration / 3600).toStringAsFixed(1)} hours',
                style: const TextStyle(color: Colors.amber, fontSize: 14),
              ),
              Text(
                'Phase 2: ${(phase2Duration / 3600).toStringAsFixed(1)} hours',
                style: const TextStyle(color: Colors.amber, fontSize: 14),
              ),
              Text(
                'Target: $temp°C, $hum%',
                style: const TextStyle(color: Colors.amber, fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
      );
    }
  }

  void stopDryingSession() {
    if (userRole == null || !userRole!.canSchedule) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You don't have permission to stop drying sessions"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (!systemOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Cannot stop schedule: System is offline')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    countdownTimer?.cancel();
    
    // Send STOP_SCHEDULE command to MEGA via Firebase
    systemRef.child('controls/schedule').set('stop');
    
    systemRef.child('schedule').update({'remaining': 0, 'phase': 'Idle'});
    logAction("Drying session manually stopped");
    scheduleService.notify("Drying session stopped");
  }

  void toggleLid() {
    final newState = lidOpen ? "close" : "open";
    scheduleService.toggleControl("lid", newState);
    logAction("Lid toggled to $newState");
    scheduleService.notify("Lid is now $newState");
  }

  void toggleHeater() {
    final newState = heaterOn ? "off" : "on";
    scheduleService.toggleControl("heater", newState);
    logAction("Heater toggled to $newState");
    scheduleService.notify("Heater is now $newState");
  }

  void triggerFlip() {
    // Send FLIP command to MEGA via Firebase
    systemRef.child('controls/mode').set('flip');
    
    logAction("Flip tray triggered");
    scheduleService.notify("Tray flip initiated");
  }

  String formatTime(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  double getProgress() {
    final total = currentPhase == 'Phase 1' ? phase1Duration : phase2Duration;
    return total > 0 ? (total - remainingSeconds) / total : 0;
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    phase1H.dispose();
    phase1M.dispose();
    phase1S.dispose();
    phase2H.dispose();
    phase2M.dispose();
    phase2S.dispose();
    tempController.dispose();
    humController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: (isBatchActive || isScheduleStarting) ? _buildControlPanel() : _buildScheduler(),
    );
  }

  Widget _buildScheduler() {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            'Schedule',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade700, Colors.amber],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.schedule, size: 32, color: Colors.black87),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Set Schedule Time',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _timeInputSection('Phase 1 Duration', phase1H, phase1M, phase1S),
        const SizedBox(height: 16),
        _timeInputSection('Phase 2 Duration', phase2H, phase2M, phase2S),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.thermostat, size: 32, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Target Conditions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(tempController, 'Target Temperature (°C)', Icons.thermostat),
        const SizedBox(height: 12),
        _buildTextField(humController, 'Target Humidity (%)', Icons.water_drop),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: scheduleNewBatch,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow),
              SizedBox(width: 8),
              Text(
                'Start Schedule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeInputSection(String title, TextEditingController h, TextEditingController m, TextEditingController s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _timeField(h, 'Hours')),
              const SizedBox(width: 8),
              Expanded(child: _timeField(m, 'Minutes')),
              const SizedBox(width: 8),
              Expanded(child: _timeField(s, 'Seconds')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      enabled: systemOnline,
      keyboardType: TextInputType.number,
      style: TextStyle(color: systemOnline ? Colors.white : Colors.grey),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        filled: true,
        fillColor: systemOnline ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      enabled: systemOnline,
      keyboardType: TextInputType.number,
      style: TextStyle(color: systemOnline ? Colors.white : Colors.grey),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: systemOnline ? Colors.amber : Colors.grey),
        filled: true,
        fillColor: systemOnline ? const Color(0xFF1E2235) : Colors.grey.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            'Schedule',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        // Timer Display
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade700, Colors.amber],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                isScheduleStarting ? 'Starting Schedule...' : 'Time Remaining',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              if (isScheduleStarting) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please wait while the system initializes...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  formatTime(remainingSeconds),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: getProgress(),
                    minHeight: 10,
                    backgroundColor: Colors.black26,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.black87),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Phase Info
        Row(
          children: [
            Expanded(
              child: _infoCard('Current Phase', currentPhase, Icons.layers, Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoCard('Batch Count', '$batchCount', Icons.inventory, Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _infoCard('Target Temp', '${targetTemp.toStringAsFixed(1)}°C', Icons.thermostat, Colors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoCard('Target Humidity', '${targetHum.toStringAsFixed(0)}%', Icons.water_drop, Colors.cyan),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Manual Controls
        const Text(
          'Manual Controls',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _controlButton(
              lidOpen ? 'Close Lid' : 'Open Lid',
              lidOpen ? Icons.door_front_door : Icons.door_front_door_outlined,
              Colors.blue,
              toggleLid,
            ),
            _controlButton(
              heaterOn ? 'Heat Off' : 'Heat On',
              Icons.thermostat,
              Colors.orange,
              toggleHeater,
            ),
            _controlButton(
              'Flip Fish',
              Icons.flip,
              Colors.purple,
              triggerFlip,
            ),
            _controlButton(
              'Stop Session',
              Icons.stop,
              Colors.red,
              stopDryingSession,
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _controlButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
