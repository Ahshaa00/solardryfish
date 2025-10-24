import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Service to monitor internet connectivity and show warnings when connection is lost
class ConnectionMonitorService {
  static final ConnectionMonitorService _instance = ConnectionMonitorService._internal();
  factory ConnectionMonitorService() => _instance;
  ConnectionMonitorService._internal();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isConnected = true;
  final List<VoidCallback> _listeners = [];

  bool get isConnected => _isConnected;

  /// Start monitoring connectivity
  void startMonitoring() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final wasConnected = _isConnected;
      _isConnected = !results.contains(ConnectivityResult.none);
      
      // Only notify if connection state changed
      if (wasConnected != _isConnected) {
        _notifyListeners();
      }
    });
  }

  /// Stop monitoring connectivity
  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Add a listener for connection changes
  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// Remove a listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners
  void _notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  /// Check current connectivity status
  Future<bool> checkConnection() async {
    final results = await Connectivity().checkConnectivity();
    _isConnected = !results.contains(ConnectivityResult.none);
    return _isConnected;
  }

  /// Show connection lost dialog
  static Future<void> showConnectionLostDialog(BuildContext context) async {
    if (!context.mounted) return;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ConnectionLostDialog(),
    );
  }

  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
    _listeners.clear();
  }
}

class _ConnectionLostDialog extends StatefulWidget {
  @override
  State<_ConnectionLostDialog> createState() => _ConnectionLostDialogState();
}

class _ConnectionLostDialogState extends State<_ConnectionLostDialog> {
  int countdown = 10;
  Timer? _countdownTimer;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        countdown--;
      });
      if (countdown <= 0) {
        timer.cancel();
        _retryConnection();
      }
    });
  }

  Future<void> _retryConnection() async {
    if (!mounted) return;
    
    setState(() {
      _isRetrying = true;
    });

    final isConnected = await ConnectionMonitorService().checkConnection();
    
    if (!mounted) return;

    if (isConnected) {
      // Connection restored
      Navigator.of(context).pop();
    } else {
      // Still no connection, restart countdown
      setState(() {
        countdown = 10;
        _isRetrying = false;
      });
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orangeAccent, width: 2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.signal_wifi_off,
                color: Colors.orangeAccent,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Connection Lost",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your device has lost internet connection. You cannot control the hardware system while offline.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "All controls are disabled",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isRetrying)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Checking connection...",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Column(
                  children: [
                    Text(
                      "Retrying in",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          "$countdown",
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              _countdownTimer?.cancel();
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            icon: const Icon(Icons.home, size: 18),
            label: const Text("Go to Home"),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isRetrying ? null : () {
              _countdownTimer?.cancel();
              _retryConnection();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text("Retry Now"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
