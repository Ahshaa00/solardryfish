import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';

import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/system_monitor_page.dart';
import 'pages/schedule_flip_page.dart';
import 'pages/activity_log_page.dart';
import 'pages/notifications_page.dart';
import 'pages/system_selector_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SolarDryFish',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141829),
        primaryColor: Colors.amber,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        final systemId = settings.arguments as String?;
        if (systemId == null) {
          return MaterialPageRoute(builder: (_) => const SystemSelectorPage());
        }

        switch (settings.name) {
          case '/dashboard':
            return MaterialPageRoute(
              builder: (_) => DashboardPage(systemId: systemId),
            );
          case '/schedule':
            return MaterialPageRoute(
              builder: (_) => ScheduleFlipPage(systemId: systemId),
            );
          case '/log':
            return MaterialPageRoute(
              builder: (_) => ActivityLogPage(systemId: systemId),
            );
          case '/notifications':
            return MaterialPageRoute(
              builder: (_) => NotificationsPage(systemId: systemId),
            );
          case '/monitor':
            return MaterialPageRoute(
              builder: (_) => SystemMonitorPage(systemId: systemId),
            );
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterPage());
          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool checking = true;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    checkConnectivity();
  }

  Future<void> checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    final hasInternet = result != ConnectivityResult.none;

    if (hasInternet) {
      setState(() {
        isConnected = true;
        checking = false;
      });
    } else {
      await showNoInternetDialog();
      setState(() {
        isConnected = false;
        checking = true;
      });
      checkConnectivity();
    }
  }

  Future<void> showNoInternetDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        title: const Text(
          "No Internet Connection",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "You are not connected to the internet.\nPlease check your connection.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => exit(0),
            child: const Text(
              "Exit",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Try Again",
              style: TextStyle(color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF141829),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      colors: [Colors.white, Colors.amber, Colors.white],
                      stops: [
                        (_controller.value - 0.3).clamp(0.0, 1.0),
                        _controller.value.clamp(0.0, 1.0),
                        (_controller.value + 0.3).clamp(0.0, 1.0),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds);
                  },
                  child: const Text(
                    "SolarDryFish",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            const Text(
              "Real-Time Statistics and Notifications",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            checking
                ? const CircularProgressIndicator()
                : isConnected
                ? ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthWrapper()),
                      );
                    },
                    child: const Text("Get Started"),
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.hasData) {
          return const SystemSelectorPage(); // ✅ Now prompts for systemId
        }
        return const LoginPage();
      },
    );
  }
}
