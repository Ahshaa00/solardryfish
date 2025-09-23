import 'package:firebase_database/firebase_database.dart';

class ScheduleService {
  final DatabaseReference systemRef;

  ScheduleService(this.systemRef);

  /// 🔄 Listen to schedule updates: remaining time, phase, batch count, targets
  void listenToSchedule({
    required Function(int) onRemainingUpdate,
    required Function(String) onPhaseUpdate,
    required Function(int) onBatchUpdate,
    required Function(double, double) onTargetUpdate,
  }) {
    systemRef.child('schedule/remaining').onValue.listen((event) {
      final val = event.snapshot.value;
      final seconds = val is int ? val : int.tryParse(val.toString()) ?? 0;
      onRemainingUpdate(seconds);
    });

    systemRef.child('schedule/phase').onValue.listen((event) {
      final phase = event.snapshot.value?.toString() ?? 'Phase 1';
      onPhaseUpdate(phase);
    });

    systemRef.child('schedule/batchCount').onValue.listen((event) {
      final val = event.snapshot.value;
      final count = val is int ? val : int.tryParse(val.toString()) ?? 0;
      onBatchUpdate(count);
    });

    systemRef.child('schedule/targets').onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final temp = double.tryParse(data['temp'].toString()) ?? 35.0;
        final hum = double.tryParse(data['hum'].toString()) ?? 50.0;
        onTargetUpdate(temp, hum);
      }
    });
  }

  /// 🎛️ Listen to control states: lid and heater
  void listenToControls({
    required Function(bool) onLidUpdate,
    required Function(bool) onHeaterUpdate,
  }) {
    systemRef.child('controls/lid').onValue.listen((event) {
      final isOpen = event.snapshot.value == "open";
      onLidUpdate(isOpen);
    });

    systemRef.child('controls/heater').onValue.listen((event) {
      final isOn = event.snapshot.value == "on";
      onHeaterUpdate(isOn);
    });
  }

  /// 🧠 Update schedule with new batch settings
  Future<void> updateSchedule({
    required int phase1Duration,
    required int phase2Duration,
    required int batchCount,
    required double temp,
    required double hum,
  }) async {
    await systemRef.child('schedule').update({
      'remaining': phase1Duration,
      'phase': 'Phase 1',
      'batchCount': batchCount + 1,
      'phaseDurations': {'phase1': phase1Duration, 'phase2': phase2Duration},
      'targets': {'temp': temp, 'hum': hum},
    });
  }

  /// 🎛️ Toggle any control (lid, heater, flip)
  Future<void> toggleControl(String key, String newState) async {
    await systemRef.child('controls/$key').set(newState);
  }

  /// 📝 Log system events
  Future<void> log(String message) async {
    await systemRef.child('logs').push().set({
      'timestamp': DateTime.now().toIso8601String(),
      'message': message,
    });
  }

  /// 🔔 Send user notifications
  Future<void> notify(String message) async {
    await systemRef.child('notifications').push().set({
      'timestamp': DateTime.now().toIso8601String(),
      'message': message,
    });
  }
}
