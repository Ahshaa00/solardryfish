import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ScheduleFlipPage extends StatefulWidget {
  const ScheduleFlipPage({super.key});

  @override
  State<ScheduleFlipPage> createState() => _ScheduleFlipPageState();
}

class _ScheduleFlipPageState extends State<ScheduleFlipPage> {
  final dbRef = FirebaseDatabase.instance.ref();

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
    _listenToSchedule();
    _listenToControls();
  }

  void _listenToSchedule() {
    dbRef.child('schedule/remaining').onValue.listen((event) {
      final val = event.snapshot.value;
      final seconds = val is int ? val : int.tryParse(val.toString()) ?? 0;
      setState(() {
        remainingSeconds = seconds;
        isBatchActive = seconds > 0;
      });
      _startCountdown();
    });

    dbRef.child('schedule/phase').onValue.listen((event) {
      setState(() {
        currentPhase = event.snapshot.value?.toString() ?? 'Phase 1';
      });
    });

    dbRef.child('schedule/batchCount').onValue.listen((event) {
      final val = event.snapshot.value;
      setState(() {
        batchCount = val is int ? val : int.tryParse(val.toString()) ?? 0;
      });
    });

    dbRef.child('schedule/targets').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          targetTemp = double.tryParse(data['temp'].toString()) ?? 35.0;
          targetHum = double.tryParse(data['hum'].toString()) ?? 50.0;
          tempController.text = targetTemp.toString();
          humController.text = targetHum.toString();
        });
      }
    });
  }

  void _listenToControls() {
    dbRef.child('controls/lid').onValue.listen((event) {
      setState(() {
        lidOpen = event.snapshot.value == "open";
      });
    });

    dbRef.child('controls/heater').onValue.listen((event) {
      setState(() {
        heaterOn = event.snapshot.value == "on";
      });
    });
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    if (remainingSeconds > 0) {
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (remainingSeconds <= 1) {
          timer.cancel();
          _handlePhaseTransition();
        } else {
          setState(() {
            remainingSeconds--;
          });
          dbRef.child('schedule/remaining').set(remainingSeconds);
        }
      });
    }
  }

  void _handlePhaseTransition() {
    if (currentPhase == 'Phase 1') {
      dbRef.child('schedule').update({
        'phase': 'Phase 2',
        'remaining': phase2Duration,
      });
      _log("Auto-switched to Phase 2");
      _notify("Drying session flipped to Phase 2");
    } else {
      dbRef.child('schedule/remaining').set(0);
      _log("Drying session completed");
      _notify("Drying session completed");
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

    dbRef.child('schedule').update({
      'remaining': phase1Duration,
      'phase': 'Phase 1',
      'batchCount': batchCount + 1,
      'phaseDurations': {'phase1': phase1Duration, 'phase2': phase2Duration},
      'targets': {'temp': temp, 'hum': hum},
    });

    _log(
      "Scheduled new batch with Phase 1: $phase1Duration sec, Phase 2: $phase2Duration sec, Temp: $temp°C, Humidity: $hum%",
    );
    _notify("New drying batch scheduled");
  }

  void stopDryingSession() {
    countdownTimer?.cancel();
    dbRef.child('schedule').update({'remaining': 0, 'phase': 'Phase 1'});
    _log("Drying session manually stopped");
    _notify("Drying session stopped");
  }

  void toggleLid() {
    final newState = lidOpen ? "close" : "open";
    dbRef.child('controls/lid').set(newState);
    _log("Lid toggled to $newState");
    _notify("Lid is now $newState");
  }

  void toggleHeater() {
    final newState = heaterOn ? "off" : "on";
    dbRef.child('controls/heater').set(newState);
    _log("Heater toggled to $newState");
    _notify("Heater is now $newState");
  }

  void triggerFlip() {
    dbRef.child('controls/flip').set("flipping");
    _log("Flip triggered");

    if (currentPhase == 'Phase 1') {
      dbRef.child('schedule').update({
        'phase': 'Phase 2',
        'remaining': phase2Duration,
      });
      _log("Manually flipped to Phase 2");
      _notify("Manually flipped to Phase 2");
    } else {
      dbRef.child('schedule/remaining').set(0);
      _log("Drying session ended after Phase 2");
      _notify("Drying session ended");
    }
  }

  void _log(String message) {
    final ref = dbRef.child('logs');
    ref.once().then((snapshot) {
      final data = snapshot.snapshot.value as List?;
      final updated = [...?data, "${DateTime.now()}: $message"];
      ref.set(updated);
    });
  }

  void _notify(String message) {
    final ref = dbRef.child('notifications');
    ref.once().then((snapshot) {
      final data = snapshot.snapshot.value as List?;
      final updated = [...?data, message];
      ref.set(updated);
    });
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
        TextField(
          controller: humController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Target Humidity (%)"),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: scheduleNewBatch,
          child: const Text("Schedule New Batch"),
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
