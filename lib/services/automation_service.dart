import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AutomationService {
  final DatabaseReference systemRef;

  AutomationService(this.systemRef);

  /// 🌧 Lid control based on rain + light sensors
  Future<void> evaluateLidControl(
    Map<dynamic, dynamic> rainData,
    Map<dynamic, dynamic> lightData,
  ) async {
    final isRaining = rainData.values.any((v) => v is num && v > 0);
    final isDark = lightData.values.every((v) => v is num && v < 300);
    final lidState = (isRaining || isDark) ? 'close' : 'open';

    await systemRef.child('controls/lid').set(lidState);
    await systemRef.child('logs/lid').push().set({
      'timestamp': DateTime.now().toIso8601String(),
      'action': lidState,
      'reason': isRaining
          ? 'Rain detected'
          : isDark
          ? 'Low light'
          : 'Clear conditions',
    });
  }

  /// 🌡 Heater control based on average temp/humidity vs targets
  Future<void> evaluateHeaterControl({
    required List<double> temps,
    required List<double> hums,
    required double targetTemp,
    required double targetHum,
  }) async {
    final avgTemp = temps.reduce((a, b) => a + b) / temps.length;
    final avgHum = hums.reduce((a, b) => a + b) / hums.length;

    final heaterState = (avgTemp < targetTemp || avgHum > targetHum)
        ? 'on'
        : 'off';

    await systemRef.child('controls/heater').set(heaterState);
    await systemRef.child('logs/heater').push().set({
      'timestamp': DateTime.now().toIso8601String(),
      'action': heaterState,
      'avgTemp': avgTemp,
      'avgHum': avgHum,
      'targetTemp': targetTemp,
      'targetHum': targetHum,
    });
  }

  /// 🔄 Flip trigger based on scheduled time
  Future<void> checkFlipSchedule(Map<dynamic, dynamic> scheduleMap) async {
    final now = DateFormat('HH:mm').format(DateTime.now());
    final shouldFlip = scheduleMap[now] == true;

    if (shouldFlip) {
      await systemRef.child('controls/flip').set('flipping');
      await systemRef.child('logs/flips').push().set({
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'flipped',
        'scheduledTime': now,
      });
      await systemRef.child('schedules/$now').set(false);
    }
  }
}
