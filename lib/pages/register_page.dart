import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'code_verification_page.dart';
import '../utils/validators.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool loading = false;
  bool showPassword = false;
  int passwordStrength = 0;

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

  Future<void> startRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    setState(() => loading = true);

    try {
      // ✅ Generate OTP and save to Firestore
      final otp = (1000 + Random().nextInt(9000)).toString();
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));

      print('📧 Registering: $email');
      print('🔑 Generated OTP: $otp');
      print('⏰ Expires at: $expiresAt');

      await FirebaseFirestore.instance
          .collection('pending_verifications')
          .doc(email)
          .set({
            'email': email,
            'otp': otp,
            'timestamp': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(expiresAt),
          });

      print('✅ OTP saved to Firestore: pending_verifications/$email');

      // ✅ Send OTP via EmailJS
      await sendOtpEmail(email, otp);

      print('✅ OTP email sent successfully');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("OTP sent to $email! Check your inbox.")));

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CodeVerificationPage(
              email: email,
              password: password,
              firstName: firstName,
              lastName: lastName,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Email is already registered. Please log in or reset your password.",
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Firebase error: ${e.message}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Registration failed: $e")));
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
                const Text("Create Account", style: TextStyle(fontSize: 22)),
                const SizedBox(height: 30),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: firstNameController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 50,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-']")),
                        ],
                        validator: (value) => Validators.validateName(value, 'First name'),
                        decoration: const InputDecoration(
                          labelText: "First Name",
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: lastNameController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 50,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-']")),
                        ],
                        validator: (value) => Validators.validateName(value, 'Last name'),
                        decoration: const InputDecoration(
                          labelText: "Last Name",
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        maxLength: 320,
                        validator: Validators.validateEmail,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: passwordController,
                        obscureText: !showPassword,
                        maxLength: 72,
                        onChanged: (value) {
                          setState(() {
                            passwordStrength = Validators.getPasswordStrength(value);
                          });
                        },
                        validator: (value) => Validators.validatePassword(value, isNewPassword: true),
                        decoration: InputDecoration(
                          labelText: "Password",
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          counterText: '',
                          suffixIcon: IconButton(
                            icon: Icon(
                              showPassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => showPassword = !showPassword),
                          ),
                        ),
                      ),
                      if (passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: passwordStrength / 4,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(Validators.getPasswordStrengthColor(passwordStrength)),
                                ),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Validators.getPasswordStrengthLabel(passwordStrength),
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(Validators.getPasswordStrengthColor(passwordStrength)),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Must contain: 8+ chars, uppercase, lowercase, number, special char',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 20),
                      loading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: startRegistration,
                              child: const Text("Register"),
                            ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Back to login"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
