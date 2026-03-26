import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:play_sphere/constants.dart';
import 'package:play_sphere/views/screens/splash_screen.dart';
import 'package:play_sphere/views/screens/subscription_screen.dart';
import 'firebase_options.dart';

import 'controllers/auth_controllers.dart';
import 'controllers/app_lifecycle_manager.dart';
import 'services/payment_service.dart';
import 'services/paystack_service.dart';
import 'services/autoplay_service.dart';
import 'services/video_view_service.dart';
import 'services/earnings_service.dart';
import 'services/analytics_migration_service.dart';
import 'services/historical_analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if Firebase is already initialized
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      // Firebase is already initialized, continue
    } else {
      // Re-throw other errors
      rethrow;
    }
  }
  
  // Initialize controllers and services
  Get.put(AuthController());
  Get.put(PaymentService());
  Get.put(PaystackService());
  Get.put(AppLifecycleManager()); // Initialize global video lifecycle manager
  
  // Initialize autoplay service for cross-platform support
  AutoplayService().initialize();
  
  // Register and initialize video view tracking service
  final videoViewService = VideoViewService();
  Get.put(videoViewService);
  videoViewService.initialize();
  
  // Initialize earnings service for monetization calculations
  final earningsService = EarningsService();
  Get.put(earningsService);
  
  // Initialize analytics migration service for view-to-earnings sync
  final analyticsMigrationService = AnalyticsMigrationService();
  Get.put(analyticsMigrationService);
  
  // Initialize historical analytics service for video deletion preservation
  final historicalAnalyticsService = HistoricalAnalyticsService();
  Get.put(historicalAnalyticsService);
  
  // Trigger comprehensive analytics migration on app start (one-time fix)
  // This ensures all existing views are counted towards creator earnings
  _initializeAnalyticsMigration();
  
  runApp(const MyApp());
}

/// Initialize comprehensive analytics migration
/// This runs once on app start to fix any disconnect between views and earnings
void _initializeAnalyticsMigration() {
  // Run in background to avoid blocking app startup
  Future.delayed(const Duration(seconds: 3), () async {
    try {      
      // Step 1: Migrate historical views to earnings
      final analyticsMigrationService = Get.find<AnalyticsMigrationService>();
      await analyticsMigrationService.migrateHistoricalViewsToEarnings();
      
      // Step 2: Run additional earnings recalculation as backup
      await EarningsService().recalculateHistoricalEarnings();
      
      // Step 3: Verify synchronization
      final verificationResult = await analyticsMigrationService.verifyEarningsAnalyticsSync();      
    } catch (e) {
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: backgroundColor,
        ),
        title: 'PlaySphere',
        home: const SplashScreen(),
        getPages: [
          GetPage(name: '/subscription', page: () => SubscriptionScreen()),
          // Add more routes here
        ],
    );
  }
}
