import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class PaystackService extends GetxController {
  static PaystackService get instance => Get.find();

  // Paystack test keys - Replace with your actual keys
  static const String publicKey = 'pk_test_4bc38349444a3984a31309a85f0771f533a9809f';
  static const String secretKey = 'sk_test_f3de952647d2b67dc0df1026dc0fb5329e791bdf';
  static const String baseUrl = 'https://api.paystack.co';

  // Test card data for Paystack testing
  static const Map<String, Map<String, dynamic>> testCards = {
    'success_card': {
      'number': '4084084084084081',
      'expiry': '12/25',
      'cvv': '408',
      'pin': '0000',
      'type': 'Visa',
      'description': 'Successful transaction',
    },
    'insufficient_funds': {
      'number': '4084084084084081',
      'expiry': '12/25',
      'cvv': '408',
      'pin': '1111',
      'type': 'Visa',
      'description': 'Insufficient funds',
    },
    'declined_card': {
      'number': '5060666666666666666',
      'expiry': '12/25',
      'cvv': '123',
      'pin': '1234',
      'type': 'Verve',
      'description': 'Declined transaction',
    },
    'timeout_card': {
      'number': '5060666666666666666',
      'expiry': '12/25',
      'cvv': '123',
      'pin': '0000',
      'type': 'Verve',
      'description': 'Transaction timeout',
    },
  };

  // Initialize payment transaction
  Future<Map<String, dynamic>?> initializeTransaction({
    required String email,
    required int amount,
    required String reference,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/transaction/initialize');
      final headers = {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/json',
      };

      final body = json.encode({
        'email': email,
        'amount': amount * 100, // Paystack expects amount in kobo
        'reference': reference,
        'metadata': metadata ?? {},
      });

      final response = await http.post(url, headers: headers, body: body);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == true) {
        return responseData['data'];
      } else {
        throw Exception(responseData['message'] ?? 'Failed to initialize transaction');
      }
    } catch (e) {
      return null;
    }
  }

  // Verify transaction
  Future<Map<String, dynamic>?> verifyTransaction(String reference) async {
    try {
      final url = Uri.parse('$baseUrl/transaction/verify/$reference');
      final headers = {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/json',
      };

      final response = await http.get(url, headers: headers);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == true) {
        return responseData['data'];
      } else {
        throw Exception(responseData['message'] ?? 'Failed to verify transaction');
      }
    } catch (e) {
      return null;
    }
  }

  // For testing - create a simulated successful transaction
  Future<Map<String, dynamic>> createTestTransaction({
    required String email,
    required int amount,
    required String reference,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));

    // Return a mock successful transaction
    return {
      'status': 'success',
      'reference': reference,
      'amount': amount * 100,
      'gateway_response': 'Successful',
      'paid_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'channel': 'card',
      'currency': 'NGN',
      'customer': {
        'email': email,
      },
      'authorization': {
        'authorization_code': 'AUTH_test_${DateTime.now().millisecondsSinceEpoch}',
        'card_type': 'visa',
        'last4': '1234',
        'brand': 'visa',
      }
    };
  }

  // Launch Paystack checkout (for web/mobile web)
  String getCheckoutUrl({
    required String email,
    required int amount,
    required String reference,
    String? callbackUrl,
  }) {
    final baseCheckoutUrl = 'https://checkout.paystack.com';
    final params = {
      'key': publicKey,
      'email': email,
      'amount': (amount * 100).toString(),
      'ref': reference,
      if (callbackUrl != null) 'callback_url': callbackUrl,
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$baseCheckoutUrl?$queryString';
  }

  // Validate Paystack public key format
  bool isValidPublicKey(String key) {
    return key.startsWith('pk_test_') || key.startsWith('pk_live_');
  }

  // Check if we're using test keys
  bool isTestMode() {
    return publicKey.startsWith('pk_test_');
  }
}
