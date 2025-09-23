import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_page.dart';
import 'dashboard_page.dart'; // Replace with your actual dashboard

class SystemSelectorPage extends StatefulWidget {
  const SystemSelectorPage({super.key});

  @override
  State<SystemSelectorPage> createState() => _SystemSelectorPageState();
}

class _SystemSelectorPageState extends State<SystemSelectorPage> {
  final systemIdController = TextEditingController();
  bool loading = false;

  bool isValidFormat(String id) {
    final pattern = RegExp(r'^SDF\d{6}[A-Z0-9]{2,4}$');
    return pattern.hasMatch(id);
  }

  Future<void> proceedToDashboard() async {
    final rawInput = systemIdController.text.trim().toUpperCase();

    if (rawInput.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a system ID")));
      return;
    }

    if (!isValidFormat(rawInput)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid format. Use SDFYYYYMMXX")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final systemRef = FirebaseDatabase.instance.ref(
        'hardwareSystems/$rawInput',
      );
      final snapshot = await systemRef.get();

      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("System ID not found. Please check your hardware."),
          ),
        );
        setState(() => loading = false);
        return;
      }

      // Optional: log system access or bind to user
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance.ref('userAccess/${user.uid}').set({
          'systemId': rawInput,
        });
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardPage(systemId: rawInput)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading system: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Drying System",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: systemIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: "Enter System ID (e.g. SDF202509XZ)",
                  prefixIcon: Icon(Icons.device_hub),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: proceedToDashboard,
                      child: const Text("Continue"),
                    ),
              const SizedBox(height: 10),
              TextButton(onPressed: logout, child: const Text("Logout")),
            ],
          ),
        ),
      ),
    );
  }
}
