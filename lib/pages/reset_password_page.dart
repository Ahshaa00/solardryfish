import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _confirmPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();

  bool _isLoading = false;
  String? errorMessage;

  Future<void> updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      setState(() {
        errorMessage = "No authenticated user found.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      errorMessage = null;
    });

    try {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: _confirmPasswordController.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPasswordController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Password updated successfully!")),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred.";
      switch (e.code) {
        case 'wrong-password':
          message = "❌ Your current password is incorrect.";
          break;
        case 'weak-password':
          message = "⚠️ New password is too weak.";
          break;
        case 'requires-recent-login':
          message = "⏳ Please re-login before updating your password.";
          break;
      }
      setState(() {
        errorMessage = message;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reset Password"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF141829),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm Current Password",
                  filled: true,
                  fillColor: Color(0xFF1E2338),
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.amber),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? "Enter your current password"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "New Password",
                  filled: true,
                  fillColor: Color(0xFF1E2338),
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.amber),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? "Enter a new password"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmNewPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm New Password",
                  filled: true,
                  fillColor: Color(0xFF1E2338),
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.amber),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Re-enter your new password";
                  }
                  if (value != _newPasswordController.text.trim()) {
                    return "Passwords do not match";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : updatePassword,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isLoading ? "Updating..." : "Update Password"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
