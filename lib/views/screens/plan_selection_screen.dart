import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants.dart';
import '../../services/payment_service.dart';
import '../../services/paystack_service.dart';
import 'free_trial_card_screen.dart';
import 'payment_method_screen.dart';
import 'home_screen.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  bool _isLoading = false;
  final PaymentService _paymentService = Get.put(PaymentService());
  final PaystackService _paystackService = Get.put(PaystackService());

  @override
  void initState() {
    super.initState();
    _checkExistingSubscription();
  }

  void _checkExistingSubscription() async {
    final user = firebaseAuth.currentUser;
    if (user != null) {
      final hasSubscription = await _paymentService.hasActiveSubscription(user.uid);
      final hasFreeTrial = await _paymentService.hasActiveTrial(user.uid);
      
      if (hasSubscription || hasFreeTrial) {
        // User already has access, redirect to home
        Get.offAll(() => const HomeScreen());
      }
    }
  }

  void _startFreeTrial() async {
    final user = firebaseAuth.currentUser;
    if (user != null) {
      // Check if user is eligible for free trial
      final isEligible = await _paymentService.isEligibleForFreeTrial(user.uid);
      
      if (!isEligible) {
        Get.snackbar(
          'Trial Not Available',
          'You have already used your free trial. Please choose a paid plan.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }
    }
    
    // Navigate to card verification screen for free trial
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FreeTrialCardScreen(),
      ),
    );
  }

  void _choosePaidPlan(String planType, int amount) {
    // Navigate to payment method selection screen
    final reference = 'PS_${DateTime.now().millisecondsSinceEpoch}';
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentMethodScreen(
          planType: planType,
          amount: amount,
          reference: reference,
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature, {bool highlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: highlighted ? secondaryColor : Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                color: highlighted ? Colors.white : Colors.grey[300],
                fontSize: 15,
                fontWeight: highlighted ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String duration,
    required String description,
    required List<String> features,
    required VoidCallback onPressed,
    required Color primaryColor,
    required Color buttonColor,
    bool isRecommended = false,
    bool isFree = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: isRecommended 
            ? Border.all(color: secondaryColor, width: 2)
            : Border.all(color: Colors.grey[700]!, width: 1),
        boxShadow: isRecommended ? [
          BoxShadow(
            color: secondaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isRecommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: secondaryColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            if (isRecommended) const SizedBox(height: 15),
            
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isFree)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'FREE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
                height: 1.3,
              ),
            ),
            const SizedBox(height: 15),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: isFree ? 28 : 34,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                if (!isFree) ...[
                  Text(
                    '/$duration',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 25),
            
            // Features list
            ...features.map((feature) => _buildFeatureItem(feature, highlighted: isRecommended)),
            
            const SizedBox(height: 25),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: buttonColor == secondaryColor ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: isRecommended ? 8 : 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isFree ? 'Start Free Trial' : 'Choose $title',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Choose Your Plan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // Remove back button since this is mandatory step
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Welcome section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.celebration,
                    size: 60,
                    color: secondaryColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to PlaySphere!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choose a plan to unlock all features and start creating amazing content.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Free Trial Plan
            _buildPlanCard(
              title: '7-Day Free Trial',
              price: 'FREE',
              duration: '',
              description: 'Experience all premium features with no commitment. Card required for verification only.',
              features: [
                'Full access to all features',
                'Upload unlimited videos',
                'Advanced editing tools',
                'Priority support',
                'No ads during trial',
                'Cancel anytime before trial ends',
              ],
              onPressed: _startFreeTrial,
              primaryColor: Colors.green,
              buttonColor: Colors.green,
              isRecommended: true,
              isFree: true,
            ),
            
            // Monthly Plan
            _buildPlanCard(
              title: 'Monthly Plan',
              price: '₦2,000',
              duration: 'month',
              description: 'Perfect for testing the waters. Full access with monthly flexibility.',
              features: [
                'Full access to all features',
                'Upload unlimited videos',
                'Advanced editing tools',
                'Priority support',
                'Ad-free experience',
                'Monthly billing',
              ],
              onPressed: () => _choosePaidPlan('Monthly', 2000),
              primaryColor: secondaryColor,
              buttonColor: Colors.grey[700]!,
            ),
            
            // Annual Plan
            _buildPlanCard(
              title: 'Annual Plan',
              price: '₦20,000',
              duration: 'year',
              description: 'Best value! Save 17% compared to monthly billing. Most popular choice.',
              features: [
                'Everything in Monthly Plan',
                'Save ₦4,000 per year',
                'Get verification badge (✓)',
                'Priority customer support',
                'Early access to new features',
                'Advanced analytics',
                'Exclusive content creation tools',
              ],
              onPressed: () => _choosePaidPlan('Annual', 20000),
              primaryColor: secondaryColor,
              buttonColor: secondaryColor,
            ),
            
            const SizedBox(height: 30),
            
            // Footer information
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.security,
                    color: secondaryColor,
                    size: 24,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Secure Payment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your payment information is encrypted and secure. Cancel anytime from your account settings.',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
