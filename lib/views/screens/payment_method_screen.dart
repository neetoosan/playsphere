import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants.dart';
import '../../services/payment_service.dart';
import '../../services/paystack_service.dart';
import 'payment_card_screen.dart';
import 'payment_bank_screen.dart';
import 'payment_ussd_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String planType;
  final int amount;
  final String reference;

  const PaymentMethodScreen({
    Key? key,
    required this.planType,
    required this.amount,
    required this.reference,
  }) : super(key: key);

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final PaymentService _paymentService = Get.find<PaymentService>();
  PaystackService? _paystackService;
  
  @override
  void initState() {
    super.initState();
    // Try to get PaystackService, initialize if not found
    try {
      _paystackService = Get.find<PaystackService>();
    } catch (e) {
      // Initialize PaystackService if not found
      _paystackService = PaystackService();
      Get.put(_paystackService!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Payment Method',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: secondaryColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Plan:',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      Text(
                        widget.planType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount:',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      Text(
                        '₦${widget.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Payment Methods Title
            const Text(
              'Choose Payment Method',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Test Mode Banner
            if (_paystackService?.isTestMode() ?? false)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Test Mode: You can use fake cards for testing',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Payment Method Options
            _buildPaymentMethodOption(
              icon: Icons.credit_card,
              title: 'Card Payment',
              subtitle: 'Pay with Debit/Credit Card',
              onTap: () => _navigateToCardPayment(),
            ),
            
            const SizedBox(height: 15),
            
            _buildPaymentMethodOption(
              icon: Icons.account_balance,
              title: 'Bank Transfer',
              subtitle: 'Direct bank transfer',
              onTap: () => _navigateToBankPayment(),
            ),
            
            const SizedBox(height: 15),
            
            _buildPaymentMethodOption(
              icon: Icons.phone_android,
              title: 'USSD Payment',
              subtitle: 'Pay via USSD codes',
              onTap: () => _navigateToUSSDPayment(),
            ),
            
            const SizedBox(height: 30),
            
            // Security Notice
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All payments are secured with 256-bit SSL encryption',
                      style: TextStyle(
                        color: Colors.grey[400],
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

  Widget _buildPaymentMethodOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: secondaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[600],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCardPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentCardScreen(
          planType: widget.planType,
          amount: widget.amount,
          reference: widget.reference,
        ),
      ),
    );
  }

  void _navigateToBankPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentBankScreen(
          planType: widget.planType,
          amount: widget.amount,
          reference: widget.reference,
        ),
      ),
    );
  }

  void _navigateToUSSDPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentUSSDScreen(
          planType: widget.planType,
          amount: widget.amount,
          reference: widget.reference,
        ),
      ),
    );
  }
}
