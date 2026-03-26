import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants.dart';
import '../../services/payment_service.dart';

class SubscriptionCheckIcon extends StatelessWidget {
  final String userId;
  final double size;
  final EdgeInsets? padding;

  const SubscriptionCheckIcon({
    Key? key,
    required this.userId,
    this.size = 16.0,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PaymentService.instance.hasActiveSubscription(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // Don't show anything while loading
        }
        
        if (snapshot.hasData && snapshot.data == true) {
          return Padding(
            padding: padding ?? const EdgeInsets.only(left: 4.0),
            child: Icon(
              Icons.check_circle,
              color: secondaryColor,
              size: size,
            ),
          );
        }
        
        return const SizedBox.shrink(); // Don't show icon if not subscribed
      },
    );
  }
}
