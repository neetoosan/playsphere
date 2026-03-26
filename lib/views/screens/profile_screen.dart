import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/instance_manager.dart';
import 'package:play_sphere/constants.dart';
import 'package:play_sphere/views/screens/auth/login_screen.dart';
import 'package:play_sphere/views/screens/edit_profile_screen.dart';
import 'package:play_sphere/views/screens/home_screen.dart';
import 'package:play_sphere/views/screens/message_screen.dart';
import 'package:play_sphere/views/screens/play_video.dart';
import 'package:play_sphere/views/screens/single_video_screen.dart';
import 'package:play_sphere/views/screens/withdrawal_setup_screen.dart';
import '../widgets/subscription_badge.dart';
import '../../controllers/msg_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/video_controller.dart';
import '../../services/earnings_service.dart';
import '../../services/historical_analytics_service.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;
  final bool fromSearch;
  const ProfileScreen({
    Key? key,
    required this.uid,
    this.fromSearch = false,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileController profileController = Get.put(ProfileController());
  final VideoController videoController = Get.put(VideoController());

  final MessageController msgController = Get.put(MessageController());
  bool _isNavigatingToWithdrawal = false;
  bool _isLoadingProfile = false;
  bool _isDeletingVideo = false;
  String _deletingVideoId = '';

  @override
  void initState() {
    super.initState();
    profileController.updateUserId(widget.uid);
    videoController.getMyVideos(widget.uid);
  }
  //msg is clicked{
  // msg_controller.updateReceiverUid(widget.uid);
  //}

  void playVideo(int index) async {
    // Get the video ID from the myVideos list at the given index
    if (index < videoController.myVideos.length) {
      String videoId = videoController.myVideos[index].id;
      
      // Navigate to SingleVideoScreen with the specific video ID
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SingleVideoScreen(videoId: videoId),
        ),
      );
    } else {
    }
  }

  // Helper method to fetch video view count from Firestore
  Future<int> _getVideoViewCount(String videoId) async {
    try {
      final doc = await firestore.collection('videos').doc(videoId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['viewCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Helper method to format view count for display
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

  // Helper method to calculate total views including historical data from deleted videos
  Future<int> _calculateTotalViews() async {
    try {
      final userId = authController.userData?.uid;
      if (userId == null) return 0;
      
      // Use HistoricalAnalyticsService to get accurate lifetime analytics
      final lifetimeAnalytics = await HistoricalAnalyticsService().getLifetimeAnalytics(userId);
      final totalViews = lifetimeAnalytics['lifetime']?['views'] ?? 0;
      
      return totalViews;
    } catch (e) {
      return 0;
    }
  }

  // Helper method to calculate unpaid views for earnings using real-time video data
  Future<int> _calculateUnpaidViews() async {
    try {
      final userId = authController.userData?.uid;
      if (userId == null) return 0;

      // First, ensure earnings are synchronized with actual video views
      await _syncEarningsWithVideoViews();
      
      // Get current total views from videos (same as displayed in Total Views)
      int actualTotalViews = await _calculateTotalViews();
      
      // Get earnings summary to get paid views count (refreshed after sync)
      final earningsSummary = await EarningsService().getCreatorEarningsSummary(userId);
      int totalPaidViews = earningsSummary['totalPaidViews'] ?? 0;
      
      // Calculate unpaid views using actual video view counts
      // This ensures withdrawal progress reflects the same views as Content Analytics
      int unpaidViews = actualTotalViews - totalPaidViews;
            
      // Ensure unpaid views never go below 0
      return unpaidViews < 0 ? 0 : unpaidViews;
    } catch (e) {
      return 0;
    }
  }
  
  // Helper method to ensure earnings are synchronized with actual video views
  Future<void> _syncEarningsWithVideoViews() async {
    try {
      final userId = authController.userData?.uid;
      if (userId == null) return;
      
      // Get actual total views from videos
      int actualTotalViews = await _calculateTotalViews();
      
      // Get current earnings data
      final earningsSummary = await EarningsService().getCreatorEarningsSummary(userId);
      int currentEarningViews = earningsSummary['totalEarningViews'] ?? 0;
      
      // If actual views are higher than earning views, sync them up
      if (actualTotalViews > currentEarningViews) {        
        // Update user document with correct earning views
        await firestore.collection('users').doc(userId).update({
          'totalEarningViews': actualTotalViews,
          'totalLifetimeViews': actualTotalViews,
          'totalEarnings': actualTotalViews * 1.0, // ₦1 per view
          'unpaidEarnings': (actualTotalViews - (earningsSummary['totalPaidViews'] ?? 0)) * 1.0,
          'lastEarningsUpdate': FieldValue.serverTimestamp(),
        });
        
      }
    } catch (e) {
    }
  }

  // Helper method to calculate estimated earnings
  double _calculateEarnings(int totalViews) {
    // Assuming ₦1 per view (Nigerian Naira rate)
    return totalViews * 1.0;
  }

  // Helper method to format currency
  String _formatCurrency(double amount) {
    return '₦${amount.toStringAsFixed(2)}';
  }

  // Helper method to get withdrawal progress
  double _getWithdrawalProgress(int totalViews) {
    const int withdrawalThreshold = 1000;
    return (totalViews / withdrawalThreshold).clamp(0.0, 1.0);
  }

  // Helper method to fetch subscription details from database
  Future<Map<String, dynamic>?> _getSubscriptionDetails() async {
    try {
      final userId = authController.userData?.uid;
      if (userId == null) return null;

      final subscriptionDoc = await firestore
          .collection('subscriptions')
          .doc(userId)
          .get();

      if (subscriptionDoc.exists) {
        final data = subscriptionDoc.data()!;
        
        // Handle null safety for expiryDate
        final expiryDateData = data['expiryDate'];
        if (expiryDateData == null) {
          return null;
        }
        
        final expiryDate = (expiryDateData as Timestamp).toDate();
        final isActive = data['isActive'] as bool? ?? false;
        
        // Check if subscription is still active
        if (isActive && expiryDate.isAfter(DateTime.now())) {
          return {
            'planType': data['planType'] as String? ?? 'Unknown',
            'expiryDate': expiryDate,
            'isActive': true,
          };
        } else {
          return {
            'planType': 'Expired',
            'expiryDate': expiryDate,
            'isActive': false,
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Helper method to format date for display
  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _navigateToWithdrawal() async {
    // Show full-screen loading overlay with "Checking eligibility..." message
    setState(() {
      _isNavigatingToWithdrawal = true;
    });
    
    try {
      // Refresh profile data and calculate total views
      await profileController.refreshProfile();
      int totalViews = await _calculateTotalViews();

      if (!context.mounted) return;
      
      // Hide loading overlay before navigation
      setState(() {
        _isNavigatingToWithdrawal = false;
      });
      
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => WithdrawalSetupScreen(
            totalViews: totalViews,
          ),
        ),
      );

      // If coming back from withdrawal, show loading profile overlay
      if (result != null) {
        setState(() {
          _isLoadingProfile = true;
        });

        await profileController.refreshProfile();
        
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() {
        _isNavigatingToWithdrawal = false;
        _isLoadingProfile = false;
      });
    }
  }

  // Handle video deletion with earnings protection and immediate loading feedback
  Future<void> _handleVideoDelete(String videoId, int videoViewCount) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Start loading state immediately when deletion begins
      setState(() {
        _isDeletingVideo = true;
        _deletingVideoId = videoId;
      });
      
      String result = await videoController.deletePost(videoId);
      
      if (result == 'success') {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Video deleted successfully - analytics and earnings preserved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Refresh the videos list
        videoController.getMyVideos(widget.uid);
        
        // Also refresh profile controller to update analytics immediately
        await profileController.refreshProfile();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete video: $result'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting video: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      // Always stop loading state
      if (mounted) {
        setState(() {
          _isDeletingVideo = false;
          _deletingVideoId = '';
        });
      }
    }
  }

  Widget _buildLoadingOverlay(String message) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    void onSignout() async {
      authController.signOut();
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => LoginScreen()));
    }

    void onEditProfile() async {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => EditProfileScreen()));
    }

    return GetBuilder<ProfileController>(
        init: profileController,
        builder: (controller) {
          // Show full-screen loading overlays
          if (_isNavigatingToWithdrawal) {
            return Scaffold(
              body: _buildLoadingOverlay('Checking eligibility…'),
            );
          }
          
          if (_isLoadingProfile) {
            return Scaffold(
              body: _buildLoadingOverlay('Loading profile…'),
            );
          }
          
          // Show full black loading screen
          if (controller.isLoading || (controller.user.isEmpty && !controller.hasError)) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: _buildLoadingOverlay('Loading profile...'),
            );
          }
          
          // Show error state
          if (controller.hasError && controller.user.isEmpty) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.black12,
                leading: IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back_ios)),
                title: const Text('Profile'),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      controller.errorMessage.isNotEmpty 
                          ? controller.errorMessage 
                          : 'Failed to load profile',
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Retry loading profile
                        profileController.updateUserId(widget.uid);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: secondaryColor,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Scaffold(
            drawer: widget.uid == authController.userData.uid 
                ? _buildProfileDrawer(context, controller, onSignout) 
                : null,
            appBar: AppBar(
              backgroundColor: backgroundColor,
              elevation: 0,
              leading: widget.uid == authController.userData.uid
                  ? Builder(
                      builder: (context) => IconButton(
                        onPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                        icon: const Icon(
                          Icons.menu,
                          color: Color(0xFFF5F5F5), // Brighter white for better contrast
                          size: 24, // Increased size for better visibility
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: () {
                        if (widget.fromSearch) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const HomeScreen())
                          );
                        }
                      },
                      icon: const Icon(Icons.arrow_back_ios),
                    ),
              actions: widget.uid == authController.userData.uid 
                  ? [
                      IconButton(
                        onPressed: () async {
                          // Show confirmation dialog
                          bool? shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: const Color(0xFF2A2A2A),
                                title: const Text(
                                  'Logout Confirmation',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: const Text(
                                  'Are you sure you want to logout?',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4A5568),
                                      foregroundColor: secondaryColor,
                                    ),
                                    child: const Text('Yes'),
                                  ),
                                ],
                              );
                            },
                          );
                          
                          if (shouldLogout == true) {
                            onSignout();
                          }
                        },
                        icon: const Icon(
                          Icons.logout,
                          color: Color(0xFFF5F5F5), // Brighter white for better contrast
                          size: 24, // Increased size for better visibility
                        ),
                      ),
                    ]
                  : null,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      controller.user['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ConditionalSubscriptionBadge(
                    userId: widget.uid,
                    size: 18.0,
                    margin: const EdgeInsets.only(left: 6.0),
                  ),
                ],
              ),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipOval(
                                child: CachedNetworkImage(
                                  fit: BoxFit.cover,
                                  imageUrl: controller.user['profilePhoto'],
                                  height: 100,
                                  width: 100,
                                  placeholder: (context, url) =>
                                      const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                    Icons.error,
                                  ),
                                  // Add cache key to force refresh when needed
                                  cacheKey: '${controller.user['profilePhoto']}_profile',
                                ),
                              )
                            ],
                          ),
                          const SizedBox(
                            height: 15,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    controller.user['following'],
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Following',
                                    style: TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                color: Colors.black54,
                                width: 1,
                                height: 15,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    controller.user['followers'],
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Followers',
                                    style: TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                color: Colors.black54,
                                width: 1,
                                height: 15,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    controller.user['likes'],
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Likes',
                                    style: TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 15,
                          ),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Center(
                                  child: InkWell(
                                    onTap: () {
                                      if (widget.uid ==
                                          authController.userData.uid) {
                                        //edit profile function
                                        onEditProfile();
                                      } else {
                                        controller.followUser();
                                      }
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      width: size.width / 3,
                                      height: 34,
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: secondaryColor,
                                            width: 2,
                                          )),
                                      child: Text(
                                        widget.uid ==
                                                authController.userData.uid
                                            ? 'Edit Profile'
                                            : controller.user['isFollowing']
                                                ? 'Unfollow'
                                                : 'Follow',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                //msg user btn
                                widget.uid == authController.userData.uid
                                    ? Container()
                                    : Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: secondaryColor,
                                            width: 2,
                                          ),
                                          color: Colors.black12,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0, vertical: 2),
                                          child: InkWell(
                                              onTap: () async {
                                                Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            MessageScreen(
                                                                recieverUserId:
                                                                    widget.uid,
                                                                name: controller
                                                                        .user[
                                                                    'name'])));
                                              },
                                              child:
                                                  const Icon(Icons.mail)),
                                        ))
                              ]),
                          const SizedBox(
                            height: 15,
                          ),
                          const Divider(thickness: 3),
                          controller.user['thumbnails'].length == 0
                              ? Column(children: const [
                                  SizedBox(height: 190),
                                  Text("No videos to show",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 18,
                                      ))
                                ])
                              :
                              // video list
                              GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount:
                                      controller.user['thumbnails'].length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.7,
                                    crossAxisSpacing: 2,
                                    mainAxisSpacing: 2,
                                  ),
                                  itemBuilder: (context, index) {
                                    String thumbnail =
                                        controller.user['thumbnails'][index];
                                    String videoId =
                                        controller.user['videoIds'][index];
                                    return Stack(
                                      children: [
                                        InkWell(
                                          onTap: () => playVideo(index),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: CachedNetworkImage(
                                                imageUrl: thumbnail,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                            ),
                                          ),
                                        ),
                                        
                                        // Loading overlay during deletion
                                        if (_isDeletingVideo && _deletingVideoId == videoId)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.7),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    CircularProgressIndicator(
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                      strokeWidth: 2,
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'Deleting...',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        // View count overlay
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          child: FutureBuilder<int>(
                                            future: _getVideoViewCount(videoId),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.7),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.visibility,
                                                        color: Colors.white,
                                                        size: 12,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        _formatViewCount(snapshot.data!),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                        ),
                                        // Show delete menu only for the current user's profile
                                        if (widget.uid == authController.userData.uid)
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.8),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: PopupMenuButton<String>(
                                                padding: EdgeInsets.zero,
                                                iconSize: 16,
                                                icon: const Icon(
                                                  Icons.more_vert,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                onSelected: (value) async {
                                                  if (value == 'delete') {
                                                    // Get the view count asynchronously before calling delete
                                                    final viewCount = await _getVideoViewCount(videoId);
                                                    await _handleVideoDelete(videoId, viewCount);
                                                  }
                                                },
                                                itemBuilder: (BuildContext context) => [
                                                  const PopupMenuItem<String>(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.delete, color: Colors.red),
                                                        SizedBox(width: 8),
                                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  Widget _buildProfileDrawer(BuildContext context, ProfileController controller, VoidCallback onSignout) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8, // Standard drawer width (80%)
      height: MediaQuery.of(context).size.height, // Full screen height
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Distinct darker background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16.0,
            spreadRadius: 0.0,
            offset: const Offset(2.0, 0.0),
          ),
        ],
      ),
      child: Column(
        children: [
            // Header Section - Dynamic height
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    secondaryColor.withOpacity(0.8),
                    secondaryColor.withOpacity(0.6),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with title and close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Creator Studio',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.black,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Profile row with picture and username on same row
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 32,
                              width: 32,
                              child: Image.network(
                                controller.user['profilePhoto'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.person, 
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    controller.user['name'] ?? 'Creator',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ConditionalSubscriptionBadge(
                                  userId: widget.uid,
                                  size: 14.0,
                                  margin: const EdgeInsets.only(left: 4.0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Expandable Content Section with SingleChildScrollView
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Earnings & Monetization Section
                      FutureBuilder<List<dynamic>>(
                        future: Future.wait([
                          _getSubscriptionDetails(),
                          _calculateUnpaidViews(),
                        ]),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: secondaryColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          }
                          
                          final subscriptionData = snapshot.data![0] as Map<String, dynamic>?;
                          final unpaidViewsFromFuture = snapshot.data![1] as int;
                          
                          bool isSubscribed = subscriptionData?['isActive'] ?? false;
                          String planType = subscriptionData?['planType'] ?? 'Free Trial';
                          
                          // Check if user is on Free Trial (not subscribed to a paid plan)
                          bool isFreeTrialUser = !isSubscribed || planType.toLowerCase().contains('free') || planType.toLowerCase().contains('trial');
                          
                          int unpaidViews = isSubscribed && !isFreeTrialUser ? unpaidViewsFromFuture : 0;
                          double earnings = isSubscribed && !isFreeTrialUser ? _calculateEarnings(unpaidViews) : 0.0;
                          double progress = isSubscribed && !isFreeTrialUser ? _getWithdrawalProgress(unpaidViews) : 0.0;
                          
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A), // Slightly lighter than main background
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: secondaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.monetization_on,
                                      color: secondaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Earnings & Monetization',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Estimated Earnings',
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      (!isSubscribed || isFreeTrialUser) ? '₦0.00' : _formatCurrency(earnings),
                                      style: TextStyle(
                                        color: (!isSubscribed || isFreeTrialUser) ? Colors.grey.withOpacity(0.6) : secondaryColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        decoration: (!isSubscribed || isFreeTrialUser) ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Only make arrow interactive for active paid subscribers
                                    (isSubscribed && !isFreeTrialUser) ? GestureDetector(
                                      onTap: _navigateToWithdrawal,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: secondaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          Icons.north_east,
                                          color: secondaryColor,
                                          size: 16,
                                        ),
                                      ),
                                    ) : Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.north_east,
                                        color: Colors.grey.withOpacity(0.5),
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Withdrawal Progress',
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                LinearProgressIndicator(
                                  value: (!isSubscribed || isFreeTrialUser) ? 0.0 : progress,
                                  backgroundColor: (!isSubscribed || isFreeTrialUser) ? Colors.grey[700] : Colors.grey[600],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    (!isSubscribed || isFreeTrialUser) ? Colors.grey.withOpacity(0.3) : secondaryColor
                                  ),
                                  minHeight: 5,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  (isSubscribed && !isFreeTrialUser)
                                      ? '${unpaidViews}/1,000 views needed to withdraw'
                                      : isFreeTrialUser
                                          ? 'Upgrade from Free Trial to enable monetization'
                                          : 'Subscribe to enable monetization',
                                  style: TextStyle(
                                    color: (isSubscribed && !isFreeTrialUser) ? Colors.grey[300] : Colors.orange,
                                    fontSize: 11,
                                    fontWeight: (isSubscribed && !isFreeTrialUser) ? FontWeight.normal : FontWeight.w500,
                                  ),
                                ),
                                if (!isSubscribed || isFreeTrialUser) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.orange,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            isFreeTrialUser 
                                                ? 'Upgrade from Free Trial to start earning'
                                                : 'Upgrade to start earning from your views',
                                            style: TextStyle(
                                              color: Colors.orange[300],
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Analytics Section
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A), // Slightly lighter than main background
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: secondaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.analytics,
                                  color: secondaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Content Analytics',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FutureBuilder<int>(
                                        future: _calculateTotalViews(),
                                        builder: (context, snapshot) {
                                          return Text(
                                            _formatViewCount(snapshot.data ?? 0),
                                            style: TextStyle(
                                              color: secondaryColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Total Views',
                                        style: TextStyle(
                                          color: Colors.grey[300],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: Colors.grey[600],
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FutureBuilder<Map<String, dynamic>>(
                                        future: HistoricalAnalyticsService().getLifetimeAnalytics(widget.uid),
                                        builder: (context, snapshot) {
                                          int lifetimeVideos = 0;
                                          if (snapshot.hasData && snapshot.data != null) {
                                            lifetimeVideos = snapshot.data!['lifetime']?['videos'] ?? videoController.myVideos.length;
                                          } else {
                                            // Fallback to current active videos while loading
                                            lifetimeVideos = videoController.myVideos.length;
                                          }
                                          return Text(
                                            lifetimeVideos.toString(),
                                            style: TextStyle(
                                              color: secondaryColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Total Uploads',
                                        style: TextStyle(
                                          color: Colors.grey[300],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 14),
                      
                      // Subscription Section with Dynamic Data
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _getSubscriptionDetails(),
                        builder: (context, snapshot) {
                          String planType = 'No Active Plan';
                          String expiryText = 'N/A';
                          Color planColor = Colors.grey;
                          Color expiryColor = Colors.grey;
                          
                          if (snapshot.hasData && snapshot.data != null) {
                            final subscriptionData = snapshot.data!;
                            planType = subscriptionData['planType'] ?? 'Unknown';
                            final expiryDate = subscriptionData['expiryDate'] as DateTime?;
                            final isActive = subscriptionData['isActive'] ?? false;
                            
                            if (expiryDate != null) {
                              expiryText = _formatDate(expiryDate);
                            }
                            
                            // Set plan color based on type and status
                            if (isActive) {
                              planColor = secondaryColor;
                              expiryColor = Colors.white;
                            } else {
                              planColor = Colors.red;
                              expiryColor = Colors.red;
                            }
                          } else if (snapshot.connectionState == ConnectionState.waiting) {
                            planType = 'Loading...';
                            expiryText = 'Loading...';
                            planColor = Colors.grey;
                          }
                          
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A), // Slightly lighter than main background
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: secondaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: secondaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Subscription Status',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Current Plan',
                                            style: TextStyle(
                                              color: Colors.grey[300],
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            planType,
                                            style: TextStyle(
                                              color: planColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Expires',
                                            style: TextStyle(
                                              color: Colors.grey[300],
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            expiryText,
                                            style: TextStyle(
                                              color: expiryColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      // Upgrade Now Button - Only for Free Trial users
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _getSubscriptionDetails(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data == null) {
                            return const SizedBox.shrink();
                          }
                          
                          final subscriptionData = snapshot.data!;
                          bool isSubscribed = subscriptionData['isActive'] ?? false;
                          String planType = subscriptionData['planType'] ?? 'Free Trial';
                          
                          // Check if user is on Free Trial
                          bool isFreeTrialUser = !isSubscribed || planType.toLowerCase().contains('free') || planType.toLowerCase().contains('trial');
                          
                          if (!isFreeTrialUser) {
                            return const SizedBox.shrink(); // Hide button for paid subscribers
                          }
                          
                          return Column(
                            children: [
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Navigate to subscription/upgrade screen
                                    // You'll need to replace this with your actual subscription screen route
                                    Navigator.of(context).pushNamed('/subscription');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: secondaryColor,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                    shadowColor: secondaryColor.withOpacity(0.3),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.upgrade,
                                        size: 20,
                                        color: Colors.black,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Upgrade Now',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'PRO',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      
                      // App Version Info - positioned at bottom
                      const SizedBox(height: 32),
                      
                      Center(
                        child: Text(
                          'Version 1.0.0 • © PlaySphere',
                          style: TextStyle(
                            color: Colors.grey.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      
                      // Bottom padding to ensure content doesn't clash with bottom nav
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}
