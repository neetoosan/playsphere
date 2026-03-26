import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PaymentBankScreen extends StatelessWidget {
  final String planType;
  final int amount;
  final String reference;

  const PaymentBankScreen({
    Key? key,
    required this.planType,
    required this.amount,
    required this.reference,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Transfer'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Use the following bank details to make a transfer:'),
            const SizedBox(height: 20),
            Text('Account Name: PlaySphere'),
            Text('Account Number: 1234567890'),
            Text('Bank Name: Bank Of Test'),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('I have made the transfer'),
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

