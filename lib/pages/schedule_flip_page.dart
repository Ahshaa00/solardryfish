import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/schedule_service.dart';
import '../services/automation_service.dart';

class ScheduleFlipPage extends StatefulWidget {
  final String systemId;
  const ScheduleFlipPage({required this.systemId, super.key});

  @override
  State<ScheduleFlipPage> createState() => _ScheduleFlipPageState();
}

class _ScheduleFlipPageState extends State<ScheduleFlipPage> {
  late final DatabaseReference systemRef;
  late final ScheduleService scheduleService;
  late final AutomationService automationService;

  int phase1Duration = 3600;
  int phase2Duration = 1800;
  int remainingSeconds = 0;
  String currentPhase = 'Phase 1';
  int batchCount = 0;
  bool isBatchActive = false;

  bool lidOpen = false;
  bool heaterOn = false;

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
    systemRef = FirebaseDatabase.instance.ref(
      'hardwareSystems/${widget.systemId}',
    );
    scheduleService = ScheduleService(systemRef);
    automationService = AutomationService(systemRef);

    scheduleService.listenToSchedule(
      onRemainingUpdate: (seconds) {
        setState(() {
          remainingSeconds = seconds;
          isBatchActive = seconds > 0;
        });
        _startCountdown();
      },
      onPhaseUpdate: (phase) => setState(() => currentPhase = phase),
      onBatchUpdate: (count) => setState(() => batchCount = count),
      onTargetUpdate: (temp, hum) {
        setState(() {
          targetTemp = temp;
          targetHum = hum;
          tempController.text = temp.toString();
          humController.text = hum.toString();
        });
      },
    );

    scheduleService.listenToControls(
      onLidUpdate: (open) => setState(() => lidOpen = open),
      onHeaterUpdate: (on) => setState(() => heaterOn = on),
    );
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    if (remainingSeconds > 0) {
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (remainingSeconds <= 1) {
          timer.cancel();
          _handlePhaseTransition();
        } else {
          setState(() => remainingSeconds--);
          systemRef.child('schedule/remaining').set(remainingSeconds);
        }
      });
    }
  }

  void _handlePhaseTransition() {
    if (currentPhase == 'Phase 1') {
      systemRef.child('schedule').update({
        'phase': 'Phase 2',
        'remaining': phase2Duration,
      });
      scheduleService.log("Auto-switched to Phase 2");
      scheduleService.notify("Drying session flipped to Phase 2");
    } else {
      systemRef.child('schedule/remaining').set(0);
      scheduleService.log("Drying session completed");
      scheduleService.notify("Drying session completed");
    }
  }

  void scheduleNewBatch() {
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

    scheduleService.updateSchedule(
      phase1Duration: phase1Duration,
      phase2Duration: phase2Duration,
      batchCount: batchCount,
      temp: temp,
      hum: hum,
    );

    scheduleService.log(
      "Scheduled new batch with Phase 1: $phase1Duration sec, Phase 2: $phase2Duration sec, Temp: $temp°C, Humidity: $hum%",
    );
    scheduleService.notify("New drying batch scheduled");
  }

  void stopDryingSession() {
    countdownTimer?.cancel();
    systemRef.child('schedule').update({'remaining': 0, 'phase': 'Phase 1'});
    scheduleService.log("Drying session manually stopped");
    scheduleService.notify("Drying session stopped");
  }

  void toggleLid() {
    final newState = lidOpen ? "close" : "open";
    scheduleService.toggleControl("lid", newState);
    scheduleService.log("Lid toggled to $newState");
    scheduleService.notify("Lid is now $newState");
  }

  void toggleHeater() {
    final newState = heaterOn ? "off" : "on";
    scheduleService.toggleControl("heater", newState);
    scheduleService.log("Heater toggled to $newState");
    scheduleService.notify("Heater is now $newState");
  }

  void triggerFlip() {
    scheduleService.toggleControl("flip", "flipping");
    scheduleService.log("Flip triggered");

    if (currentPhase == 'Phase 1') {
      systemRef.child('schedule').update({
        'phase': 'Phase 2',
        'remaining': phase2Duration,
      });
      scheduleService.log("Manually flipped to Phase 2");
      scheduleService.notify("Manually flipped to Phase 2");
    } else {
      systemRef.child('schedule/remaining').set(0);
      scheduleService.log("Drying session ended after Phase 2");
      scheduleService.notify("Drying session ended");
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Schedule Flip")),
      backgroundColor: const Color(0xFF141829),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isBatchActive ? _buildControlPanel() : _buildScheduler(),
      ),
    );
  }

  Widget _buildScheduler() {
    return ListView(
      children: [
        const Text(
          "Set Schedule Time",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text("Phase 1 Duration (H:M:S)"),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: phase1H,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Hours"),
              ),
            ),
            Expanded(
              child: TextField(
                controller: phase1M,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Minutes"),
              ),
            ),
            Expanded(
              child: TextField(
                controller: phase1S,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Seconds"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text("Phase 2 Duration (H:M:S)"),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: phase2H,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Hours"),
              ),
            ),
            Expanded(
              child: TextField(
                controller: phase2M,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Minutes"),
              ),
            ),
            Expanded(
              child: TextField(
                controller: phase2S,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Seconds"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          "Set Target Conditions",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: tempController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Target Temperature (°C)",
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: humController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Target Humidity (%)"),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: scheduleNewBatch,
          icon: const Icon(Icons.schedule),
          label: const Text("Schedule New Batch"),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return ListView(
      children: [
        Text(
          "Remaining Time: ${formatTime(remainingSeconds)}",
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: getProgress(), minHeight: 8),
        const SizedBox(height: 10),
        Text("Current Phase: $currentPhase"),
        const SizedBox(height: 10),
        Text("Batch Count: $batchCount"),
        const SizedBox(height: 10),
        Text("Target Temperature: ${targetTemp.toStringAsFixed(1)}°C"),
        Text("Target Humidity: ${targetHum.toStringAsFixed(0)}%"),
        const Divider(height: 30),
        const Text(
          "Manual Controls",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton(
              onPressed: toggleLid,
              child: Text(lidOpen ? "Close Lid" : "Open Lid"),
            ),
            ElevatedButton(
              onPressed: toggleHeater,
              child: Text(heaterOn ? "Heat Off" : "Heat On"),
            ),
            ElevatedButton(
              onPressed: triggerFlip,
              child: const Text("Flip Fish"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: stopDryingSession,
              child: const Text("Stop Drying Session"),
            ),
          ],
        ),
      ],
    );
  }
}
