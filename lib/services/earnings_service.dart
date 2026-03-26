import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

/// Service to handle creator earnings and monetization calculations
class EarningsService {
  static final EarningsService _instance = EarningsService._internal();
  factory EarningsService() => _instance;
  EarningsService._internal();

  static const double _earningsPerView = 1.0; // ₦1 per view
  
  /// Update creator's earnings when a valid view is recorded
  Future<void> updateCreatorEarnings(String videoId, String creatorUserId) async {
    try {      
      await firestore.runTransaction((transaction) async {
        // Get the creator's user document
        DocumentReference userRef = firestore.collection('users').doc(creatorUserId);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        
        Map<String, dynamic> userData = {};
        if (userSnapshot.exists) {
          userData = Map<String, dynamic>.from(userSnapshot.data() as Map<String, dynamic>);
        }
        
        // Get current earnings tracking fields
        int totalEarningViews = userData['totalEarningViews'] ?? 0;
        int totalLifetimeViews = userData['totalLifetimeViews'] ?? 0;
        int totalPaidViews = userData['totalPaidViews'] ?? 0;
        double totalEarnings = (userData['totalEarnings'] ?? 0.0).toDouble();
        
        // Increment earning views and total earnings
        int newTotalEarningViews = totalEarningViews + 1;
        double newTotalEarnings = totalEarnings + _earningsPerView;
        
        // Update lifetime views to ensure it's at least as much as earning views
        int newTotalLifetimeViews = totalLifetimeViews;
        if (newTotalEarningViews > newTotalLifetimeViews) {
          newTotalLifetimeViews = newTotalEarningViews;
        }
        
        // Calculate unpaid earnings
        double unpaidEarnings = (newTotalEarningViews - totalPaidViews) * _earningsPerView;
        
        // Update the user document with new earnings data
        Map<String, dynamic> updateData = {
          'totalEarningViews': newTotalEarningViews,
          'totalLifetimeViews': newTotalLifetimeViews,
          'totalEarnings': newTotalEarnings,
          'unpaidEarnings': unpaidEarnings,
          'lastEarningsUpdate': FieldValue.serverTimestamp(),
        };
        
        if (userSnapshot.exists) {
          transaction.update(userRef, updateData);
        } else {
          // Create the user document if it doesn't exist
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
  
  /// Recalculate historical earnings for all creators based on current views
  /// This method should be called once to fix historical data
  Future<void> recalculateHistoricalEarnings() async {
    try {      
      // Get all videos to calculate earnings per creator
      QuerySnapshot videosSnapshot = await firestore.collection('videos').get();
      
      // Group views by creator with detailed tracking
      Map<String, int> creatorViewCounts = {};
      Map<String, List<String>> creatorVideos = {};
      Map<String, List<int>> creatorVideoViews = {}; // Track views per video for debugging
      int totalVideosProcessed = 0;
      int totalViewsFound = 0;
      
      for (var videoDoc in videosSnapshot.docs) {
        try {
          Map<String, dynamic> videoData = videoDoc.data() as Map<String, dynamic>;
          String creatorId = videoData['uid'] ?? '';
          int viewCount = videoData['viewCount'] ?? 0;
          
          totalVideosProcessed++;
          
          if (creatorId.isNotEmpty && viewCount > 0) {
            creatorViewCounts[creatorId] = (creatorViewCounts[creatorId] ?? 0) + viewCount;
            creatorVideos[creatorId] = (creatorVideos[creatorId] ?? [])..add(videoDoc.id);
            creatorVideoViews[creatorId] = (creatorVideoViews[creatorId] ?? [])..add(viewCount);
            totalViewsFound += viewCount;
            
          } else if (creatorId.isEmpty) {
          }
        } catch (e) {
        }
      }
            
      // Log detailed creator stats
      for (String creatorId in creatorViewCounts.keys) {
        int totalViews = creatorViewCounts[creatorId]!;
        int videoCount = creatorVideos[creatorId]!.length;
        List<int> videoViews = creatorVideoViews[creatorId] ?? [];
        double expectedEarnings = totalViews * _earningsPerView;
        
      }
      
      // Update earnings for each creator
      int successfulUpdates = 0;
      for (String creatorId in creatorViewCounts.keys) {
        try {
          int totalViews = creatorViewCounts[creatorId]!;
          List<String> videoIds = creatorVideos[creatorId]!;
          
          await _updateCreatorHistoricalEarnings(creatorId, totalViews, videoIds);
          successfulUpdates++;
        } catch (e) {
        }
      }
      
    } catch (e) {
    }
  }
  
  /// Update historical earnings for a specific creator
  Future<void> _updateCreatorHistoricalEarnings(String creatorId, int totalViews, List<String> videoIds) async {
    try {
      await firestore.runTransaction((transaction) async {
        DocumentReference userRef = firestore.collection('users').doc(creatorId);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        
        Map<String, dynamic> userData = {};
        if (userSnapshot.exists) {
          userData = Map<String, dynamic>.from(userSnapshot.data() as Map<String, dynamic>);
        }
        
        // Get current paid views to preserve withdrawal history
        int totalPaidViews = userData['totalPaidViews'] ?? 0;
        
        // Only update if the historical views are higher than current earning views
        int currentEarningViews = userData['totalEarningViews'] ?? 0;
        
        if (totalViews > currentEarningViews) {
          double totalEarnings = totalViews * _earningsPerView;
          double unpaidEarnings = (totalViews - totalPaidViews) * _earningsPerView;
          
          Map<String, dynamic> updateData = {
            'totalEarningViews': totalViews,
            'totalLifetimeViews': totalViews,
            'totalEarnings': totalEarnings,
            'unpaidEarnings': unpaidEarnings,
            'videoIds': videoIds, // Track which videos contributed to earnings
            'historicalRecalculationDate': FieldValue.serverTimestamp(),
            'lastEarningsUpdate': FieldValue.serverTimestamp(),
          };
          
          if (userSnapshot.exists) {
            transaction.update(userRef, updateData);
          } else {
            updateData.addAll({
              'totalPaidViews': 0,
              'createdAt': FieldValue.serverTimestamp(),
            });
            transaction.set(userRef, updateData, SetOptions(merge: true));
          }
          
        } else {
        }
      });
    } catch (e) {
    }
  }
  
  /// Get creator earnings summary
  Future<Map<String, dynamic>> getCreatorEarningsSummary(String creatorId) async {
    try {
      DocumentSnapshot userDoc = await firestore.collection('users').doc(creatorId).get();
      
      if (!userDoc.exists) {
        return {
          'totalEarningViews': 0,
          'totalEarnings': 0.0,
          'unpaidEarnings': 0.0,
          'totalPaidViews': 0,
        };
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      return {
        'totalEarningViews': userData['totalEarningViews'] ?? 0,
        'totalEarnings': (userData['totalEarnings'] ?? 0.0).toDouble(),
        'unpaidEarnings': (userData['unpaidEarnings'] ?? 0.0).toDouble(),
        'totalPaidViews': userData['totalPaidViews'] ?? 0,
        'lastUpdate': userData['lastEarningsUpdate'],
      };
    } catch (e) {
      return {
        'totalEarningViews': 0,
        'totalEarnings': 0.0,
        'unpaidEarnings': 0.0,
        'totalPaidViews': 0,
      };
    }
  }
  
  /// Calculate earnings from view count
  static double calculateEarnings(int viewCount) {
    return viewCount * _earningsPerView;
  }
  
  /// Get earnings per view rate
  static double get earningsPerView => _earningsPerView;
}
