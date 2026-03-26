// This file shows how to integrate the PaymentResultScreen into your existing payment flow
// Copy these examples into your actual payment screens

import 'package:flutter/material.dart';
import '../utils/payment_result_helper.dart';

class PaymentIntegrationExamples {
  
  // Example 1: Successful payment flow
  static void handleSuccessfulPayment(BuildContext context) {
    // After successful payment processing...
    PaymentResultHelper.showPaymentSuccess(
      context: context,
      customMessage: "Thank you! Payment successful",
    );
  }
  
  // Example 2: Failed payment with error details
  static void handleFailedPayment({
    required BuildContext context,
    required String planType,
    required int amount,
    required String reference,
    String? errorCode,
    String? customErrorMessage,
  }) {
    // Get user-friendly error message
    final errorReason = PaymentResultHelper.getErrorMessage(errorCode);
    
    PaymentResultHelper.showPaymentFailure(
      context: context,
      customMessage: customErrorMessage ?? "Payment failed",
      errorReason: errorReason,
      planType: planType,
      amount: amount,
      reference: reference,
    );
  }
  
  // Example 3: How to modify your existing payment processing method
  static Future<void> processPaymentExample({
    required BuildContext context,
    required String planType,
    required int amount,
    required String reference,
    required Map<String, dynamic> paymentData,
  }) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Process payment (replace with your actual payment logic)
      final result = await _mockPaymentProcessing(paymentData);
      
      // Hide loading indicator
      Navigator.of(context).pop();
      
      if (result['success'] == true) {
        // Payment successful
        PaymentResultHelper.showPaymentSuccess(
          context: context,
          customMessage: "Thank you! Payment successful",
        );
      } else {
        // Payment failed
        PaymentResultHelper.showPaymentFailure(
          context: context,
          customMessage: "Payment failed",
          errorReason: PaymentResultHelper.getErrorMessage(result['error_code']),
          planType: planType,
          amount: amount,
          reference: reference,
        );
      }
    } catch (e) {
      // Hide loading indicator if still showing
      Navigator.of(context).pop();
      
      // Handle unexpected errors
      PaymentResultHelper.showPaymentFailure(
        context: context,
        customMessage: "Something went wrong",
        errorReason: "An unexpected error occurred. Please try again.",
        planType: planType,
        amount: amount,
        reference: reference,
      );
    }
  }
  
  // Mock payment processing for demonstration
  static Future<Map<String, dynamic>> _mockPaymentProcessing(
    Map<String, dynamic> paymentData
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Mock different outcomes
    final random = DateTime.now().microsecond % 100;
    
    if (random < 70) {
      // 70% success rate
      return {'success': true};
    } else if (random < 85) {
      // 15% insufficient funds
      return {'success': false, 'error_code': 'insufficient_funds'};
    } else if (random < 95) {
      // 10% declined
      return {'success': false, 'error_code': 'declined'};
    } else {
      // 5% network error
      return {'success': false, 'error_code': 'network_error'};
    }
  }
}

/*
  TO INTEGRATE INTO YOUR EXISTING PAYMENT SCREENS:

  1. Import the helper at the top of your payment screen file:
     import '../utils/payment_result_helper.dart';

  2. Replace your current success navigation with:
     PaymentResultHelper.showPaymentSuccess(context: context);

  3. Replace your current error handling with:
     PaymentResultHelper.showPaymentFailure(
       context: context,
       errorReason: "Specific error message",
       planType: widget.planType,
       amount: widget.amount,
       reference: widget.reference,
     );

  4. For more complex scenarios, use:
     PaymentResultHelper.showPaymentResult(
       context: context,
       isSuccess: paymentWasSuccessful,
       message: "Custom message",
       errorReason: errorDetails,
       planType: widget.planType,
       amount: widget.amount,
       reference: widget.reference,
     );

  EXAMPLE FOR payment_card_screen.dart:
  
  In your _processPayment() method, replace the current navigation with:
  
  if (success) {
    PaymentResultHelper.showPaymentSuccess(context: context);
  } else {
    PaymentResultHelper.showPaymentFailure(
      context: context,
      errorReason: errorMessage,
      planType: widget.planType,
      amount: widget.amount,
      reference: widget.reference,
    );
  }
*/
