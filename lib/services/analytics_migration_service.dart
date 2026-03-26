import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants.dart';
import 'earnings_service.dart';

/// Service to handle migration of historical analytics data to ensure proper earnings tracking
class AnalyticsMigrationService extends GetxController {
  static final AnalyticsMigrationService _instance = AnalyticsMigrationService._internal();
  factory AnalyticsMigrationService() => _instance;
  AnalyticsMigrationService._internal();

  /// Migrate all historical view data to ensure proper earnings calculation
  /// This should be run once to fix the disconnect between views and earnings
  Future<void> migrateHistoricalViewsToEarnings() async {
    try {      
      // Step 1: Get all videos with their current view counts
      QuerySnapshot videosSnapshot = await firestore.collection('videos').get();
      
      Map<String, List<VideoAnalytics>> creatorVideoData = {};
      int totalVideos = 0;
      int totalViews = 0;
      
      for (var videoDoc in videosSnapshot.docs) {
        try {
          Map<String, dynamic> videoData = videoDoc.data() as Map<String, dynamic>;
          String videoId = videoDoc.id;
          String creatorId = videoData['uid'] ?? '';
          int viewCount = videoData['viewCount'] ?? 0;
          
          if (creatorId.isNotEmpty && viewCount > 0) {
            if (!creatorVideoData.containsKey(creatorId)) {
              creatorVideoData[creatorId] = [];
            }
            
            creatorVideoData[creatorId]!.add(VideoAnalytics(
              videoId: videoId,
              viewCount: viewCount,
              creatorId: creatorId,
            ));
            
            totalVideos++;
            totalViews += viewCount;
          }
        } catch (e) {
        }
      }      
      // Step 2: For each creator, ensure their earnings reflect all their video views
      int creatorsProcessed = 0;
      int creatorsUpdated = 0;
      
      for (String creatorId in creatorVideoData.keys) {
        try {
          List<VideoAnalytics> videoAnalytics = creatorVideoData[creatorId]!;
          int totalCreatorViews = videoAnalytics.fold(0, (sum, video) => sum + video.viewCount);
          
          // Check current creator earnings
          Map<String, dynamic> currentEarnings = await EarningsService().getCreatorEarningsSummary(creatorId);
          int currentEarningViews = currentEarnings['totalEarningViews'] ?? 0;
                    
          // If creator's earning views don't match their actual video views, migrate the data
          if (totalCreatorViews > currentEarningViews) {
            int viewsToMigrate = totalCreatorViews - currentEarningViews;
            
            await _migrateCreatorViewsToEarnings(creatorId, totalCreatorViews, videoAnalytics);
            creatorsUpdated++;
          } else {
          }
          
          creatorsProcessed++;
        } catch (e) {
          creatorsProcessed++;
        }
      }
            
    } catch (e) {
    }
  }
  
  /// Migrate a specific creator's views to earnings
  Future<void> _migrateCreatorViewsToEarnings(String creatorId, int totalViews, List<VideoAnalytics> videoAnalytics) async {
    try {
      await firestore.runTransaction((transaction) async {
        DocumentReference userRef = firestore.collection('users').doc(creatorId);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        
        Map<String, dynamic> userData = {};
        if (userSnapshot.exists) {
          userData = Map<String, dynamic>.from(userSnapshot.data() as Map<String, dynamic>);
        }
        
        // Preserve existing withdrawal history
        int totalPaidViews = userData['totalPaidViews'] ?? 0;
        
        // Calculate new earnings based on total views
        double totalEarnings = totalViews * EarningsService.earningsPerView;
        double unpaidEarnings = (totalViews - totalPaidViews) * EarningsService.earningsPerView;
        
        // Create video IDs list for tracking
        List<String> videoIds = videoAnalytics.map((v) => v.videoId).toList();
        
        Map<String, dynamic> updateData = {
          'totalEarningViews': totalViews,
          'totalLifetimeViews': totalViews,
          'totalEarnings': totalEarnings,
          'unpaidEarnings': unpaidEarnings,
          'videoIds': videoIds,
          'analyticsTransferDate': FieldValue.serverTimestamp(),
          'lastEarningsUpdate': FieldValue.serverTimestamp(),
        };
        
        if (userSnapshot.exists) {
          transaction.update(userRef, updateData);
        } else {
          // Create new user document if doesn't exist
          updateData.addAll({
            'totalPaidViews': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.set(userRef, updateData, SetOptions(merge: true));
        }
        
      });
    } catch (e) {
    }
  }
  
  /// Verify that earnings are properly synced with analytics for all creators
  Future<Map<String, dynamic>> verifyEarningsAnalyticsSync() async {
    try {      
      // Get all videos and group by creator
      QuerySnapshot videosSnapshot = await firestore.collection('videos').get();
      Map<String, int> creatorActualViews = {};
      
      for (var videoDoc in videosSnapshot.docs) {
        Map<String, dynamic> videoData = videoDoc.data() as Map<String, dynamic>;
        String creatorId = videoData['uid'] ?? '';
        int viewCount = videoData['viewCount'] ?? 0;
        
        if (creatorId.isNotEmpty && viewCount > 0) {
          creatorActualViews[creatorId] = (creatorActualViews[creatorId] ?? 0) + viewCount;
        }
      }
      
      // Compare with earnings data
      List<String> syncedCreators = [];
      List<String> unsyncedCreators = [];
      Map<String, Map<String, int>> discrepancies = {};
      
      for (String creatorId in creatorActualViews.keys) {
        try {
          Map<String, dynamic> earnings = await EarningsService().getCreatorEarningsSummary(creatorId);
          int actualViews = creatorActualViews[creatorId]!;
          int earningViews = earnings['totalEarningViews'] ?? 0;
          
          if (actualViews == earningViews) {
            syncedCreators.add(creatorId);
          } else {
            unsyncedCreators.add(creatorId);
            discrepancies[creatorId] = {
              'actualViews': actualViews,
              'earningViews': earningViews,
              'difference': actualViews - earningViews,
            };
          }
        } catch (e) {
        }
      }
      
      Map<String, dynamic> verificationResult = {
        'totalCreators': creatorActualViews.length,
        'syncedCreators': syncedCreators.length,
        'unsyncedCreators': unsyncedCreators.length,
        'syncPercentage': ((syncedCreators.length / creatorActualViews.length) * 100).toStringAsFixed(1),
        'discrepancies': discrepancies,
      };
      
      
      if (unsyncedCreators.isNotEmpty) {
        for (String creatorId in unsyncedCreators) {
          Map<String, int> discrepancy = discrepancies[creatorId]!;
        }
      }
      
      return verificationResult;
      
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

/// Data class to hold video analytics information
class VideoAnalytics {
  final String videoId;
  final int viewCount;
  final String creatorId;
  
  VideoAnalytics({
    required this.videoId,
    required this.viewCount,
    required this.creatorId,
  });
}
