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

  final user = FirebaseAuth.instance.currentUser;
  late final String userEmail;

  int phase1Duration = 3600;
  int phase2Duration = 1800;
  int remainingSeconds = 0;
  String currentPhase = 'Phase 1';
  int batchCount = 0;
  bool isBatchActive = false;

  bool lidOpen = false;
  bool heaterOn = false;
  bool systemOnline = false;

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
    
    // Load user role
    _loadUserRole();

    // Listen to remaining time from MEGA (via ESP32/Firebase)
    systemRef.child('status/remaining').onValue.listen((event) {
      if (mounted) {
        final val = event.snapshot.value;
        setState(() {
          remainingSeconds = val is int ? val : int.tryParse(val.toString()) ?? 0;
          isBatchActive = remainingSeconds > 0;
        });
      }
    });

    // Listen to phase from MEGA
    systemRef.child('status/phase').onValue.listen((event) {
      if (mounted) {
        setState(() => currentPhase = event.snapshot.value?.toString() ?? 'Idle');
      }
    });

    // Listen to system online status
    systemRef.child('status/online').onValue.listen((event) {
      if (mounted) {
        setState(() => systemOnline = event.snapshot.value == true);
      }
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

  Future<void> _loadUserRole() async {
    final role = await PermissionService.getUserRole(widget.systemId);
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
    if (userRole == null || !userRole!.canSchedule) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You don't have permission to schedule drying sessions"),
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
              Expanded(child: Text('Cannot start schedule: System is offline')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
      child: isBatchActive ? _buildControlPanel() : _buildScheduler(),
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
              const Text(
                'Time Remaining',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
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
