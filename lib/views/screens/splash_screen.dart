import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/auth_controllers.dart';
import 'auth/login_screen.dart';
import 'home_screen.dart';
import 'auth/email_verification_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthController authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  _navigateToNextScreen() async {
    // Show splash for 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool? onboardingCompleted = prefs.getBool("onboarding_completed");

      if (onboardingCompleted == null || !onboardingCompleted) {
        Get.offAll(() => const OnboardingScreen());
        return;
      }

      final user = authController.currentUser;
      if (user == null) {
        Get.offAll(() => LoginScreen());
      } else {
        if (user.emailVerified) {
          Get.offAll(() => const HomeScreen());
        } else {
          Get.offAll(() => const EmailVerificationScreen());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 100), // Adjusted to move logo higher
            // Logo
            Image.asset(
              'assets/play_sphere_logo.png',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            // Optional loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
