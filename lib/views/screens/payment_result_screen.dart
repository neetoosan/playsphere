import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants.dart';
import 'home_screen.dart';
import 'payment_method_screen.dart';

class PaymentResultScreen extends StatefulWidget {
  final bool isSuccess;
  final String message;
  final String? errorReason;
  final String? planType;
  final int? amount;
  final String? reference;

  const PaymentResultScreen({
    Key? key,
    required this.isSuccess,
    required this.message,
    this.errorReason,
    this.planType,
    this.amount,
    this.reference,
  }) : super(key: key);

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconAnimationController;
  late AnimationController _scaleAnimationController;
  late Animation<double> _iconAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Icon animation controller (for rotation/bounce effect)
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Scale animation controller (for pop-in effect)
    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Icon rotation/bounce animation
    _iconAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconAnimationController,
      curve: Curves.elasticOut,
    ));
    
    // Scale pop-in animation
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.bounceOut,
    ));
    
    // Start animations
    _scaleAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _iconAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _scaleAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top -
                         MediaQuery.of(context).padding.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor,
                    Colors.grey[900]!,
                    backgroundColor,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top spacer
                  const SizedBox(height: 40),
                  
                  // Animated icon section
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: RotationTransition(
                      turns: _iconAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isSuccess 
                              ? secondaryColor.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          boxShadow: [
                            BoxShadow(
                              color: widget.isSuccess 
                                  ? secondaryColor.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.isSuccess 
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 80,
                          color: widget.isSuccess 
                              ? secondaryColor
                              : Colors.red,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Main message
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 1000),
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: widget.isSuccess 
                            ? secondaryColor
                            : Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Success subtitle
                  if (widget.isSuccess)
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 1200),
                      child: Text(
                        "Your subscription is now active!",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[300],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  // Error reason (for failed payments)
                  if (!widget.isSuccess && widget.errorReason != null)
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 1200),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 24,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Reason:",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.errorReason!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[300],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Flexible spacer to push button to bottom
                  const SizedBox(height: 60),
                  
                  // Action buttons section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      children: [
                        // Primary action button
                        AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 1400),
                          child: GestureDetector(
                            onTap: _handlePrimaryAction,
                            child: Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: widget.isSuccess
                                      ? [secondaryColor, secondaryColor.withOpacity(0.8)]
                                      : [Colors.orange, Colors.orange.withOpacity(0.8)],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.isSuccess
                                        ? secondaryColor.withOpacity(0.4)
                                        : Colors.orange.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    widget.isSuccess 
                                        ? Icons.video_call
                                        : Icons.refresh,
                                    color: Colors.black,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    widget.isSuccess 
                                        ? "DONE"
                                        : "Try Another Payment Method",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Secondary action for failed payments
                        if (!widget.isSuccess) ...[
                          const SizedBox(height: 15),
                          AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 1600),
                            child: GestureDetector(
                              onTap: _handleRetry,
                              child: Container(
                                width: double.infinity,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(27.5),
                                  border: Border.all(
                                    color: Colors.grey[600]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.replay,
                                      color: secondaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Retry Payment",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Bottom spacer
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handlePrimaryAction() {
    if (widget.isSuccess) {
      // Navigate to Home Screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false, // Remove all previous routes
      );
    } else {
      // Navigate back to payment method selection
      _navigateToPaymentMethods();
    }
  }

  void _handleRetry() {
    if (!widget.isSuccess && 
        widget.planType != null && 
        widget.amount != null && 
        widget.reference != null) {
      // Generate new reference for retry
      final newReference = '${widget.reference}_retry_${DateTime.now().millisecondsSinceEpoch}';
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PaymentMethodScreen(
            planType: widget.planType!,
            amount: widget.amount!,
            reference: newReference,
          ),
        ),
      );
    }
  }

  void _navigateToPaymentMethods() {
    if (widget.planType != null && 
        widget.amount != null && 
        widget.reference != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PaymentMethodScreen(
            planType: widget.planType!,
            amount: widget.amount!,
            reference: widget.reference!,
          ),
        ),
      );
    } else {
      // Fallback - just go back
      Navigator.of(context).pop();
    }
  }
}
