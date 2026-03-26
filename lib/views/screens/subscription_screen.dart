import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants.dart';
import '../../services/payment_service.dart';
import '../../services/paystack_service.dart';
import 'add_video.dart';
import 'home_screen.dart';
import 'payment_method_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  final PaymentService _paymentService = Get.put(PaymentService());
  final PaystackService _paystackService = Get.put(PaystackService());

  @override
  void initState() {
    super.initState();
    // Subscription check is now handled by SubscriptionWrapper
    // This screen will only be shown to users without active subscriptions
  }

  void _startPayment(BuildContext context, int amount, String planType) {
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

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String duration,
    required List<String> features,
    required VoidCallback onPressed,
    bool isPopular = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: isPopular 
            ? Border.all(color: secondaryColor, width: 2)
            : Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPopular)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: secondaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: secondaryColor,
                  ),
                ),
                Text(
                  '/$duration',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: secondaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPopular ? secondaryColor : Colors.grey[700],
                  foregroundColor: isPopular ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
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
                        'Choose $title',
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
          'Upgrade Your Plan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                    Icons.upgrade,
                    size: 50,
                    color: secondaryColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unlock monetization and advanced features to maximize your content creation potential.',
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
            
            // Monthly Plan
            _buildPlanCard(
              title: 'Monthly Plan',
              price: '₦2,000',
              duration: 'month',
              features: [
                'Full access to all features',
                'Upload unlimited videos',
                'Advanced editing tools',
                'Priority support',
                'Ad-free experience',
                'Monetization enabled',
                'Advanced analytics',
              ],
              onPressed: () => _startPayment(context, 2000, 'Monthly'),
            ),
            
            // Annual Plan
            _buildPlanCard(
              title: 'Annual Plan',
              price: '₦20,000',
              duration: 'year',
              features: [
                'Everything in Monthly Plan',
                'Save ₦4,000 per year',
                'Get verification badge (✓)',
                'Priority customer support',
                'Early access to new features',
                'Advanced analytics dashboard',
                'Exclusive content creation tools',
                'Enhanced monetization features',
                'Premium content library access',
              ],
              onPressed: () => _startPayment(context, 20000, 'Annual'),
              isPopular: true,
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

