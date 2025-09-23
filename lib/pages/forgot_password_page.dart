import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'code_verification_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  bool loading = false;

  Future<void> sendOtpEmail(String email, String otp) async {
    const serviceId = 'service_lhe1js8';
    const templateId = 'template_4a79q0s';
    const userId = 'FzZRICSPDyIAFC1Tt';

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': userId,
        'template_params': {'to_email': email, 'otp': otp},
      }),
    );

    if (response.statusCode != 200) {
      throw "EmailJS failed: ${response.body}";
    }
  }

  Future<void> sendResetOtp() async {
    final email = emailController.text.trim().toLowerCase();
    final originalPassword = 'Admin123'; // Replace with secure logic if needed

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final otp = (1000 + Random().nextInt(9000)).toString();
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));

      await FirebaseFirestore.instance
          .collection('password_resets')
          .doc(email)
          .set({
            'email': email,
            'otp': otp,
            'password': originalPassword,
            'timestamp': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(expiresAt),
          });

      await sendOtpEmail(email, otp);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("OTP sent to $email")));

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CodeVerificationPage(email: email, isResetFlow: true),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to send OTP: $e")));
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  "SolarDryFish",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text("Forgot Password", style: TextStyle(fontSize: 22)),
                const SizedBox(height: 30),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: sendResetOtp,
                        child: const Text("Send OTP"),
                      ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Back to login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
