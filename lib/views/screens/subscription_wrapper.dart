import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants.dart';
import '../../services/payment_service.dart';
import 'subscription_screen.dart';
import 'add_video.dart';

/// Wrapper that checks subscription status before showing the subscription screen
/// Prevents the brief flicker of pricing screen for already subscribed users
class SubscriptionWrapper extends StatefulWidget {
  const SubscriptionWrapper({super.key});

  @override
  State<SubscriptionWrapper> createState() => _SubscriptionWrapperState();
}

class _SubscriptionWrapperState extends State<SubscriptionWrapper> {
  final PaymentService _paymentService = Get.put(PaymentService());
  bool _isCheckingSubscription = true;
  bool _hasActiveSubscription = false;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final userId = authController.userData?.uid;
      if (userId != null) {
        final hasSubscription = await _paymentService.hasActiveSubscription(userId);
        final hasTrial = await _paymentService.hasActiveTrial(userId);
        if (mounted) {
          setState(() {
            _hasActiveSubscription = hasSubscription || hasTrial;
            _isCheckingSubscription = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasActiveSubscription = false;
            _isCheckingSubscription = false;
          });
        }
      }
    } catch (e) {
      // If there's an error checking subscription, assume no subscription
      // and show the pricing screen to be safe
      if (mounted) {
        setState(() {
          _hasActiveSubscription = false;
          _isCheckingSubscription = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSubscription) {
      // Show loading screen while checking subscription
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                'Checking subscription status...',
                style: TextStyle(
                  color: buttonColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If user has active subscription, go directly to add video screen
    if (_hasActiveSubscription) {
      return const AddVideoScreen();
    }

    // If user doesn't have subscription, show pricing screen
    return const SubscriptionScreen();
  }
}
