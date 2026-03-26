import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:play_sphere/constants.dart';
import 'package:play_sphere/controllers/auth_controllers.dart';
import 'package:play_sphere/views/screens/plan_selection_screen.dart';
import 'package:play_sphere/views/screens/home_screen.dart';
import 'package:play_sphere/services/payment_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({Key? key}) : super(key: key);

  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthController _authController = Get.find<AuthController>();
  bool _isLoading = false;
  bool _canResendEmail = true;
  bool _isCheckingVerification = false;

  @override
  void initState() {
    super.initState();
    _sendInitialVerificationEmail();
    _checkVerificationStatus();
  }

  @override
  void dispose() {
    // Stop the verification checking when widget is disposed
    _isCheckingVerification = false;
    super.dispose();
  }

  void _sendInitialVerificationEmail() async {
    await _authController.sendEmailVerification();
  }

  void _checkVerificationStatus() async {
    // Check verification status every 3 seconds
    _isCheckingVerification = true;
    while (_isCheckingVerification && mounted) {
      await Future.delayed(const Duration(seconds: 3));
      final isVerified = await _authController.checkEmailVerified();
      if (isVerified && mounted) {
        Get.snackbar(
          'Registration Complete!', 
          'Your account has been created successfully. Welcome to PlaySphere!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        _isCheckingVerification = false; // Stop checking after verification
        break;
      }
    }
  }

  void _resendVerificationEmail() async {
    if (!_canResendEmail || !mounted) return;

    setState(() {
      _isLoading = true;
      _canResendEmail = false;
    });

    await _authController.sendEmailVerification();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    // Prevent spam by disabling resend for 60 seconds
    await Future.delayed(const Duration(seconds: 60));
    if (mounted) {
      setState(() {
        _canResendEmail = true;
      });
    }
  }

  void _refreshVerificationStatus() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    final isVerified = await _authController.checkEmailVerified();
    
    if (isVerified && mounted) {
      // Check if user already has an active subscription or trial
      final user = _authController.currentUser;
      if (user != null) {
        final PaymentService paymentService = Get.find<PaymentService>();
        final hasSubscription = await paymentService.hasActiveSubscription(user.uid);
        final hasTrial = await paymentService.hasActiveTrial(user.uid);
        
        if (hasSubscription || hasTrial) {
          // User already has access, go to home
          Get.offAll(() => const HomeScreen());
        } else {
          // User needs to select a plan
          Get.offAll(() => const PlanSelectionScreen());
        }
      } else {
        Get.offAll(() => const PlanSelectionScreen());
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authController.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                Icon(
                  Icons.email_outlined,
                  size: 100,
                  color: secondaryColor,
                ),
                const SizedBox(height: 30),
                Text(
                  'Verify Your Email',
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'We\'ve sent a verification email to:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _authController.currentUser?.email ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: secondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Text(
                  'Please check your email and click the verification link to continue.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // Refresh Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _refreshVerificationStatus,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 20, 
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.refresh, color: Colors.black),
                    label: Text(
                      _isLoading ? 'Checking...' : 'I\'ve Verified My Email',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Resend Email Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _canResendEmail && !_isLoading ? _resendVerificationEmail : null,
                    icon: Icon(
                      Icons.send,
                      color: _canResendEmail ? secondaryColor : Colors.grey,
                    ),
                    label: Text(
                      _canResendEmail ? 'Resend Verification Email' : 'Wait before resending',
                      style: TextStyle(
                        color: _canResendEmail ? secondaryColor : Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _canResendEmail ? secondaryColor : Colors.grey,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Help Text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Didn\'t receive the email?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Check your spam/junk folder\n• Make sure you entered the correct email\n• Wait a few minutes for the email to arrive',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
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
