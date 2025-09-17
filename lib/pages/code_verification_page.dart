import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_page.dart';

class CodeVerificationPage extends StatefulWidget {
  final String email;
  const CodeVerificationPage({super.key, required this.email});

  @override
  State<CodeVerificationPage> createState() => _CodeVerificationPageState();
}

class _CodeVerificationPageState extends State<CodeVerificationPage> {
  final linkController = TextEditingController();
  bool loading = false;

  Future<void> verifyEmailLink() async {
    final email = widget.email;
    final otpLink = linkController.text.trim();

    if (!FirebaseAuth.instance.isSignInWithEmailLink(otpLink)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid verification link")),
      );
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailLink(
        email: email,
        emailLink: otpLink,
      );

      // Retrieve password from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('pending_registrations')
          .doc(email)
          .get();
      if (!doc.exists) {
        throw Exception("No pending registration found for this email.");
      }

      final password = doc['password'];

      // Create actual Firebase Auth account
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Clean up Firestore
      await FirebaseFirestore.instance
          .collection('pending_registrations')
          .doc(email)
          .delete();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Verification failed: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "SolarDryFish",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("Code Verification", style: TextStyle(fontSize: 22)),
              const SizedBox(height: 30),
              TextField(
                controller: linkController,
                decoration: const InputDecoration(
                  labelText: "Paste verification link from email",
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: verifyEmailLink,
                      child: const Text("Verify"),
                    ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Back to login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
