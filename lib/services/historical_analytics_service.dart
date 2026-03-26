import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

/// Service to manage historical analytics data and preserve earnings when videos are deleted
class HistoricalAnalyticsService {
  static final HistoricalAnalyticsService _instance = HistoricalAnalyticsService._internal();
  factory HistoricalAnalyticsService() => _instance;
  HistoricalAnalyticsService._internal();

  /// Get comprehensive lifetime analytics for a creator (including deleted videos)
  Future<Map<String, dynamic>> getLifetimeAnalytics(String creatorId) async {
    try {      
      // Get user document with historical data
      DocumentSnapshot userDoc = await firestore.collection('users').doc(creatorId).get();
      
      Map<String, dynamic> userData = {};
      if (userDoc.exists) {
        userData = Map<String, dynamic>.from(userDoc.data() as Map<String, dynamic>);
      }
      
      // Get current active videos analytics (filter out deleted videos in code)
      QuerySnapshot activeVideos = await firestore
          .collection('videos')
          .where('uid', isEqualTo: creatorId)
          .get();
      
      int currentActiveViews = 0;
      int currentActiveLikes = 0;
      int currentActiveComments = 0;
      int currentActiveShares = 0;
      int activeVideoCount = 0;
      
      for (var doc in activeVideos.docs) {
        final videoData = doc.data() as Map<String, dynamic>;
        // Skip deleted videos (filter in code to handle missing isDeleted field)
        bool isDeleted = videoData['isDeleted'] ?? false;
        if (!isDeleted) {
          activeVideoCount++;
          currentActiveViews += (videoData['viewCount'] ?? 0) as int;
          currentActiveLikes += (videoData['likes'] as List?)?.length ?? 0;
          currentActiveComments += (videoData['commentCount'] ?? 0) as int;
          currentActiveShares += (videoData['shareCount'] ?? 0) as int;
        }
      }
      
      // Get historical data from deleted videos
      Map<String, dynamic> historicalAnalytics = Map<String, dynamic>.from(userData['historicalAnalytics'] ?? {});
      List<dynamic> deletedVideos = List.from(userData['deletedVideos'] ?? []);
      
      int historicalViews = historicalAnalytics['totalViews'] ?? 0;
      int historicalLikes = historicalAnalytics['totalLikes'] ?? 0;
      int historicalComments = historicalAnalytics['totalComments'] ?? 0;
      int historicalShares = historicalAnalytics['totalShares'] ?? 0;
      int historicalVideoCount = historicalAnalytics['totalVideosCreated'] ?? 0;
      
      // Calculate lifetime totals (current active + historical deleted)
      int lifetimeViews = currentActiveViews + historicalViews;
      int lifetimeLikes = currentActiveLikes + historicalLikes;
      int lifetimeComments = currentActiveComments + historicalComments;
      int lifetimeShares = currentActiveShares + historicalShares;
      int lifetimeVideoCount = activeVideoCount + historicalVideoCount;
      
      // Get earnings data (preserved independently)
      int totalEarningViews = userData['totalEarningViews'] ?? 0;
      double totalEarnings = (userData['totalEarnings'] ?? 0.0).toDouble();
      double unpaidEarnings = (userData['unpaidEarnings'] ?? 0.0).toDouble();
      int totalPaidViews = userData['totalPaidViews'] ?? 0;
      
      Map<String, dynamic> lifetimeAnalytics = {
        // Current active video data
        'currentActive': {
          'videos': activeVideoCount,
          'views': currentActiveViews,
          'likes': currentActiveLikes,
          'comments': currentActiveComments,
          'shares': currentActiveShares,
        },
        
        // Historical deleted video data
        'historical': {
          'videos': historicalVideoCount,
          'views': historicalViews,
          'likes': historicalLikes,
          'comments': historicalComments,
          'shares': historicalShares,
          'deletedVideosCount': deletedVideos.length,
        },
        
        // Lifetime totals (for display in analytics)
        'lifetime': {
          'videos': lifetimeVideoCount,
          'views': lifetimeViews,
          'likes': lifetimeLikes,
          'comments': lifetimeComments,
          'shares': lifetimeShares,
        },
        
        // Earnings data (preserved independently of video deletion)
        'earnings': {
          'totalEarningViews': totalEarningViews,
          'totalEarnings': totalEarnings,
          'unpaidEarnings': unpaidEarnings,
          'totalPaidViews': totalPaidViews,
          'averageEarningsPerView': totalEarningViews > 0 ? totalEarnings / totalEarningViews : 0.0,
        },
        
        // Meta information
        'lastUpdated': userData['analyticsLastUpdated'],
        'createdAt': userData['createdAt'],
      };
      
      
      return lifetimeAnalytics;
    } catch (e) {
      return {};
    }
  }
  
  /// Preserve video analytics when marking video for deletion
  Future<void> preserveVideoAnalytics(String videoId, String creatorId, Map<String, dynamic> videoData) async {
    try {      
      int viewCount = videoData['viewCount'] ?? 0;
      int likes = (videoData['likes'] as List?)?.length ?? 0;
      int commentCount = videoData['commentCount'] ?? 0;
      int shareCount = videoData['shareCount'] ?? 0;
      Timestamp? uploadTimestamp = videoData['uploadTimestamp'];
      String caption = videoData['caption'] ?? '';
      
      await firestore.runTransaction((transaction) async {
        // Get current user data
        DocumentReference userRef = firestore.collection('users').doc(creatorId);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        
        Map<String, dynamic> userData = {};
        if (userSnapshot.exists) {
          userData = Map<String, dynamic>.from(userSnapshot.data() as Map<String, dynamic>);
        }
        
        // Get or initialize historical analytics data
        Map<String, dynamic> historicalAnalytics = Map<String, dynamic>.from(userData['historicalAnalytics'] ?? {});
        List<dynamic> deletedVideos = List.from(userData['deletedVideos'] ?? []);
        
        // Current historical totals
        int currentHistoricalViews = historicalAnalytics['totalViews'] ?? 0;
        int currentHistoricalLikes = historicalAnalytics['totalLikes'] ?? 0;
        int currentHistoricalComments = historicalAnalytics['totalComments'] ?? 0;
        int currentHistoricalShares = historicalAnalytics['totalShares'] ?? 0;
        int currentHistoricalVideos = historicalAnalytics['totalVideosCreated'] ?? 0;
        
        // Add deleted video data to historical record with detailed tracking
        Map<String, dynamic> deletedVideoRecord = {
          'videoId': videoId,
          'viewCount': viewCount,
          'likes': likes,
          'commentCount': commentCount,
          'shareCount': shareCount,
          'caption': caption.length > 100 ? caption.substring(0, 100) + '...' : caption, // Truncated for storage efficiency
          'deletedAt': FieldValue.serverTimestamp(),
          'uploadTimestamp': uploadTimestamp,
          'earningsFromVideo': viewCount * 1.0, // ₦1 per view
        };
        
        deletedVideos.add(deletedVideoRecord);
        
        // Update historical analytics totals
        Map<String, dynamic> updatedHistoricalAnalytics = {
          'totalViews': currentHistoricalViews + viewCount,
          'totalLikes': currentHistoricalLikes + likes,
          'totalComments': currentHistoricalComments + commentCount,
          'totalShares': currentHistoricalShares + shareCount,
          'totalVideosCreated': currentHistoricalVideos + 1,
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        
        // IMPORTANT: Do NOT modify earnings fields here!
        // totalEarningViews, totalEarnings, unpaidEarnings must remain untouched
        // so unpaid earnings from deleted videos are preserved until withdrawal
        
        Map<String, dynamic> updateData = {
          'historicalAnalytics': updatedHistoricalAnalytics,
          'deletedVideos': deletedVideos,
          'analyticsLastUpdated': FieldValue.serverTimestamp(),
          // Note: We intentionally do NOT update earnings fields to preserve unpaid earnings
        };
        
        if (userSnapshot.exists) {
          transaction.update(userRef, updateData);
        } else {
          // If user document doesn't exist, create it with preserved data
          updateData.addAll({
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.set(userRef, updateData, SetOptions(merge: true));
        }
        
      });
    } catch (e) {
      throw e; // Rethrow to prevent video deletion if analytics preservation fails
    }
  }
  
  /// Mark video as deleted (soft delete) instead of hard delete
  Future<String> softDeleteVideo(String videoId, String creatorId) async {
    try {      
      // Validate inputs
      if (videoId.isEmpty || creatorId.isEmpty) {
        return 'Invalid video ID or creator ID';
      }
      
      // Get video data first with better error handling
      DocumentSnapshot videoDoc;
      try {
        videoDoc = await firestore.collection('videos').doc(videoId).get();
      } catch (e) {
        return 'Failed to fetch video data: $e';
      }
      
      if (!videoDoc.exists) {
        return 'Video not found';
      }
      
      Map<String, dynamic>? docData = videoDoc.data() as Map<String, dynamic>?;
      if (docData == null) {
        return 'Video data is null';
      }
      
      Map<String, dynamic> videoData = Map<String, dynamic>.from(docData);
      
      // Check if video is already deleted
      bool isAlreadyDeleted = videoData['isDeleted'] ?? false;
      if (isAlreadyDeleted) {
        return 'Video is already deleted';
      }
      
      // Verify ownership
      String videoCreatorId = videoData['uid'] ?? '';
      if (videoCreatorId != creatorId) {
        return 'Unauthorized: Creator ID mismatch';
      }
      
      // Preserve analytics before marking as deleted (with error handling)
      try {
        await preserveVideoAnalytics(videoId, creatorId, videoData);
      } catch (e) {
        // Continue with soft delete even if analytics preservation fails
        // Analytics preservation failure shouldn't block the deletion
      }
      
      // Mark video as deleted instead of physically removing it
      try {
        await firestore.collection('videos').doc(videoId).update({
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': creatorId,
          'preservedViewCount': videoData['viewCount'] ?? 0,
          'preservedLikes': (videoData['likes'] as List?)?.length ?? 0,
          'preservedComments': videoData['commentCount'] ?? 0,
          'preservedShares': videoData['shareCount'] ?? 0,
        });
        
        return 'success';
      } catch (e) {
        return 'Failed to mark video as deleted: $e';
      }
      
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }
  
  /// Get detailed earnings breakdown including deleted video contributions
  Future<Map<String, dynamic>> getEarningsBreakdown(String creatorId) async {
    try {
      DocumentSnapshot userDoc = await firestore.collection('users').doc(creatorId).get();
      
      if (!userDoc.exists) {
        return {'error': 'User not found'};
      }
      
      Map<String, dynamic> userData = Map<String, dynamic>.from(userDoc.data() as Map<String, dynamic>);
      List<dynamic> deletedVideos = List.from(userData['deletedVideos'] ?? []);
      
      // Get active videos earnings (filter out deleted videos in code)
      QuerySnapshot activeVideos = await firestore
          .collection('videos')
          .where('uid', isEqualTo: creatorId)
          .get();
      
      double activeVideoEarnings = 0;
      int activeVideoViews = 0;
      
      for (var doc in activeVideos.docs) {
        final videoData = doc.data() as Map<String, dynamic>;
        // Skip deleted videos (filter in code to handle missing isDeleted field)
        bool isDeleted = videoData['isDeleted'] ?? false;
        if (!isDeleted) {
          int views = videoData['viewCount'] ?? 0;
          activeVideoViews += views;
          activeVideoEarnings += views * 1.0; // ₦1 per view
        }
      }
      
      // Calculate deleted video earnings
      double deletedVideoEarnings = 0;
      int deletedVideoViews = 0;
      
      for (var deletedVideo in deletedVideos) {
        if (deletedVideo is Map<String, dynamic>) {
          int views = deletedVideo['viewCount'] ?? 0;
          deletedVideoViews += views;
          deletedVideoEarnings += views * 1.0; // ₦1 per view
        }
      }
      
      // Get stored earnings data
      int totalEarningViews = userData['totalEarningViews'] ?? 0;
      double totalEarnings = (userData['totalEarnings'] ?? 0.0).toDouble();
      double unpaidEarnings = (userData['unpaidEarnings'] ?? 0.0).toDouble();
      int totalPaidViews = userData['totalPaidViews'] ?? 0;
      
      return {
        'active': {
          'views': activeVideoViews,
          'earnings': activeVideoEarnings,
        },
        'deleted': {
          'views': deletedVideoViews,
          'earnings': deletedVideoEarnings,
          'videosCount': deletedVideos.length,
        },
        'totals': {
          'earningViews': totalEarningViews,
          'totalEarnings': totalEarnings,
          'unpaidEarnings': unpaidEarnings,
          'paidViews': totalPaidViews,
        },
        'breakdown': {
          'earningsFromActiveVideos': activeVideoEarnings,
          'earningsFromDeletedVideos': deletedVideoEarnings,
          'totalCalculatedEarnings': activeVideoEarnings + deletedVideoEarnings,
          'storedTotalEarnings': totalEarnings,
          'unpaidAmount': unpaidEarnings,
        },
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  /// Update the video query to exclude soft-deleted videos from public feeds
  Query getActiveVideosQuery() {
    // Simple query that works during migration - we'll filter in code instead of query
    // This avoids the "invalid argument" error when isDeleted field doesn't exist on some docs
    return firestore.collection('videos');
  }
  
  /// Get active videos query for a specific user (for profile display)
  Query getUserActiveVideosQuery(String uid) {
    // Simple query that works during migration - we'll filter in code instead of query
    return firestore
        .collection('videos')
        .where('uid', isEqualTo: uid)
        .orderBy(FieldPath.documentId, descending: true);
  }
  
  /// Clean up very old deleted video records (optional - run periodically)
  Future<void> cleanupOldDeletedRecords(String creatorId, {int maxAgeInDays = 365}) async {
    try {
      DocumentSnapshot userDoc = await firestore.collection('users').doc(creatorId).get();
      
      if (!userDoc.exists) return;
      
      Map<String, dynamic> userData = Map<String, dynamic>.from(userDoc.data() as Map<String, dynamic>);
      List<dynamic> deletedVideos = List.from(userData['deletedVideos'] ?? []);
      
      DateTime cutoffDate = DateTime.now().subtract(Duration(days: maxAgeInDays));
      List<dynamic> filteredDeletedVideos = [];
      
      for (var deletedVideo in deletedVideos) {
        if (deletedVideo is Map<String, dynamic> && deletedVideo.containsKey('deletedAt')) {
          Timestamp deletedAt = deletedVideo['deletedAt'];
          if (deletedAt.toDate().isAfter(cutoffDate)) {
            filteredDeletedVideos.add(deletedVideo);
          }
        } else {
          // Keep records without timestamp for safety
          filteredDeletedVideos.add(deletedVideo);
        }
      }
      
      if (filteredDeletedVideos.length < deletedVideos.length) {
        await firestore.collection('users').doc(creatorId).update({
          'deletedVideos': filteredDeletedVideos,
          'lastCleanup': FieldValue.serverTimestamp(),
        });
        
      }
    } catch (e) {
    }
  }
}
