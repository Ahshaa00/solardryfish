import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/homepage.dart';
import 'pages/system_monitor_page.dart';
import 'pages/notifications_page.dart';
import 'pages/system_selector_page.dart';
import 'pages/account_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/email_verification_page.dart';
import 'services/notification_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔕 Background message received: ${message.messageId}");
  
  // Show notification even when app is closed/killed
  RemoteNotification? notification = message.notification;
  if (notification != null) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}

Future<void> initFCM() async {
  await FirebaseMessaging.instance.requestPermission();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Get and save FCM token for this device
  String? token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    print("📱 FCM Token: $token");
    
    // Save token to user's profile (for sending notifications later)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/fcmToken')
            .set(token);
        print("✅ FCM token saved to database");
      } catch (e) {
        print("❌ Failed to save FCM token: $e");
      }
    }
  }
  
  // Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    print("🔄 FCM Token refreshed: $newToken");
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseDatabase.instance
          .ref('users/${user.uid}/fcmToken')
          .set(newToken);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initFCM();
  
  // Initialize notification service to listen for notifications app-wide
  await NotificationService().initialize();
  
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
        String? systemId;
        final args = settings.arguments;
        if (args is String) {
          systemId = args;
        } else if (args is Map<String, dynamic>) {
          systemId = args['systemId'] as String?;
        }

        switch (settings.name) {
          case '/notifications':
            return MaterialPageRoute(
              builder: (_) => systemId != null
                  ? NotificationsPage(systemId: systemId)
                  : const SystemSelectorPage(),
            );
          case '/monitor':
            return MaterialPageRoute(
              builder: (_) => systemId != null
                  ? SystemMonitorPage(systemId: systemId)
                  : const SystemSelectorPage(),
            );
          case '/account':
            return MaterialPageRoute(
              builder: (_) => systemId != null
                  ? AccountPage(systemId: systemId)
                  : const SystemSelectorPage(),
            );
          case '/reset_pass':
            return MaterialPageRoute(builder: (_) => const ResetPasswordPage());
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
      if (mounted) {
        setState(() {
          isConnected = true;
          checking = false;
        });
      }
    } else {
      await showNoInternetDialog();
      if (mounted) {
        setState(() {
          isConnected = false;
          checking = true;
        });
      }
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) checkConnectivity();
    }
  }

  Future<void> showNoInternetDialog() async {
    if (!mounted) return;
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF141829),
              const Color(0xFF1E2235),
              const Color(0xFF141829),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                
                // Animated Sun Icon
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_controller.value * 0.1),
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.amber.withOpacity(0.3),
                              Colors.amber.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.amber.shade700, Colors.amber],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.wb_sunny,
                            size: 80,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // App Title
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
                
                const SizedBox(height: 16),
                
                // Subtitle
                const Text(
                  "Smart Fish Drying System",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.amber,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                const Text(
                  "Real-Time Monitoring & Control",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Loading or Button
                checking
                    ? Column(
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isConnected ? "Loading..." : "Checking connection...",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      )
                    : isConnected
                        ? Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.amber.shade700, Colors.amber],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Get Started",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, color: Colors.black87),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                
                const Spacer(flex: 3),
                
                // Footer
                const Text(
                  "Powered by Solar Energy",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
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
          final user = snapshot.data!;
          
          // ✅ Check if email is verified (DISABLED FOR TESTING)
          // TODO: Re-enable email verification before production
          // if (!user.emailVerified) {
          //   return EmailVerificationPage();
          // }
          
          return const SystemSelectorPage();
        }
        return const LoginPage();
      },
    );
  }
}
