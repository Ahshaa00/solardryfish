import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'system_selector_page.dart';
import 'reset_password_page.dart';

class CodeVerificationPage extends StatefulWidget {
  final String email;
  final bool isResetFlow;

  const CodeVerificationPage({
    super.key,
    required this.email,
    this.isResetFlow = false,
  });

  @override
  State<CodeVerificationPage> createState() => _CodeVerificationPageState();
}

class _CodeVerificationPageState extends State<CodeVerificationPage> {
  final codeController = TextEditingController();
  bool loading = false;

  Future<void> verifyOtp() async {
    final enteredOtp = codeController.text.trim();
    final email = widget.email.trim().toLowerCase();

    if (enteredOtp.isEmpty || enteredOtp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the 4-digit OTP")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection(
            widget.isResetFlow ? 'password_resets' : 'pending_verifications',
          )
          .doc(email);

      final doc = await docRef.get();
      if (!doc.exists) throw "No OTP record found.";

      final data = doc.data()!;
      final correctOtp = data['otp'];
      final password = data['password'];
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        await docRef.delete();
        throw "OTP has expired. Please request a new one.";
      }

      if (enteredOtp != correctOtp) throw "Incorrect OTP.";

      // ✅ Registration Flow
      if (!widget.isResetFlow) {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          await docRef.delete();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account created successfully.")),
          );

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SystemSelectorPage()),
            );
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            await docRef.delete();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Email is already registered. Please log in or reset your password.",
                ),
              ),
            );
          } else {
            rethrow; // other FirebaseAuth errors
          }
        }
      }
      // ✅ Forgot Password Flow
      else {
        await docRef.delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("OTP verified. Proceed to reset password."),
          ),
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ResetPasswordPage(email: email)),
          );
        }
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
    final title = widget.isResetFlow ? "Reset Password" : "Verify Email";

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isResetFlow
                    ? "Enter the OTP sent to your email to reset your password"
                    : "Enter the OTP sent to your email to complete registration",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: "OTP",
                  prefixIcon: Icon(Icons.verified),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: verifyOtp,
                      child: const Text("Verify"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
