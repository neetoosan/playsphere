import 'package:flutter/material.dart';
import '../../constants.dart';

class SubscriptionBadge extends StatelessWidget {
  final double size;
  final EdgeInsets margin;
  
  const SubscriptionBadge({
    Key? key,
    this.size = 16.0,
    this.margin = const EdgeInsets.only(left: 4.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Icon(
        Icons.verified,
        color: Colors.green,
        size: size,
      ),
    );
  }
}

/// Helper function to check if a user has an active annual subscription
Future<bool> hasActiveAnnualSubscription(String userId) async {
  try {
    final subscriptionDoc = await firestore
        .collection('subscriptions')
        .doc(userId)
        .get();

    if (!subscriptionDoc.exists) return false;

    final data = subscriptionDoc.data()!;
    final planType = data['planType'] as String?;
    final expiryDate = data['expiryDate'];
    final isActive = data['isActive'] as bool? ?? false;

    // Check if it's an active annual subscription
    if (planType != null && 
        planType.toLowerCase().contains('annual') && 
        isActive && 
        expiryDate != null) {
      final expiry = (expiryDate as dynamic).toDate() as DateTime;
      return expiry.isAfter(DateTime.now());
    }

    return false;
  } catch (e) {
    return false;
  }
}

/// Widget that shows subscription badge only for annual subscribers
class ConditionalSubscriptionBadge extends StatelessWidget {
  final String userId;
  final double size;
  final EdgeInsets margin;
  
  const ConditionalSubscriptionBadge({
    Key? key,
    required this.userId,
    this.size = 16.0,
    this.margin = const EdgeInsets.only(left: 4.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasActiveAnnualSubscription(userId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          return SubscriptionBadge(size: size, margin: margin);
        }
        return const SizedBox.shrink();
      },
    );
  }
}
