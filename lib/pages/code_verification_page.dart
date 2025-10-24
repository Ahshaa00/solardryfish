import 'dart:math';
import '../barrel.dart';

class CodeVerificationPage extends StatefulWidget {
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  const CodeVerificationPage({
    super.key,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  @override
  State<CodeVerificationPage> createState() => _CodeVerificationPageState();
}

class _CodeVerificationPageState extends State<CodeVerificationPage> {
  final codeController = TextEditingController();
  bool loading = false;

  String _generateUserId() {
    final now = DateTime.now();
    final dateStr = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final randomStr = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'USR-$dateStr-$randomStr';
  }

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
      // Registration Flow Only
      final docRef = FirebaseFirestore.instance.collection('pending_verifications').doc(email);

      print('🔍 Fetching OTP record for: $email');
      final doc = await docRef.get();
      
      if (!doc.exists) {
        print('❌ No OTP record found for: $email');
        throw "No OTP record found. Please request a new code.";
      }

      final data = doc.data()!;
      final correctOtp = data['otp']?.toString() ?? '';
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

      print('✅ OTP record found. Correct OTP: $correctOtp, Entered: $enteredOtp');

      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        await docRef.delete();
        throw "OTP has expired. Please request a new one.";
      }

      if (enteredOtp != correctOtp) {
        print('❌ OTP mismatch. Expected: $correctOtp, Got: $enteredOtp');
        throw "Incorrect OTP. Please try again.";
      }

      print('✅ OTP verified successfully!');

      // ✅ Create account using password from memory (not from Firestore)
      final password = widget.password;
      
      try {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = userCredential.user;
        if (user == null) throw "User creation failed";

        // ✅ Generate unique user ID
        final userId = _generateUserId();

        // ✅ Store user profile in Realtime Database
        await FirebaseDatabase.instance.ref('users/${user.uid}/profile').set({
          'userId': userId,
          'firstName': widget.firstName,
          'lastName': widget.lastName,
          'email': email,
          'createdAt': ServerValue.timestamp,
        });

        // ✅ Create reverse index for quick lookup
        await FirebaseDatabase.instance.ref('userIdIndex/$userId').set(user.uid);

        // ✅ Send email verification immediately after account creation
        await user.sendEmailVerification();

        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        await docRef.delete();

        print('✅ Account created and signed in successfully!');

        // ✅ Don't navigate manually - let AuthWrapper handle it
        // The authStateChanges() stream will automatically redirect to SystemSelectorPage
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Account created successfully! Welcome!"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Wait a moment for the snackbar to show, then AuthWrapper takes over
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          print('⚠️ Email already in use, attempting to sign in...');
          
          try {
            // Try to delete OTP record
            await docRef.delete().catchError((e) => print('OTP delete failed: $e'));
            
            // Sign in with existing account
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: widget.password,
            );
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Account already exists. Signing you in..."),
                  backgroundColor: Colors.orange,
                ),
              );
              
              // Wait for AuthWrapper to handle navigation
              await Future.delayed(const Duration(milliseconds: 500));
            }
          } catch (signInError) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Email already registered. Please log in. Error: $signInError"),
                  backgroundColor: Colors.red,
                ),
              );
              
              // Navigate to login page
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            }
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      print('❌ Verification error: $e');
      
      // Check if user is already signed in despite the error
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        print('✅ User is signed in despite error. Redirecting...');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Account created! Some profile data may be incomplete. Please deploy database rules."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Wait for snackbar, then let AuthWrapper redirect
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      } else {
        // User not signed in, show error
        if (mounted) {
          // Check if it's a permission error
          if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Database rules not deployed! Deploy both Firestore AND Realtime Database rules."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Verification failed: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Verify Email",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E2235),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFF141829),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            
            // Header Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.amber.shade700, Colors.amber],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read,
                size: 60,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Title
            const Text(
              "Verify Your Email",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Subtitle
            Text(
              "We've sent a 4-digit code to",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade400,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Email Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Text(
                widget.email,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // OTP Input
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.pin,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Enter OTP Code",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: "••••",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        letterSpacing: 16,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF141829),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade800),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber, width: 2),
                      ),
                      counterText: "",
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Verify Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: loading ? null : verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade800,
                ),
                child: loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user, size: 24),
                          SizedBox(width: 12),
                          Text(
                            "Verify & Continue",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Didn't receive the code? Check your spam folder or request a new one.",
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
