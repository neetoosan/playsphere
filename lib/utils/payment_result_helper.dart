import 'package:flutter/material.dart';
import '../views/screens/payment_result_screen.dart';

class PaymentResultHelper {
  /// Navigate to success payment result screen
  static void showPaymentSuccess({
    required BuildContext context,
    String? customMessage,
  }) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => PaymentResultScreen(
          isSuccess: true,
          message: customMessage ?? "Thank you! Payment successful",
        ),
      ),
      (route) => false, // Remove all previous routes
    );
  }

  /// Navigate to failed payment result screen
  static void showPaymentFailure({
    required BuildContext context,
    String? customMessage,
    String? errorReason,
    String? planType,
    int? amount,
    String? reference,
  }) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => PaymentResultScreen(
          isSuccess: false,
          message: customMessage ?? "Payment failed",
          errorReason: errorReason,
          planType: planType,
          amount: amount,
          reference: reference,
        ),
      ),
      (route) => false, // Remove all previous routes
    );
  }

  /// Navigate to payment result screen with custom parameters
  static void showPaymentResult({
    required BuildContext context,
    required bool isSuccess,
    required String message,
    String? errorReason,
    String? planType,
    int? amount,
    String? reference,
    bool removeAllRoutes = true,
  }) {
    if (removeAllRoutes) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => PaymentResultScreen(
            isSuccess: isSuccess,
            message: message,
            errorReason: errorReason,
            planType: planType,
            amount: amount,
            reference: reference,
          ),
        ),
        (route) => false,
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaymentResultScreen(
            isSuccess: isSuccess,
            message: message,
            errorReason: errorReason,
            planType: planType,
            amount: amount,
            reference: reference,
          ),
        ),
      );
    }
  }

  /// Common error messages for different payment failure scenarios
  static const Map<String, String> commonErrorMessages = {
    'insufficient_funds': 'Insufficient funds in your account',
    'invalid_card': 'Invalid card details provided',
    'expired_card': 'Your card has expired',
    'declined': 'Payment was declined by your bank',
    'network_error': 'Network connection failed. Please try again',
    'timeout': 'Payment request timed out',
    'invalid_otp': 'Invalid OTP entered',
    'blocked_card': 'Your card has been blocked',
    'limit_exceeded': 'Transaction limit exceeded',
    'processing_error': 'Payment processing error occurred',
  };

  /// Get user-friendly error message
  static String getErrorMessage(String? errorCode) {
    if (errorCode == null) return 'Something went wrong. Please try again.';
    return commonErrorMessages[errorCode.toLowerCase()] ?? 
           'Something went wrong. Please try again.';
  }
}
