import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:play_sphere/views/screens/comment_screen.dart';
import 'package:play_sphere/views/screens/profile_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants.dart';
import '../../controllers/video_controller.dart';
import '../../controllers/video_player_manager.dart';
import '../../services/user_cleanup_service.dart';
import '../widgets/circle_animation.dart';
import '../widgets/robust_video_player.dart';
import '../widgets/subscription_badge.dart';

class VideoScreen extends StatefulWidget {
  VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> with WidgetsBindingObserver, RouteAware {
  final VideoController videoController = Get.put(VideoController());
  final VideoPlayerManager _playerManager = VideoPlayerManager();
  final PageController pageController = PageController(initialPage: 0, viewportFraction: 1);
  
  bool _isScreenActive = false;
  bool _isAppInForeground = true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isScreenActive = true;
        
    // Trigger autoplay after screen is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoplaySystem();
      
      // Additional check after a short delay to ensure first video autoplays
      Future.delayed(const Duration(milliseconds: 500), () {
        _ensureFirstVideoAutoplay();
      });
    });
  }
  
  @override
  void dispose() {    
    _isScreenActive = false;
    WidgetsBinding.instance.removeObserver(this);
    
    // Immediately stop all video playback
    _stopAllVideoPlayback();
    
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        if (_isScreenActive) {
          _pauseAllVideos();
        }
        break;
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        if (_isScreenActive) {
          _resumeVideoPlayback();
        }
        break;
      case AppLifecycleState.detached:
        _stopAllVideoPlayback();
        break;
    }
  }
  
  /// Start the autoplay system when screen becomes active
  void _startAutoplaySystem() {
    if (!_isScreenActive || !_isAppInForeground) return;
        
    // Resume playback for the most visible video
    _playerManager.resumePlayback();
  }
  
  /// Pause all videos but keep them ready to resume
  void _pauseAllVideos() {
    _playerManager.pauseAllVideos();
  }
  
  /// Resume video playback
  void _resumeVideoPlayback() {
    if (!_isScreenActive || !_isAppInForeground) return;
        
    // Small delay to ensure screen is fully visible
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_isScreenActive && _isAppInForeground) {
        _playerManager.resumePlayback();
      }
    });
  }
  
  /// Completely stop all video playback and dispose resources
  void _stopAllVideoPlayback() {    
    // Pause all videos immediately
    _playerManager.pauseAllVideos();
    
    // Dispose all video controllers to prevent background audio
    _playerManager.disposeAll();
  }
  
  /// Handle when screen becomes visible (called from route observer)
  void _onScreenResumed() {
    _isScreenActive = true;
    
    if (_isAppInForeground) {
      _startAutoplaySystem();
    }
  }
  
  /// Handle when screen becomes hidden (called from route observer)
  void _onScreenPaused() {
    _isScreenActive = false;
    
    // Immediately stop all playback when leaving screen
    _stopAllVideoPlayback();
  }
  
  /// Ensure the first video starts playing when screen loads
  void _ensureFirstVideoAutoplay() {
    if (!_isScreenActive || !_isAppInForeground) return;
    
    final videos = videoController.videoList;
    if (videos.isNotEmpty) {
      final firstVideoId = videos[0].id;      
      // Force the first video to start playing
      _playerManager.forceAutoplay(firstVideoId);
    }
  }
  
  /// Method to scroll to top and refresh feed
  Future<void> scrollToTopAndRefresh() async {
    if (pageController.hasClients) {
      await pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Future<void> shareVideo(String id) async {
    await Share.share(
      'I am inviting you to check out some amazing videos on PlaySphere\nhttps://flutter.dev/',
      subject: 'Explore fun videos at PlaySphere. Sign up today!',
    );
    videoController.updateShareCount(id);
  }

  buildProfile(String profilePhoto) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(children: [
        Positioned(
          left: 5,
          child: Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Image(
                image: NetworkImage(profilePhoto),
                fit: BoxFit.cover,
              ),
            ),
          ),
        )
      ]),
    );
  }

  buildMusicAlbum(String profilePhoto) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Column(
        children: [
          Container(
              padding: const EdgeInsets.all(11),
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.grey,
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Image(
                  image: NetworkImage(profilePhoto),
                  fit: BoxFit.cover,
                ),
              ))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Obx(() {
        return NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (notification) {
            notification.disallowIndicator(); // Remove overscroll glow
            return true;
          },
          child: RefreshIndicator(
            onRefresh: () async {
              // Only allow refresh when on first page (index 0)
              if (pageController.page?.round() == 0) {
                await videoController.pullToRefreshVideos();
              }
            },
            color: Colors.white,
            backgroundColor: Colors.black54,
            strokeWidth: 2.5,
            displacement: 40.0,
            child: PageView.builder(
              itemCount: videoController.videoList.length,
              controller: pageController,
              scrollDirection: Axis.vertical,
              physics: const ClampingScrollPhysics(), // Prevent bounce effect
              onPageChanged: (index) {
                HapticFeedback.selectionClick(); // Add haptic feedback for page changes
                videoController.onPageChanged(index);
                
                // Ensure the new page's video starts playing
                if (index < videoController.videoList.length) {
                  final videoId = videoController.videoList[index].id;                  
                  // Small delay to ensure the page transition is complete
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (_isScreenActive && _isAppInForeground) {
                      _playerManager.forceAutoplay(videoId);
                    }
                  });
                }
              },
              itemBuilder: (context, index) {
            final data = videoController.videoList[index];

            return Stack(
              children: [
                RobustVideoPlayer(
                  videoUrl: data.videoUrl,
                  videoId: data.id, // Pass video ID for view count tracking
                  pageIndex: index, // Pass page index for TikTok-like behavior
                  onDoubleTapLike: (videoId) => videoController.likeVideo(videoId, forceLike: true), // Double-tap like callback
                ),
                Column(
                    //sized box
                    children: [
                      //sized box,
                      Expanded(
                          child: Row(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.only(left: 15),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      // Validate user exists before navigating
                                      final userExists = await UserCleanupService.validateUserAndCleanup(data.uid);
                                      if (userExists) {
                                        Get.to(() => ProfileScreen(uid: data.uid));
                                      } else {
                                        Get.snackbar(
                                          'User Not Found',
                                          'This user account no longer exists.',
                                          snackPosition: SnackPosition.TOP,
                                        );
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        Icon(Icons.person),
                                        Text(
                                          " ${data.username}",
                                          style: const TextStyle(
                                            fontSize: 20,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        ConditionalSubscriptionBadge(
                                          userId: data.uid,
                                          size: 18.0,
                                          margin: const EdgeInsets.only(left: 6.0),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    data.caption,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),

                          //sidebar container
                          Container(
                              width: 75,
                              margin: EdgeInsets.only(top: size.height / 2.5),
                              //user profile stat
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  //profile photo
                                  buildProfile(data.profilePhoto),
                                  //likes
                                  Column(children: [
                                    InkWell(
                                      onTap: () {
                                        videoController.likeVideo(data.id);
                                        // The UI will update automatically through reactive programming with GetX
                                      },
                                      child: Icon(
                                        Icons.favorite,
                                        size: 30,
                                        color: data.likes.contains(
                                                authController.userData.uid)
                                            ? Colors.red
                                            : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      data.likes.length.toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ]),

                                  //comments

                                  Column(children: [
                                    InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    CommentScreen(
                                                        id: data.id)));
                                      },
                                      child: const Icon(
                                        Icons.comment,
                                        size: 30,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      data.commentCount.toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ]),

                                  //shares
                                  Column(children: [
                                    InkWell(
                                      onTap: () => shareVideo(data.id),
                                      child: const Icon(
                                        Icons.reply,
                                        size: 30,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      data.shareCount.toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ]),

                                  CircleAnimation(
                                    child: buildMusicAlbum(data.profilePhoto),
                                  ),
                                ],
                              )),
                        ],
                      )),
                    ]),
              ],
            );
          }),
          ),
        );
      }),
    );
  }
}
