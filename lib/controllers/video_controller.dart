import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../models/video.dart';
import '../services/user_cleanup_service.dart';
import '../services/historical_analytics_service.dart';

class VideoController extends GetxController {
  final Rx<List<Video>> _videoList = Rx<List<Video>>([]);
  final Rx<List<Video>> _myVideos = Rx<List<Video>>([]);
  
  // Track local like updates to prevent unnecessary feed refreshes
  final Map<String, Map<String, dynamic>> _localVideoUpdates = {};
  bool _isUpdatingLikes = false;
  bool _preventShuffle = false;
  List<String> _currentVideoOrder = [];
  
  // Track current page for TikTok-like behavior
  final RxInt _currentPageIndex = 0.obs;
  int get currentPageIndex => _currentPageIndex.value;
  RxInt get currentPageIndexRx => _currentPageIndex;

//getter fun
  List<Video> get videoList => _videoList.value;

  List<Video> get myVideos => _myVideos.value;

  @override
  void onInit() {
    super.onInit();
    
    // Run migration once on app start to ensure all videos have viewHistory field
    migrateVideoViewHistory();
    
    // Use fallback approach to handle videos that might not have isDeleted field yet
    _videoList.bindStream(
        _getActiveVideosStreamWithFallback().asyncMap((QuerySnapshot query) async {
      //map individual stream data for each video
      List<Video> returnedVideos = [];
      for (var element in query.docs) {
        final videoData = element.data() as Map<String, dynamic>;
        // Skip deleted videos (filter in code to handle missing isDeleted field)
        bool isDeleted = videoData['isDeleted'] ?? false;
        if (!isDeleted) {
          final video = Video.fromSnap(element);
          // Validate user exists before adding video
          final userExists = await UserCleanupService.validateUserAndCleanup(video.uid);
          if (userExists) {
            returnedVideos.add(video);
          } else {
          }
        } else {
        }
      }
      
  // Apply simple randomized feed logic
      returnedVideos = _applyRandomizedFeedLogic(returnedVideos);
      
      return returnedVideos;
    }));
  }
  
  /// Simple randomized feed logic suitable for final year project
  /// 1. Sort videos by timestamp (most recent first)
  /// 2. Apply shuffle for unpredictability
  /// 3. Skip shuffling for very small lists (< 5 videos)
  List<Video> _applyRandomizedFeedLogic(List<Video> videos) {
    if (videos.isEmpty) {
      return videos;
    }
    
    // Step 1: Sort videos by timestamp in descending order (most recent first)
    videos.sort((a, b) {
      // Use uploadTimestamp if available, otherwise fall back to document ID comparison
      if (a.uploadTimestamp != null && b.uploadTimestamp != null) {
        return b.uploadTimestamp!.compareTo(a.uploadTimestamp!);
      }
      // Fallback: compare document IDs (which are timestamp-based in Firestore)
      return b.id.compareTo(a.id);
    });
    
    
    // Step 2: Check if list is large enough for shuffling
    if (videos.length < 5) {
      return videos;
    }
    
    // Step 3: Apply shuffle to introduce randomness
    // Use current time as seed to ensure different order on each app launch/refresh
    videos.shuffle(Random(DateTime.now().millisecondsSinceEpoch));    
    return videos;
  }
  
  // Check if we should reshuffle based on video list changes
  bool _shouldReshuffle(List<Video> newVideos) {
    // If the number of videos changed significantly, reshuffle
    if ((_videoList.value.length - newVideos.length).abs() > 0) {
      return true;
    }
    
    // If we have completely different video IDs, reshuffle
    final currentIds = _videoList.value.map((v) => v.id).toSet();
    final newIds = newVideos.map((v) => v.id).toSet();
    final commonIds = currentIds.intersection(newIds);
    
    // If less than 80% of videos are the same, reshuffle
    if (currentIds.isNotEmpty && (commonIds.length / currentIds.length) < 0.8) {
      return true;
    }
    
    return false;
  }
  
  // Preserve the current video order while updating video data
  List<Video> _preserveVideoOrder(List<Video> newVideos) {
    final videoMap = {for (var video in newVideos) video.id: video};
    List<Video> orderedVideos = [];
    
    // First, add videos in the current order
    for (String videoId in _currentVideoOrder) {
      if (videoMap.containsKey(videoId)) {
        orderedVideos.add(videoMap[videoId]!);
        videoMap.remove(videoId); // Remove to avoid duplicates
      }
    }
    
    // Add any new videos that weren't in the original order
    orderedVideos.addAll(videoMap.values);
    
    // Update the current order to include any new videos
    _currentVideoOrder = orderedVideos.map((video) => video.id).toList();
    
    return orderedVideos;
  }
  
  // Regular refresh method for general use
  Future<void> refreshVideoFeed() async {
    try {
      
      // Get current active videos from Firestore (exclude deleted)
      QuerySnapshot query;
      try {
        query = await HistoricalAnalyticsService().getActiveVideosQuery().get();
      } catch (e) {
        query = await firestore.collection('videos').get();
      }
      
      List<Video> refreshedVideos = [];
      for (var element in query.docs) {
        final videoData = element.data() as Map<String, dynamic>;
        // Skip deleted videos (filter in code to handle missing isDeleted field)
        bool isDeleted = videoData['isDeleted'] ?? false;
        if (!isDeleted) {
          final video = Video.fromSnap(element);
          // Validate user exists before adding video
          final userExists = await UserCleanupService.validateUserSilently(video.uid);
          if (userExists) {
            refreshedVideos.add(video);
          }
        }
      }
      
      if (refreshedVideos.isNotEmpty) {
        // Apply the same randomized feed logic
        refreshedVideos = _applyRandomizedFeedLogic(refreshedVideos);
        
        // Force a real-time update by clearing first, then updating
        _videoList.value = [];
        await Future.delayed(const Duration(milliseconds: 50));
        _videoList.value = refreshedVideos;
        
      } else {
        _videoList.value = [];
      }
    } catch (e) {
    }
  }
  
  // Enhanced refresh method with synchronization for after upload
  Future<void> refreshVideoFeedWithSync() async {
    try {
      
      // Fetch active videos from Firestore ensuring fresh sync including newly uploaded one
      final QuerySnapshot query = await HistoricalAnalyticsService().getActiveVideosQuery().orderBy('uploadTimestamp', descending: true).get();
      
      List<Video> refreshedVideos = [];
      for (var element in query.docs) {
        final videoData = element.data() as Map<String, dynamic>;
        // Skip deleted videos (filter in code to handle missing isDeleted field)
        bool isDeleted = videoData['isDeleted'] ?? false;
        if (!isDeleted) {
          final video = Video.fromSnap(element);
          // Validate user exists before adding video
          final userExists = await UserCleanupService.validateUserSilently(video.uid);
          if (userExists) {
            refreshedVideos.add(video);
          }
        }
      }
      
      if (refreshedVideos.isNotEmpty) {
        // Apply the updated randomized feed logic
        refreshedVideos = _applyRandomizedFeedLogic(refreshedVideos);
        
        // Force a real-time update by clearing first, then updating
        _videoList.value = [];
        await Future.delayed(const Duration(milliseconds: 50));
        _videoList.value = refreshedVideos;
        
      } else {
        _videoList.value = [];
      }
    } catch (e) {
    }
  }
  
  // Pull-to-refresh method with explicit shuffling for fresh content discovery
  Future<void> pullToRefreshVideos() async {
    try {      
      // Fetch latest active videos from Firestore (exclude soft-deleted)
      final QuerySnapshot query = await HistoricalAnalyticsService().getActiveVideosQuery().get();
      
      List<Video> refreshedVideos = [];
      for (var element in query.docs) {
        final videoData = element.data() as Map<String, dynamic>;
        // Skip deleted videos (filter in code to handle missing isDeleted field)
        bool isDeleted = videoData['isDeleted'] ?? false;
        if (!isDeleted) {
          final video = Video.fromSnap(element);
          // Validate user exists before adding video
          final userExists = await UserCleanupService.validateUserSilently(video.uid);
          if (userExists) {
            refreshedVideos.add(video);
          }
        }
      }
      
      if (refreshedVideos.isNotEmpty) {
        // Sort by timestamp first (newest first)
        refreshedVideos.sort((a, b) {
          if (a.uploadTimestamp != null && b.uploadTimestamp != null) {
            return b.uploadTimestamp!.compareTo(a.uploadTimestamp!);
          }
          return b.id.compareTo(a.id);
        });
        
        // Apply explicit shuffle for fresh discovery experience
        refreshedVideos.shuffle(Random(DateTime.now().millisecondsSinceEpoch));
        
        // Update the feed with shuffled videos
        _videoList.value = refreshedVideos;
        
      } else {
        _videoList.value = [];
      }
    } catch (e) {
      throw e; // Re-throw to let RefreshIndicator handle the error
    }
  }
  
  // Load specific video by ID and show it in the feed without randomizing
  Future<void> loadSpecificVideo(String videoId) async {
    try {
      
      // Get current active videos from Firestore (exclude deleted)
      final QuerySnapshot query = await HistoricalAnalyticsService().getActiveVideosQuery().get();
      
      List<Video> allVideos = [];
      Video? targetVideo;
      
      for (var element in query.docs) {
        final videoData = element.data() as Map<String, dynamic>;
        // Skip deleted videos (filter in code to handle missing isDeleted field)
        bool isDeleted = videoData['isDeleted'] ?? false;
        if (!isDeleted) {
          final video = Video.fromSnap(element);
          // Validate user exists before adding video
          final userExists = await UserCleanupService.validateUserSilently(video.uid);
          if (userExists) {
            allVideos.add(video);
            if (video.id == videoId) {
              targetVideo = video;
            }
          }
        }
      }
      
      if (targetVideo != null) {
        // Put the target video first, then add other videos without shuffling
        // This maintains the original order while ensuring the specific video is shown first
        List<Video> orderedVideos = [targetVideo];
        orderedVideos.addAll(allVideos.where((v) => v.id != videoId));
        
        _videoList.value = orderedVideos;
      } else {
        _videoList.value = allVideos;
      }
    } catch (e) {
    }
  }

  void getMyVideos(String uid) async {
    //profile videos - maintain chronological order (newest first) - only show active videos
    // Use fallback for migration period
    Stream<QuerySnapshot> videoStream;
    try {
      videoStream = HistoricalAnalyticsService()
          .getUserActiveVideosQuery(uid)
          .snapshots();
    } catch (e) {
      videoStream = firestore
          .collection('videos')
          .where('uid', isEqualTo: uid)
          .orderBy(FieldPath.documentId, descending: true)
          .snapshots();
    }
    
    _myVideos.bindStream(videoStream
        .asyncMap((QuerySnapshot query) async {
      //map individual stream data for each video
      List<Video> returnedVideos = [];
      if (query.docs.isNotEmpty) {
        // Validate user exists before showing their videos
        final userExists = await UserCleanupService.validateUserAndCleanup(uid);
        if (userExists) {
          for (var element in query.docs) {
            final videoData = element.data() as Map<String, dynamic>;
            // Skip deleted videos (filter in code to handle missing isDeleted field)
            bool isDeleted = videoData['isDeleted'] ?? false;
            if (!isDeleted) {
              returnedVideos.add(Video.fromSnap(element));
            }
          }
          // DO NOT shuffle - maintain chronological order for profile thumbnails
        }
      }
      //otherwise returns empty list
      return returnedVideos;
    }));
  }

  // Optimistic like update - updates UI immediately, syncs with Firestore in background
  void likeVideo(String id, {bool forceLike = false}) async {
    try {
      String uid = authController.userData!.uid;
      
      // Find the video in current list and update it optimistically
      List<Video> currentVideos = List.from(_videoList.value);
      int videoIndex = currentVideos.indexWhere((video) => video.id == id);
      
      if (videoIndex != -1) {
        Video video = currentVideos[videoIndex];
        List<dynamic> updatedLikes = List.from(video.likes);
        
        bool isCurrentlyLiked = updatedLikes.contains(uid);
        bool shouldLike = forceLike ? true : !isCurrentlyLiked;
        
        // Update likes optimistically
        if (shouldLike) {
          if (!isCurrentlyLiked) {
            updatedLikes.add(uid);
          }
        } else {
          updatedLikes.remove(uid);
        }
        
        // Create updated video object
        Video updatedVideo = Video(
          username: video.username,
          uid: video.uid,
          id: video.id,
          likes: updatedLikes,
          commentCount: video.commentCount,
          shareCount: video.shareCount,
          viewCount: video.viewCount,
          viewHistory: video.viewHistory,
          caption: video.caption,
          videoUrl: video.videoUrl,
          profilePhoto: video.profilePhoto,
          thumbnail: video.thumbnail,
          uploadTimestamp: video.uploadTimestamp,
        );
        
        // Update the list with the new video object
        currentVideos[videoIndex] = updatedVideo;
        _videoList.value = currentVideos;
        
        // Update Firestore in background (don't await to keep UI responsive)
        _updateLikeInFirestore(id, uid, shouldLike);
      }
    } catch (e) {
      // If optimistic update fails, fall back to direct Firestore update
      _updateLikeInFirestore(id, authController.userData!.uid, null);
    }
  }
  
  // Background Firestore update for likes
  Future<void> _updateLikeInFirestore(String id, String uid, bool? shouldLike) async {
    try {
      if (shouldLike == null) {
        // Fallback case - check current state and toggle
        DocumentSnapshot snap = await firestore.collection('videos').doc(id).get();
        if (snap.exists) {
          List<dynamic> currentLikes = (snap.data()! as dynamic)['likes'] ?? [];
          shouldLike = !currentLikes.contains(uid);
        } else {
          return;
        }
      }
      
      if (shouldLike) {
        await firestore.collection('videos').doc(id).update({
          'likes': FieldValue.arrayUnion([uid])
        });
      } else {
        await firestore.collection('videos').doc(id).update({
          'likes': FieldValue.arrayRemove([uid])
        });
      }
      
    } catch (e) {
      // In case of error, we could implement retry logic or revert optimistic update
    }
  }

  void updateShareCount(String id) async {
    DocumentSnapshot doc = await firestore.collection('videos').doc(id).get();
    await firestore.collection('videos').doc(id).update({
      'shareCount': (doc.data()! as dynamic)['shareCount'] + 1,
    });
  }

  /// Legacy method - now redirects to the new intelligent view tracking system
  /// This maintains backward compatibility while using the new service
  void updateViewCount(String id) {
    // Note: This method is now deprecated in favor of the intelligent
    // VideoViewService which tracks actual watch time and engagement.
    // For backward compatibility, we'll start a watch session here,
    // but proper integration should use startWatching/stopWatching directly.    
    // This is kept for backward compatibility but won't do anything
    // The new system requires explicit start/stop watching calls
  }

  // Migration helper for existing videos without viewHistory and isDeleted fields
  Future<void> migrateVideoViewHistory() async {
    try {
      final QuerySnapshot query = await firestore.collection('videos').get();
      
      for (var doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> updates = {};
        
        // Check if viewHistory field exists
        if (!data.containsKey('viewHistory')) {
          updates['viewHistory'] = <String, dynamic>{}; // Empty map for new videos
        }
        
        // Check if isDeleted field exists (for soft delete functionality)
        if (!data.containsKey('isDeleted')) {
          updates['isDeleted'] = false; // All existing videos are not deleted
        }
        
        // Only update if we have fields to add
        if (updates.isNotEmpty) {
          await firestore.collection('videos').doc(doc.id).update(updates);
        }
      }
      
    } catch (e) {
    }
  }

  // Get active videos stream with fallback for migration period
  Stream<QuerySnapshot> _getActiveVideosStreamWithFallback() {
    try {
      return HistoricalAnalyticsService().getActiveVideosQuery().snapshots();
    } catch (e) {
      // Fallback: get all videos (during migration period before isDeleted field exists)
      return firestore.collection('videos').snapshots();
    }
  }
  
  // Handle page changes for TikTok-like behavior
  void onPageChanged(int index) {
    _currentPageIndex.value = index;
  }
  
  // Delete Post with comprehensive analytics and earnings preservation
  Future<String> deletePostWithConfirmation(String id) async {
    String res = "Some error occurred";
    try {
      // Get video details first to check ownership and analytics
      DocumentSnapshot videoDoc = await firestore.collection('videos').doc(id).get();
      if (!videoDoc.exists) {
        return 'Video not found';
      }
      
      Map<String, dynamic> videoData = videoDoc.data() as Map<String, dynamic>;
      String creatorId = videoData['uid'] ?? '';
      int viewCount = videoData['viewCount'] ?? 0;
      String currentUserId = authController.userData?.uid ?? '';
      
      // Verify ownership
      if (creatorId != currentUserId) {
        return 'Unauthorized: You can only delete your own videos';
      }
      
      // Check for unpaid earnings
      bool hasUnpaidEarnings = await _checkForUnpaidEarnings(creatorId, viewCount);
      
      // Show confirmation dialog
      bool? confirmed = await _showDeleteConfirmationDialog(viewCount, hasUnpaidEarnings);
      if (confirmed != true) {
        return 'Deletion cancelled by user';
      }
      
      // Use the new HistoricalAnalyticsService for soft delete with complete preservation
      res = await HistoricalAnalyticsService().softDeleteVideo(id, creatorId);
      
    } catch (err) {
      res = err.toString();
    }
    return res;
  }
  
  // Legacy method for backward compatibility - now redirects to new method
  Future<String> deletePost(String id) async {
    return await deletePostWithConfirmation(id);
  }
  
  // Helper method to check for unpaid earnings
  Future<bool> _checkForUnpaidEarnings(String creatorId, int videoViewCount) async {
    try {
      // Get creator's earnings data
      DocumentSnapshot userDoc = await firestore.collection('users').doc(creatorId).get();
      if (!userDoc.exists) {
        return false; // No earnings data means no unpaid earnings
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      int totalEarningViews = userData['totalEarningViews'] ?? 0;
      int totalPaidViews = userData['totalPaidViews'] ?? 0;
      
      // Calculate unpaid views
      int unpaidViews = totalEarningViews - totalPaidViews;
      
      // If there are unpaid views and this video has views, there might be unpaid earnings
      return unpaidViews > 0 && videoViewCount > 0;
    } catch (e) {
      return false; // If we can't check, don't block deletion
    }
  }
  
  // Preserve historical analytics and earnings data before video deletion
  Future<void> _preserveHistoricalData(String creatorId, String videoId, Map<String, dynamic> videoData) async {
    try {
      
      int viewCount = videoData['viewCount'] ?? 0;
      int likes = (videoData['likes'] as List?)?.length ?? 0;
      int commentCount = videoData['commentCount'] ?? 0;
      int shareCount = videoData['shareCount'] ?? 0;
      Timestamp? uploadTimestamp = videoData['uploadTimestamp'];
      
      if (viewCount > 0) {
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
          
          // Current analytics totals
          int currentHistoricalViews = historicalAnalytics['totalViews'] ?? 0;
          int currentHistoricalLikes = historicalAnalytics['totalLikes'] ?? 0;
          int currentHistoricalComments = historicalAnalytics['totalComments'] ?? 0;
          int currentHistoricalShares = historicalAnalytics['totalShares'] ?? 0;
          int currentHistoricalVideos = historicalAnalytics['totalVideosCreated'] ?? 0;
          
          // Add deleted video data to historical record
          deletedVideos.add({
            'videoId': videoId,
            'viewCount': viewCount,
            'likes': likes,
            'commentCount': commentCount,
            'shareCount': shareCount,
            'deletedAt': FieldValue.serverTimestamp(),
            'uploadTimestamp': uploadTimestamp,
          });
          
          // Update historical analytics totals
          Map<String, dynamic> updatedHistoricalAnalytics = {
            'totalViews': currentHistoricalViews + viewCount,
            'totalLikes': currentHistoricalLikes + likes,
            'totalComments': currentHistoricalComments + commentCount,
            'totalShares': currentHistoricalShares + shareCount,
            'totalVideosCreated': currentHistoricalVideos + 1,
            'lastUpdated': FieldValue.serverTimestamp(),
          };
          
          // Preserve earnings data independently
          // Note: We don't modify totalEarningViews, totalEarnings, unpaidEarnings, or totalPaidViews
          // These remain unchanged so unpaid earnings persist until withdrawn
          
          Map<String, dynamic> updateData = {
            'historicalAnalytics': updatedHistoricalAnalytics,
            'deletedVideos': deletedVideos,
            'analyticsLastUpdated': FieldValue.serverTimestamp(),
          };
          
          if (userSnapshot.exists) {
            transaction.update(userRef, updateData);
          } else {
            transaction.set(userRef, updateData, SetOptions(merge: true));
          }
          
        });
      }
    } catch (e) {
      // Don't fail the deletion if we can't preserve data
    }
  }
  
  // Show confirmation dialog before deleting video
  Future<bool?> _showDeleteConfirmationDialog(int viewCount, bool hasUnpaidEarnings) async {
    return await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Text(
              'Delete Video?',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this video?',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              
              // Analytics preservation info
              Container(
                width: double.infinity, // Ensure full width
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Analytics & Earnings Protected',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Video stats ($viewCount views) will be preserved in your lifetime analytics',
                      style: TextStyle(color: Colors.green[300], fontSize: 14),
                    ),
                    if (hasUnpaidEarnings) ...[
                      Text(
                        '• Your unpaid earnings from this video will remain available for withdrawal',
                        style: TextStyle(color: Colors.green[300], fontSize: 14),
                      ),
                    ],
                    Text(
                      '• Only public visibility will be removed',
                      style: TextStyle(color: Colors.green[300], fontSize: 14),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              Container(
                width: double.infinity, // Make same width as analytics container
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Video Performance:',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• $viewCount views earned ₦${(viewCount * 1.0).toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.blue[300], fontSize: 14),
                    ),
                    Text(
                      '• Performance data will be preserved',
                      style: TextStyle(color: Colors.blue[300], fontSize: 14),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              Text(
                'This action will remove the video from public view but preserve all your analytics and earnings data.',
                style: TextStyle(color: Colors.white60, fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Delete Video',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
  
  // Force delete post (after user confirms they understand the earnings loss)
  Future<String> forceDeletePost(String id) async {
    String res = "Some error occurred";
    try {
      await firestore.collection('videos').doc(id).delete();
      res = 'success';
    } catch (err) {
      res = err.toString();
    }
    return res;
  }
}
