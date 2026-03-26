import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'home_screen.dart';
import 'auth/email_verification_screen.dart';
import '../../controllers/auth_controllers.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  int _currentPage = 0;
  final PageController _pageController = PageController(initialPage: 0);
  late AnimationController _animationController;
  late Animation<double> _animation;

  List<Map<String, String>> _onBoardData = [
    {
      "title": "Welcome to PlaySphere!",
      "subtitle": "Experience the world of endless entertainment with videos that matter to you.",
      "asset": "assets/world.svg"
    },
    {
      "title": "Ads Free Experience",
      "subtitle": "Enjoy uninterrupted content streaming without any advertisements.",
      "asset": "assets/video.svg"
    },
    {
      "title": "Connect & Share",
      "subtitle": "Share your favorite moments with friends and build your community.",
      "asset": "assets/share.svg"
    },
  ];

  final AuthController authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _storeOnboardingInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool("onboarding_completed", true);
  }

  void _goToNext() async {
    await _storeOnboardingInfo();
    
    // For first-time users, redirect to sign-up page after onboarding
    // This encourages new user registration
    final user = authController.currentUser;
    if (user == null) {
      // First-time user - show sign-up screen
      Get.offAll(() => SignupScreen());
    } else {
      // Already logged in user - go to home
      if (user.emailVerified) {
        Get.offAll(() => const HomeScreen());
      } else {
        Get.offAll(() => const EmailVerificationScreen());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Only show Skip button if not on the last page
          if (_currentPage < _onBoardData.length - 1)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton(
                onPressed: _goToNext,
                child: Text(
                  "Skip",
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _animation,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (value) {
            setState(() {
              _currentPage = value;
            });
            _animationController.reset();
            _animationController.forward();
          },
          itemCount: _onBoardData.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                // SVG Icon with PlaySphere's secondary color
                SvgPicture.asset(
                  _onBoardData[index]["asset"]!,
                  height: 180,
                  width: 180,
                  colorFilter: ColorFilter.mode(
                    secondaryColor,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 40),
                // Title
                Text(
                  _onBoardData[index]["title"]!,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: buttonColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Subtitle
                Text(
                  _onBoardData[index]["subtitle"]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: buttonColor.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomSheet: Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onBoardData.length,
                (index) => buildDot(index: index),
              ),
            ),
            const SizedBox(height: 30),
            // Get Started button (only on last page)
            if (_currentPage == _onBoardData.length - 1)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _goToNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryColor,
                    foregroundColor: backgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Get Started",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  AnimatedContainer buildDot({int? index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: _currentPage == index ? secondaryColor : borderColor,
      ),
    );
  }
}

