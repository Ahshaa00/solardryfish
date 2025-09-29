import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountPage extends StatelessWidget {
  final String systemId;
  const AccountPage({super.key, required this.systemId});

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) return "***@$domain";
    return "${name[0]}***${name[name.length - 1]}@$domain";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "No email";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Account"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF141829),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Account Information",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 20),

            // System ID
            ListTile(
              tileColor: const Color(0xFF1E2338),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(
                Icons.settings_input_component,
                color: Colors.amber,
              ),
              title: const Text("System ID"),
              subtitle: Text(
                systemId,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),

            // Email
            ListTile(
              tileColor: const Color(0xFF1E2338),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.email, color: Colors.amber),
              title: const Text("Email"),
              subtitle: Text(
                _maskEmail(email),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),

            // Reset Password Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/reset_pass');
                },
                icon: const Icon(Icons.lock_reset),
                label: const Text("Reset Password"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
