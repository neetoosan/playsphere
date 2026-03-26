import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../services/user_cleanup_service.dart';
import '../services/historical_analytics_service.dart';

class ProfileController extends GetxController {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Map<String, dynamic> user = {};
  String _uid = '';
  bool isLoading = false;
  bool hasError = false;
  String errorMessage = '';

  void updateUserId(String uid) {
    _uid = uid;
    getUserData();
    _setupVideoDeletionListener(); // Set up listener for deletions
  }

  // Listen to deletions of videos and refresh the profile
  void _setupVideoDeletionListener() {
    if (_uid.isNotEmpty) {
      firestore
          .collection('videos')
          .where('uid', isEqualTo: _uid)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.removed) {
            // A video was deleted for this user, refresh profile videos
            getUserData();
            break; // Only need to refresh once per snapshot
          }
        }
      });
    }
  }

  // Refresh profile data to get the latest information
  Future<void> refreshProfile() async {
    if (_uid.isNotEmpty) {
      await getUserData();
      // Force UI update
      update();
    }
  }
  
  // Force update the profile photo specifically
  void updateProfilePhoto(String newPhotoUrl) {
    if (user.isNotEmpty) {
      user['profilePhoto'] = newPhotoUrl;
      update(); // Trigger UI rebuild
    }
  }

  Future<void> getUserData() async {
    if (_uid.isEmpty) {
      user = {};
      isLoading = false;
      hasError = true;
      errorMessage = 'Invalid user ID';
      // Defer update to avoid setState during build
      Future.microtask(() => update());
      return;
    }

    isLoading = true;
    hasError = false;
    errorMessage = '';
    // Defer update to avoid setState during build
    Future.microtask(() => update());

    List<String> thumbnails = [];
    List<String> videoUrls = [];
    List<String> videoIds = [];

    try {
      // Get user document first
      DocumentSnapshot userDoc =
          await firestore.collection('users').doc(_uid).get();

      if (!userDoc.exists || userDoc.data() == null) {
        
        // Try to create the user document if it's the current user
        if (_uid == firebaseAuth.currentUser?.uid) {
          await authController.createUserDocumentIfNotExists();
          
          // Try to fetch the document again
          userDoc = await firestore.collection('users').doc(_uid).get();
          
          if (!userDoc.exists || userDoc.data() == null) {
            user = {};
            isLoading = false;
            hasError = true;
            errorMessage = 'Unable to load user profile';
            Future.microtask(() => update());
            return;
          }
        } else {
          // User doesn't exist, clean up their content silently
          // The Cloud Function should handle this, but this is a backup
          UserCleanupService.cleanupUserVideos(_uid).catchError((e) {
          });
          
          user = {};
          isLoading = false;
          hasError = true;
          errorMessage = 'This user account is no longer available';
          Future.microtask(() => update());
          return;
        }
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      thumbnails = List<String>.from(userData['thumbnails'] ?? []);
      videoUrls = List<String>.from(userData['videoUrls'] ?? []);

      // Get user videos (only active/non-deleted videos for profile display)
      // Use a fallback approach for videos that might not have isDeleted field yet
      QuerySnapshot myVideos;
      try {
        myVideos = await HistoricalAnalyticsService()
            .getUserActiveVideosQuery(_uid)
            .get();
      } catch (e) {
        // Fallback: if the query fails (likely due to missing isDeleted field), 
        // get all videos for this user
        myVideos = await firestore
            .collection('videos')
            .where('uid', isEqualTo: _uid)
            .orderBy(FieldPath.documentId, descending: true)
            .get();
      }

      // Create lists of video data with corresponding indices for chronological sorting
      // Only include non-deleted videos for profile thumbnail display
      List<Map<String, dynamic>> videoData = [];
      for (var doc in myVideos.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Skip deleted videos (filter in code to handle missing isDeleted field)
        bool isDeleted = data['isDeleted'] ?? false;
        if (!isDeleted && data['thumbnail'] != null && data['videoUrl'] != null) {
          videoData.add({
            'thumbnail': data['thumbnail'],
            'videoUrl': data['videoUrl'],
            'id': doc.id,
            'uploadTimestamp': data['uploadTimestamp'] ?? Timestamp.fromMillisecondsSinceEpoch(0),
          });
        }
      }
      
      // Order videos by upload timestamp chronologically, latest first, handling null values
      videoData.sort((a, b) {
        // Handle Firestore Timestamp objects and null values
        DateTime aDateTime;
        DateTime bDateTime;
        
        if (a['uploadTimestamp'] == null) {
          aDateTime = DateTime.fromMillisecondsSinceEpoch(0);
        } else if (a['uploadTimestamp'] is Timestamp) {
          aDateTime = (a['uploadTimestamp'] as Timestamp).toDate();
        } else {
          aDateTime = a['uploadTimestamp'] as DateTime;
        }
        
        if (b['uploadTimestamp'] == null) {
          bDateTime = DateTime.fromMillisecondsSinceEpoch(0);
        } else if (b['uploadTimestamp'] is Timestamp) {
          bDateTime = (b['uploadTimestamp'] as Timestamp).toDate();
        } else {
          bDateTime = b['uploadTimestamp'] as DateTime;
        }
        
        return bDateTime.compareTo(aDateTime);
      });
      
      // Extract the ordered data into separate lists
      for (var data in videoData) {
        thumbnails.add(data['thumbnail']);
        videoUrls.add(data['videoUrl']);
        videoIds.add(data['id']);
      }

      String name = userData['name'];
      String profilePhoto = userData['profilePhoto'];
      String email = userData['email'];

      // Get lifetime analytics including deleted videos
      Map<String, dynamic> lifetimeAnalytics = await HistoricalAnalyticsService()
          .getLifetimeAnalytics(_uid);
      
      // Current active video likes
      int activeLikes = 0;
      for (var item in myVideos.docs) {
        final itemData = item.data() as Map<String, dynamic>;
        activeLikes += (itemData['likes'] as List?)?.length ?? 0;
      }
      
      // Use lifetime analytics for total stats display
      int totalLifetimeViews = lifetimeAnalytics['lifetime']?['views'] ?? 0;
      int totalLifetimeLikes = lifetimeAnalytics['lifetime']?['likes'] ?? activeLikes;
      int totalLifetimeVideos = lifetimeAnalytics['lifetime']?['videos'] ?? myVideos.docs.length;

      // Get followers and following counts
      var followerDoc = await firestore
          .collection('users')
          .doc(_uid)
          .collection('followers')
          .get();

      var followingDoc = await firestore
          .collection('users')
          .doc(_uid)
          .collection('following')
          .get();

      int followers = followerDoc.docs.length;
      int following = followingDoc.docs.length;

      // Check if current user follows this user
      final currentUserId = authController.userData?.uid;
      bool isFollowing = false;

      if (currentUserId != null && currentUserId.isNotEmpty) {
        var isFollowingDoc = await firestore
            .collection('users')
            .doc(_uid)
            .collection('followers')
            .doc(currentUserId)
            .get();

        isFollowing = isFollowingDoc.exists;
      }

      user = {
        'followers': followers.toString(),
        'following': following.toString(),
        'isFollowing': isFollowing,
        'likes': totalLifetimeLikes.toString(), // Show lifetime likes including deleted videos
        'totalViews': totalLifetimeViews.toString(), // Add total lifetime views
        'totalVideos': totalLifetimeVideos.toString(), // Add total lifetime videos created
        'profilePhoto': profilePhoto,
        'name': name,
        'email': email,
        'thumbnails': thumbnails,
        'videoUrls': videoUrls,
        'videoIds': videoIds,
        // Add earnings data for creator profiles
        'earnings': lifetimeAnalytics['earnings'],
        'lifetimeAnalytics': lifetimeAnalytics,
      };
      isLoading = false;
      hasError = false;
      Future.microtask(() => update());
    } catch (e) {
      user = {};
      isLoading = false;
      hasError = true;
      errorMessage = 'Failed to load profile: ${e.toString()}';
      Future.microtask(() => update());
    }
  }

  Future<void> followUser() async {
    final currentUserId = authController.userData?.uid;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      var doc = await firestore
          .collection('users')
          .doc(_uid)
          .collection('followers')
          .doc(currentUserId)
          .get();

      if (!doc.exists) {
        await firestore
            .collection('users')
            .doc(_uid)
            .collection('followers')
            .doc(currentUserId)
            .set({});
        await firestore
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(_uid)
            .set({});
        user.update(
          'followers',
          (value) => (int.parse(value) + 1).toString(),
        );
        user['isFollowing'] = true;
      } else {
        await firestore
            .collection('users')
            .doc(_uid)
            .collection('followers')
            .doc(currentUserId)
            .delete();
        await firestore
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(_uid)
            .delete();
        user.update(
          'followers',
          (value) => (int.parse(value) - 1).toString(),
        );
        user['isFollowing'] = false;
      }

      update();
    } catch (e) {
    }
  }
}
