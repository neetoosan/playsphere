import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PaymentUSSDScreen extends StatelessWidget {
  final String planType;
  final int amount;
  final String reference;

  const PaymentUSSDScreen({
    Key? key,
    required this.planType,
    required this.amount,
    required this.reference,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('USSD Payment'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Dial the following USSD codes to pay:'),
            const SizedBox(height: 20),
            Text('GTBank: *737*000*Amount#'),
            Text('Access Bank: *901*000*Amount#'),
            Text('First Bank: *894*000*Amount#'),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('I have completed the payment'),
              onPressed: () {
                Get.snackbar(
                  'Pending Verification',
                  'Your payment will be verified shortly.',
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
