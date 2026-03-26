import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants.dart';

class PaymentService extends GetxController {
  static PaymentService get instance => Get.find();

  // Store subscription data in Firestore
Future<void> storeSubscription({
    required String userId,
    required String planType,
    required int amount,
    required String reference,
    required String transactionId,
  }) async {
    try {
      DateTime expiryDate;
      
      // Calculate expiry date based on plan type
      if (planType.toLowerCase() == 'monthly') {
        expiryDate = DateTime.now().add(const Duration(days: 30));
      } else {
        expiryDate = DateTime.now().add(const Duration(days: 365));
      }

      await firestore.collection('subscriptions').doc(userId).set({
        'userId': userId,
        'planType': planType,
        'amount': amount,
        'reference': reference,
        'transactionId': transactionId,
        'startDate': DateTime.now(),
        'expiryDate': expiryDate,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Also update user document with subscription status
      await firestore.collection('users').doc(userId).update({
        'hasActiveSubscription': true,
        'subscriptionType': planType,
        'subscriptionExpiry': expiryDate,
      });

    } catch (e) {
      throw e;
    }
  }

  // Start free trial for 7 days
  Future<void> startFreeTrial({
    required String userId,
  }) async {
    try {
      DateTime expiryDate = DateTime.now().add(const Duration(days: 7));

      await firestore.collection('subscriptions').doc(userId).set({
        'userId': userId,
        'planType': 'Free Trial',
        'amount': 0,
        'reference': 'FREE_TRIAL_${DateTime.now().millisecondsSinceEpoch}',
        'transactionId': 'FREE_TRIAL_${DateTime.now().millisecondsSinceEpoch}',
        'startDate': DateTime.now(),
        'expiryDate': expiryDate,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user document with trial status
      await firestore.collection('users').doc(userId).update({
        'hasActiveSubscription': true,
        'subscriptionType': 'Free Trial',
        'subscriptionExpiry': expiryDate,
      });

    } catch (e) {
      throw e;
    }
  }

  // Check if user has active subscription
  Future<bool> hasActiveSubscription(String userId) async {
    try {
      final subscriptionDoc = await firestore
          .collection('subscriptions')
          .doc(userId)
          .get();

      if (!subscriptionDoc.exists) return false;

      final data = subscriptionDoc.data()!;
      final expiryDate = (data['expiryDate'] as Timestamp).toDate();
      final isActive = data['isActive'] as bool;

      // Check if subscription is still active and not expired
      if (isActive && expiryDate.isAfter(DateTime.now())) {
        return true;
      } else {
        // Subscription has expired, update status
        await _deactivateSubscription(userId);
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Deactivate expired subscription
  Future<void> _deactivateSubscription(String userId) async {
    try {
      await firestore.collection('subscriptions').doc(userId).update({
        'isActive': false,
      });

      await firestore.collection('users').doc(userId).update({
        'hasActiveSubscription': false,
      });
    } catch (e) {
    }
  }

  // Check if user has active trial
  Future<bool> hasActiveTrial(String userId) async {
    try {
      final subscriptionDoc = await firestore
          .collection('subscriptions')
          .doc(userId)
          .get();

      if (!subscriptionDoc.exists) return false;

      final data = subscriptionDoc.data()!;
      final planType = data['planType'] as String;
      final expiryDate = (data['expiryDate'] as Timestamp).toDate();
      final isActive = data['isActive'] as bool;

      // Check if it's a free trial and still active
      if (planType == 'Free Trial' && isActive && expiryDate.isAfter(DateTime.now())) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Check if user is eligible for free trial (hasn't used it before)
  Future<bool> isEligibleForFreeTrial(String userId) async {
    try {
      // Check if user has ever had a subscription (including past trials)
      final subscriptionHistory = await firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .get();

      // If no subscription history, user is eligible for trial
      if (subscriptionHistory.docs.isEmpty) {
        return true;
      }

      // Check if any past subscription was a free trial
      for (var doc in subscriptionHistory.docs) {
        final data = doc.data();
        if (data['planType'] == 'Free Trial') {
          return false; // User already used their free trial
        }
      }

      return true; // User has subscriptions but never used free trial
    } catch (e) {
      return false; // Err on the side of caution
    }
  }

  // Get subscription details
  Future<Map<String, dynamic>?> getSubscriptionDetails(String userId) async {
    try {
      final subscriptionDoc = await firestore
          .collection('subscriptions')
          .doc(userId)
          .get();

      if (subscriptionDoc.exists) {
        return subscriptionDoc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
