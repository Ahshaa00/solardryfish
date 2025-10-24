import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationTestPage extends StatefulWidget {
  final String systemId;

  const NotificationTestPage({
    super.key,
    required this.systemId,
  });

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  Timer? _countdownTimer;
  int _countdown = 0;
  bool _isTimerRunning = false;
  String _lastSentNotification = '';
  String? _fcmToken;
  bool _useDirectNotification = true; // Toggle between direct and FCM

  @override
  void initState() {
    super.initState();
    _initLocalNotifications();
    _loadFCMToken();
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _localNotifications.initialize(initSettings);
  }

  Future<void> _loadFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await _database.child('users/${user.uid}/fcmToken').get();
        if (snapshot.exists) {
          setState(() {
            _fcmToken = snapshot.value.toString();
          });
        }
      }
    } catch (e) {
      print('Error loading FCM token: $e');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds, String notificationType) {
    setState(() {
      _countdown = seconds;
      _isTimerRunning = true;
      _lastSentNotification = '';
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
          _isTimerRunning = false;
          _sendTestNotification(notificationType);
        }
      });
    });
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _countdown = 0;
    });
  }

  Future<void> _sendLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notification channel',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
    );
  }

  Future<void> _sendViaRenderServer(String title, String body) async {
    if (_fcmToken == null || _fcmToken!.isEmpty) {
      throw Exception('No FCM token found. Make sure you\'re logged in.');
    }

    final response = await http.post(
      Uri.parse('https://fcm-proxy-87ly.onrender.com/send'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'token': _fcmToken,
        'title': title,
        'body': body,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send notification: ${response.body}');
    }
  }

  Future<void> _sendTestNotification(String type) async {
    try {
      String title = '';
      String body = '';

      switch (type) {
        case 'rain':
          title = 'Rain Alert';
          body = 'Lid closed due to rain (TEST)';
          break;
        case 'battery_low':
          title = 'Low Battery';
          body = 'Battery level below 20% (TEST)';
          break;
        case 'battery_critical':
          title = 'Critical Battery';
          body = 'Battery critically low - System may shut down (TEST)';
          break;
        case 'temp_high':
          title = 'High Temperature';
          body = 'Temperature reached 65.5°C (TEST)';
          break;
        case 'humidity_high':
          title = 'High Humidity';
          body = 'Humidity reached 95.0% (TEST)';
          break;
        case 'phase_changed':
          title = 'Phase Changed';
          body = 'Now entering Phase 2 (TEST)';
          break;
        case 'drying_complete':
          title = 'Drying Complete';
          body = 'Batch finished (TEST)';
          break;
        case 'manual_override':
          title = 'Manual Override';
          body = 'Manual override enabled - Auto control disabled (TEST)';
          break;
        case 'override_timeout':
          title = 'Override Timeout';
          body = 'Manual override auto-disabled after 15 minutes (TEST)';
          break;
        case 'schedule_started':
          title = 'Schedule Started';
          body = 'Drying schedule has begun (TEST)';
          break;
        case 'schedule_stopped':
          title = 'Schedule Stopped';
          body = 'Drying schedule manually stopped (TEST)';
          break;
      }

      // Send notification based on selected method
      if (_useDirectNotification) {
        // Direct local notification (works immediately)
        await _sendLocalNotification(title, body);
      } else {
        // Via Render server (requires FCM token)
        await _sendViaRenderServer(title, body);
      }

      // Save to Firebase for history (same path as real notifications)
      // ESP32 won't listen to this path, so no duplicates
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _database.child('users/${user.uid}/notifications').push().set({
          'message': '$title: $body',
          'timestamp': ServerValue.timestamp,
          'type': 'test', // Mark as test notification
          'systemId': widget.systemId,
          'isTest': true, // Flag for easy filtering
        });
      }

      setState(() {
        _lastSentNotification = '$title: $body';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Notification sent: $title'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTestButton({
    required String label,
    required String type,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: _isTimerRunning ? null : () => _sendTestNotification(type),
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildTimerButton({
    required String label,
    required int seconds,
    required String type,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: _isTimerRunning ? null : () => _startCountdown(seconds, type),
      icon: Icon(icon, size: 20),
      label: Text('$label ($seconds sec)'),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141829),
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: const Color(0xFF1E2337),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Notification Method Toggle
            Card(
              color: const Color(0xFF1E2337),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Notification Method',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(
                        _useDirectNotification ? 'Direct (Local)' : 'Via FCM Server',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _useDirectNotification
                            ? '✅ Works immediately without hardware'
                            : '⚠️ Requires FCM token & Render server',
                        style: TextStyle(
                          color: _useDirectNotification ? Colors.green : Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                      value: _useDirectNotification,
                      onChanged: (value) {
                        setState(() {
                          _useDirectNotification = value;
                        });
                      },
                      activeColor: Colors.green,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (!_useDirectNotification && (_fcmToken == null || _fcmToken!.isEmpty))
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No FCM token found! Switch to Direct mode or login again.',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Instructions Card
            Card(
              color: const Color(0xFF1E2337),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(
                          'Testing Instructions',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Tap a timer button (10s, 30s, or 60s)\n'
                      '2. Close the app or lock your phone\n'
                      '3. Wait for the countdown to finish\n'
                      '4. You should receive a notification!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Timer Status Card
            if (_isTimerRunning || _countdown > 0)
              Card(
                color: const Color(0xFF1E2337),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Countdown Active',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_countdown',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'seconds remaining',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _cancelTimer,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel Timer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.phone_android, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Close the app now to test background notifications!',
                                style: TextStyle(
                                  color: Colors.orange,
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
              ),
            const SizedBox(height: 20),

            // Last Sent Notification
            if (_lastSentNotification.isNotEmpty)
              Card(
                color: Colors.green.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Last Sent',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _lastSentNotification,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Timer Buttons Section
            Text(
              'Delayed Notifications (Close App After Tap)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimerButton(
                  label: 'Rain Alert',
                  seconds: 10,
                  type: 'rain',
                  icon: Icons.water_drop,
                  color: Colors.blue,
                ),
                _buildTimerButton(
                  label: 'Low Battery',
                  seconds: 30,
                  type: 'battery_low',
                  icon: Icons.battery_alert,
                  color: Colors.orange,
                ),
                _buildTimerButton(
                  label: 'Critical Battery',
                  seconds: 60,
                  type: 'battery_critical',
                  icon: Icons.battery_0_bar,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Instant Buttons Section
            Text(
              'Instant Notifications (For Quick Testing)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTestButton(
                  label: 'Rain Alert',
                  type: 'rain',
                  icon: Icons.water_drop,
                  color: Colors.blue,
                ),
                _buildTestButton(
                  label: 'Low Battery',
                  type: 'battery_low',
                  icon: Icons.battery_alert,
                  color: Colors.orange,
                ),
                _buildTestButton(
                  label: 'Critical Battery',
                  type: 'battery_critical',
                  icon: Icons.battery_0_bar,
                  color: Colors.red,
                ),
                _buildTestButton(
                  label: 'High Temp',
                  type: 'temp_high',
                  icon: Icons.thermostat,
                  color: Colors.deepOrange,
                ),
                _buildTestButton(
                  label: 'High Humidity',
                  type: 'humidity_high',
                  icon: Icons.water,
                  color: Colors.cyan,
                ),
                _buildTestButton(
                  label: 'Phase Changed',
                  type: 'phase_changed',
                  icon: Icons.sync,
                  color: Colors.purple,
                ),
                _buildTestButton(
                  label: 'Drying Complete',
                  type: 'drying_complete',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
                _buildTestButton(
                  label: 'Manual Override',
                  type: 'manual_override',
                  icon: Icons.lock_open,
                  color: Colors.amber,
                ),
                _buildTestButton(
                  label: 'Override Timeout',
                  type: 'override_timeout',
                  icon: Icons.timer_off,
                  color: Colors.grey,
                ),
                _buildTestButton(
                  label: 'Schedule Started',
                  type: 'schedule_started',
                  icon: Icons.play_arrow,
                  color: Colors.teal,
                ),
                _buildTestButton(
                  label: 'Schedule Stopped',
                  type: 'schedule_stopped',
                  icon: Icons.stop,
                  color: Colors.brown,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Warning Card
            Card(
              color: Colors.red.withOpacity(0.2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This is a TEST page. Remove before production!',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
