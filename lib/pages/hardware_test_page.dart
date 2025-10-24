import '../barrel.dart';

class HardwareTestPage extends StatefulWidget {
  final String systemId;
  const HardwareTestPage({required this.systemId, super.key});

  @override
  State<HardwareTestPage> createState() => _HardwareTestPageState();
}

class _HardwareTestPageState extends State<HardwareTestPage> {
  late final DatabaseReference systemRef;
  bool isTestingFlip = false;
  bool isTestingLid = false;
  String flipStatus = '';
  String lidStatus = '';
  
  // System status
  bool online = false;
  String currentPhase = 'Idle';
  bool systemWorking = false;

  @override
  void initState() {
    super.initState();
    systemRef = FirebaseDatabase.instance.ref('hardwareSystems/${widget.systemId}');
    
    // Listen to system online status
    systemRef.child('status/online').onValue.listen((event) {
      if (mounted) {
        setState(() {
          online = event.snapshot.value == true;
        });
      }
    });
    
    // Listen to current phase
    systemRef.child('status/phase').onValue.listen((event) {
      if (mounted) {
        final phase = event.snapshot.value?.toString() ?? 'Idle';
        setState(() {
          currentPhase = phase;
          systemWorking = phase != 'Idle' && phase != 'Ended';
        });
      }
    });
  }

  Future<void> _testFlipControl() async {
    setState(() {
      isTestingFlip = true;
      flipStatus = 'Testing flip control...';
    });

    try {
      // Send flip test command to Firebase
      await systemRef.child('commands/testFlip').set({
        'action': 'test',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      setState(() {
        flipStatus = '✅ Flip test command sent!\nTray will flip 2 times.';
      });

      // Auto-clear status after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            flipStatus = '';
            isTestingFlip = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        flipStatus = '❌ Error: $e';
        isTestingFlip = false;
      });
    }
  }

  Future<void> _testLidControl() async {
    setState(() {
      isTestingLid = true;
      lidStatus = 'Testing lid control...';
    });

    try {
      // Send lid test command to Firebase
      await systemRef.child('commands/testLid').set({
        'action': 'test',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      setState(() {
        lidStatus = '✅ Lid test command sent!\nLid will open and close.';
      });

      // Auto-clear status after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            lidStatus = '';
            isTestingLid = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        lidStatus = '❌ Error: $e';
        isTestingLid = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2235),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Hardware Testing",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: const Color(0xFF141829),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Page Title
          const Text(
            'Hardware Testing',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Test hardware components manually',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),

          // System Status Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2235),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: online ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        online ? Icons.cloud_done : Icons.cloud_off,
                        color: online ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connection',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              online ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: online ? Colors.green : Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2235),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: systemWorking ? Colors.orange.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        systemWorking ? Icons.work : Icons.check_circle,
                        color: systemWorking ? Colors.orange : Colors.blue,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              systemWorking ? 'Working' : 'Idle',
                              style: TextStyle(
                                color: systemWorking ? Colors.orange : Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (systemWorking)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Current Phase: $currentPhase',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Warning/Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (!online || systemWorking)
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (!online || systemWorking)
                    ? Colors.red.withOpacity(0.3)
                    : Colors.green.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  (!online || systemWorking)
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle,
                  color: (!online || systemWorking) ? Colors.red : Colors.green,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (!online || systemWorking) ? 'Cannot Test' : 'Ready to Test',
                        style: TextStyle(
                          color: (!online || systemWorking) ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        !online
                            ? 'System is offline. Tests are disabled.'
                            : systemWorking
                                ? 'System is working ($currentPhase). Stop drying first.'
                                : 'System is idle and online. Safe to run tests.',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Flip Control Test
          _buildTestCard(
            title: 'Flip Control Test',
            description: 'Test tray flipping mechanism\nWill flip 2 times',
            icon: Icons.flip,
            color: Colors.blue,
            isLoading: isTestingFlip,
            status: flipStatus,
            onTest: _testFlipControl,
          ),
          const SizedBox(height: 16),

          // Lid Control Test
          _buildTestCard(
            title: 'Lid Control Test',
            description: 'Test lid opening and closing\nWill open and close once',
            icon: Icons.door_front_door,
            color: Colors.green,
            isLoading: isTestingLid,
            status: lidStatus,
            onTest: _testLidControl,
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required String status,
    required VoidCallback onTest,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (status.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: status.contains('✅')
                    ? Colors.green.withOpacity(0.1)
                    : status.contains('❌')
                        ? Colors.red.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: status.contains('✅')
                      ? Colors.green
                      : status.contains('❌')
                          ? Colors.red
                          : Colors.blue,
                  fontSize: 13,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isLoading || !online || systemWorking) ? null : onTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade700,
                  disabledForegroundColor: Colors.grey.shade500,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        !online
                            ? 'System Offline'
                            : systemWorking
                                ? 'System Working'
                                : 'Start Test',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
