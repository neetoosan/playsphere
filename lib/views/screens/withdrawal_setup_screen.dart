import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:play_sphere/constants.dart';
import '../../services/earnings_service.dart';

class WithdrawalSetupScreen extends StatefulWidget {
  final int totalViews;
  
  const WithdrawalSetupScreen({
    Key? key,
    required this.totalViews,
  }) : super(key: key);

  @override
  State<WithdrawalSetupScreen> createState() => _WithdrawalSetupScreenState();
}

class _WithdrawalSetupScreenState extends State<WithdrawalSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  
  String? _selectedBank;
  bool _isVerifying = false;
  bool _isSubmitting = false;
  int _totalPaidViews = 0;
  final _withdrawalAmountController = TextEditingController();
  bool _isLoadingProfile = false;
  
  // List of Nigerian banks (Traditional + Digital/Microfinance Banks) - Alphabetically Ordered
  final List<Map<String, String>> _nigerianBanks = [
    {'name': 'Access Bank', 'code': '044'},
    {'name': 'Carbon (Formerly Paylater)', 'code': '565'},
    {'name': 'Citibank Nigeria', 'code': '023'},
    {'name': 'Diamond Bank', 'code': '063'},
    {'name': 'Ecobank Nigeria', 'code': '050'},
    {'name': 'Eyowo', 'code': '50126'},
    {'name': 'Fairmoney Microfinance Bank', 'code': '51318'},
    {'name': 'Fidelity Bank', 'code': '070'},
    {'name': 'First Bank of Nigeria', 'code': '011'},
    {'name': 'First City Monument Bank', 'code': '214'},
    {'name': 'GoMoney', 'code': '100022'},
    {'name': 'Guaranty Trust Bank', 'code': '058'},
    {'name': 'Heritage Bank', 'code': '030'},
    {'name': 'Jaiz Bank', 'code': '301'},
    {'name': 'Keystone Bank', 'code': '082'},
    {'name': 'Kuda Bank', 'code': '090267'},
    {'name': 'Mint MFB', 'code': '50304'},
    {'name': 'Moniepoint', 'code': '50515'},
    {'name': 'Opay', 'code': '999992'},
    {'name': 'Palmpay', 'code': '999991'},
    {'name': 'Paycom', 'code': '50446'},
    {'name': 'Polaris Bank', 'code': '076'},
    {'name': 'Providus Bank', 'code': '101'},
    {'name': 'Renmoney MFB', 'code': '50823'},
    {'name': 'Rubies MFB', 'code': '125'},
    {'name': 'Sparkle Microfinance Bank', 'code': '51310'},
    {'name': 'Stanbic IBTC Bank', 'code': '221'},
    {'name': 'Standard Chartered Bank', 'code': '068'},
    {'name': 'Sterling Bank', 'code': '232'},
    {'name': 'Union Bank of Nigeria', 'code': '032'},
    {'name': 'United Bank For Africa', 'code': '033'},
    {'name': 'Unity Bank', 'code': '215'},
    {'name': 'V Bank', 'code': '035'},
    {'name': 'VFD Microfinance Bank', 'code': '566'},
    {'name': 'Wema Bank', 'code': '035'},
    {'name': 'Zenith Bank', 'code': '057'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchTotalPaidViews();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _withdrawalAmountController.dispose();
    super.dispose();
  }

  // Fetch earnings data using the new earnings service
  Future<void> _fetchTotalPaidViews() async {
    try {
      final userId = authController.userData?.uid;
      if (userId == null) return;

      // Use the earnings service to get accurate data
      final earningsSummary = await EarningsService().getCreatorEarningsSummary(userId);
      
      setState(() {
        _totalPaidViews = earningsSummary['totalPaidViews'] ?? 0;
        _totalLifetimeViews = earningsSummary['totalEarningViews'] ?? 0;
      });
    } catch (e) {
    }
  }

  // Track lifetime views to prevent negative earnings
  int _totalLifetimeViews = 0;

  // Get unpaid views count using lifetime views to ensure never negative
  int get _unpaidViews {
    int unpaidViews = _totalLifetimeViews - _totalPaidViews;
    return unpaidViews < 0 ? 0 : unpaidViews;
  }

  // Check if user is eligible for withdrawal
  bool get _isEligibleForWithdrawal => _unpaidViews >= 1000;

  // Get earnings amount
  double get _earningsAmount => _unpaidViews * 1.0;

  // Get views needed to reach threshold
  int get _viewsNeeded => 1000 - _unpaidViews;

  // Verify account details using Paystack API (you can also use Monnify or Flutterwave)
  Future<void> _verifyAccountDetails() async {
    if (_selectedBank == null || _accountNumberController.text.length != 10) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _accountNameController.clear();
    });

    try {
      // Find the selected bank code
      final bankCode = _nigerianBanks
          .firstWhere((bank) => bank['name'] == _selectedBank)['code'];

      // Auto-verification via Paystack API (replace with actual key)
      // Suggestion: For production, handle this through your backend API for security.
      const String paystackSecretKey = 'sk_test_8256d699498f432dd6944396827503e10d157e28';
      
      final response = await http.get(
        Uri.parse(
          'https://api.paystack.co/bank/resolve?account_number=${_accountNumberController.text}&bank_code=$bankCode'
        ),
        headers: {
          'Authorization': 'Bearer $paystackSecretKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          setState(() {
            _accountNameController.text = data['data']['account_name'];
          });
        } else {
          _showErrorSnackBar('Unable to verify account details. Please check your account number and bank selection.');
        }
      } else {
        _showErrorSnackBar('Failed to verify account details. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Network error. Please check your connection and try again.');
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  // Submit withdrawal request
  Future<void> _submitWithdrawalRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountNameController.text.isEmpty) {
      _showErrorSnackBar('Please verify your account details first.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final enteredAmount = double.tryParse(_withdrawalAmountController.text);
      if (enteredAmount == null || enteredAmount < 1000 || enteredAmount > _unpaidViews * 1.0) {
        _showErrorSnackBar('Invalid withdrawal amount');
        return;
      }

      final userId = authController.userData?.uid;
      if (userId == null) return;

      // Get user's name for admin reference
      String username = 'Unknown User';
      try {
        final userDoc = await firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          username = userData['name'] ?? 'Unknown User';
        }
      } catch (e) {
      }

      // Deduct amount from balance in Firestore immediately
      await firestore.collection('users').doc(userId).update({
        'totalPaidViews': FieldValue.increment(enteredAmount.toInt()),
      });
      
      // Create withdrawal request document
      await firestore.collection('withdrawal_requests').add({
        'userId': userId,
        'username': username,
        'bankName': _selectedBank,
        'accountNumber': _accountNumberController.text,
        'accountName': _accountNameController.text,
        'requestedViews': enteredAmount.toInt(), // Store the requested views count
        'withdrawalAmount': enteredAmount, // Store the actual withdrawal amount
        'status': 'pending',
        'requestDate': FieldValue.serverTimestamp(),
        'processed': false,
      });

      // Update local state immediately to reflect balance deduction
      setState(() {
        _totalPaidViews += enteredAmount.toInt();
      });

      // Show success message and navigate back
      _showSuccessDialog();
    } catch (e) {
      _showErrorSnackBar('Failed to submit withdrawal request. Please try again.');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
    setState(() {
      _isLoadingProfile = true;
    });
    
    // Small delay to show the loading screen
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Withdrawal Request Submitted',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Withdrawal request received. You\'ll be credited shortly.',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Go back to profile with refresh signal
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            SizedBox(height: 24),
            Text(
              'Loading Profile…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatViewCount(int viewCount) {
    if (viewCount < 1000) {
      return viewCount.toString();
    } else if (viewCount < 1000000) {
      double k = viewCount / 1000.0;
      return k % 1 == 0 ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    } else {
      double m = viewCount / 1000000.0;
      return m % 1 == 0 ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    }
  }

  String _formatCurrency(double amount) {
    return '₦${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    // Show loading overlay if loading profile
    if (_isLoadingProfile) {
      return Scaffold(
        body: _buildLoadingOverlay(),
      );
    }
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: _handleBackNavigation,
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        title: const Text(
          'Withdrawal',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Earnings summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: secondaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Earnings Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Views',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatViewCount(widget.totalViews),
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unpaid Views',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatViewCount(_unpaidViews),
                            style: TextStyle(
                              color: _isEligibleForWithdrawal ? Colors.green : Colors.orange,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Earnings',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(_unpaidViews * 1.0),
                            style: TextStyle(
                              color: _isEligibleForWithdrawal ? Colors.green : Colors.orange,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Eligibility check
            if (_isEligibleForWithdrawal) ...[
              // Eligible - show withdrawal form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Withdrawal amount field
                    Text(
                      'Withdrawal Amount',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _withdrawalAmountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter amount to withdraw',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: secondaryColor.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: secondaryColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: secondaryColor,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final amount = double.tryParse(value ?? '');
                        if (amount == null) return 'Enter a valid amount';
                        if (amount < 1000) return 'Minimum withdrawal is ₦1,000';
                        if (amount > _unpaidViews) return 'Cannot exceed available balance';
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Bank Account Details
                    Text(
                      'Bank Account Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Bank selection dropdown
                    Text(
                      'Select Bank',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: secondaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedBank,
                          hint: Text(
                            'Choose your bank',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          dropdownColor: const Color(0xFF2A2A2A),
                          style: const TextStyle(color: Colors.white),
                          items: _nigerianBanks.map((bank) {
                            return DropdownMenuItem<String>(
                              value: bank['name'],
                              child: Text(bank['name']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBank = value;
                              _accountNameController.clear();
                            });
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Account number field
                    Text(
                      'Account Number',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter 10-digit account number',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: secondaryColor.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: secondaryColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: secondaryColor,
                          ),
                        ),
                        suffixIcon: _selectedBank != null && _accountNumberController.text.length == 10
                            ? IconButton(
                                onPressed: _isVerifying ? null : _verifyAccountDetails,
                                icon: _isVerifying
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        Icons.search,
                                        color: secondaryColor,
                                      ),
                              )
                            : null,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your account number';
                        }
                        if (value.length != 10) {
                          return 'Account number must be 10 digits';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (value.length == 10 && _selectedBank != null) {
                          _verifyAccountDetails();
                        } else {
                          setState(() {
                            _accountNameController.clear();
                          });
                        }
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Account name field (read-only)
                    Text(
                      'Account Name',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accountNameController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Account name will appear here after verification',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: secondaryColor.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: secondaryColor.withOpacity(0.3),
                          ),
                        ),
                        suffixIcon: _accountNameController.text.isNotEmpty
                            ? Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : null,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting || _accountNameController.text.isEmpty
                            ? null
                            : _submitWithdrawalRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondaryColor,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : Text(
                                'Submit Withdrawal Request',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Info text
                    Text(
                      'Note: Your withdrawal will be processed as soon as possible. A small processing fee may apply.',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Not eligible message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sorry, you can\'t withdraw funds yet.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You need at least ₦1,000 (1,000 views) to be eligible for withdrawal.',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You currently have ${_formatViewCount(_unpaidViews)} views. You need ${_formatViewCount(_viewsNeeded)} more to reach 1,000.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
