import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants.dart';
import '../../controllers/video_controller.dart';
import '../../controllers/comment_controller.dart';
import '../../controllers/video_player_manager.dart';
import '../../models/video.dart';
import '../widgets/circle_animation.dart';
import '../widgets/robust_video_player.dart';
import 'comment_screen.dart';

class SingleVideoScreen extends StatefulWidget {
  final String videoId;
  const SingleVideoScreen({super.key, required this.videoId});

  @override
  State<SingleVideoScreen> createState() => _SingleVideoScreenState();
}

class _SingleVideoScreenState extends State<SingleVideoScreen> with WidgetsBindingObserver {
  final VideoController videoController = Get.put(VideoController());
  final CommentController commentController = Get.put(CommentController());
  final VideoPlayerManager _playerManager = VideoPlayerManager();
  Video? currentVideo;
  bool isLoading = true;
  String errorMessage = '';
  bool _isScreenActive = false;
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isScreenActive = true;
    _loadVideo();
  }
  
  @override
  void dispose() {
    _isScreenActive = false;
    WidgetsBinding.instance.removeObserver(this);
    // Stop video playback when leaving
    _playerManager.pauseAllVideos();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        if (_isScreenActive && currentVideo != null) {
          _playerManager.pauseVideo(currentVideo!.id);
        }
        break;
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        if (_isScreenActive && currentVideo != null) {
          _playerManager.forceAutoplay(currentVideo!.id);
        }
        break;
      case AppLifecycleState.detached:
        _playerManager.pauseAllVideos();
        break;
    }
  }

  Future<void> _loadVideo() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      // Get the specific video from Firestore
      DocumentSnapshot doc = await firestore.collection('videos').doc(widget.videoId).get();
      
      if (doc.exists) {
        currentVideo = Video.fromSnap(doc);
        
        // Update view count with the new cooldown logic
        videoController.updateViewCount(widget.videoId);
        
        setState(() {
          isLoading = false;
        });
        
        // Ensure video autoplays after loading
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_isScreenActive && _isAppInForeground && currentVideo != null) {
            _playerManager.forceAutoplay(currentVideo!.id);
          }
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Video not found';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading video: $e';
      });
    }
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

  Future<void> shareVideo() async {
    await Share.share(
      'Check out this amazing video on PlaySphere!\nhttps://flutter.dev/',
      subject: 'Amazing video on PlaySphere',
    );
    
    // Update share count
    if (currentVideo != null) {
      videoController.updateShareCount(currentVideo!.id);
      // Refresh the video data to show updated share count
      _loadVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        title: const Text(
          'Video',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Loading video...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : errorMessage.isNotEmpty
              ? Center(
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
                        errorMessage,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadVideo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondaryColor,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : currentVideo == null
                  ? const Center(
                      child: Text(
                        'Video not available',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : Stack(
                      children: [
                        RobustVideoPlayer(
                          videoUrl: currentVideo!.videoUrl,
                          videoId: currentVideo!.id,
                          onDoubleTapLike: (videoId) {
                            // Optimistic like update for single video screen - only like if not already liked
                            setState(() {
                              String uid = authController.userData!.uid;
                              List<dynamic> updatedLikes = List.from(currentVideo!.likes);
                              
                              // Only add like if not already liked (double-tap should only like, not unlike)
                              if (!updatedLikes.contains(uid)) {
                                updatedLikes.add(uid);
                                
                                // Update current video with new likes
                                currentVideo = Video(
                                  username: currentVideo!.username,
                                  uid: currentVideo!.uid,
                                  id: currentVideo!.id,
                                  likes: updatedLikes,
                                  commentCount: currentVideo!.commentCount,
                                  shareCount: currentVideo!.shareCount,
                                  viewCount: currentVideo!.viewCount,
                                  viewHistory: currentVideo!.viewHistory,
                                  caption: currentVideo!.caption,
                                  videoUrl: currentVideo!.videoUrl,
                                  profilePhoto: currentVideo!.profilePhoto,
                                  thumbnail: currentVideo!.thumbnail,
                                  uploadTimestamp: currentVideo!.uploadTimestamp,
                                );
                              }
                            });
                            
                            // Update Firestore in background (only like, don't unlike)
                            videoController.likeVideo(currentVideo!.id, forceLike: true);
                          },
                        ),
                        Column(
                          children: [
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
                                          Row(
                                            children: [
                                              const Icon(Icons.person, color: Colors.white),
                                              Text(
                                                " ${currentVideo!.username}",
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            currentVideo!.caption,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          // Show view count
                                          Row(
                                            children: [
                                              const Icon(Icons.visibility, color: Colors.grey, size: 16),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${currentVideo!.viewCount} views',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 75,
                                    margin: EdgeInsets.only(top: size.height / 2.5),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        buildProfile(currentVideo!.profilePhoto),
                                        
                                        // Likes
                                        Column(
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                // Optimistic like update
                                                setState(() {
                                                  String uid = authController.userData!.uid;
                                                  List<dynamic> updatedLikes = List.from(currentVideo!.likes);
                                                  
                                                  if (updatedLikes.contains(uid)) {
                                                    updatedLikes.remove(uid);
                                                  } else {
                                                    updatedLikes.add(uid);
                                                  }
                                                  
                                                  // Update current video with new likes
                                                  currentVideo = Video(
                                                    username: currentVideo!.username,
                                                    uid: currentVideo!.uid,
                                                    id: currentVideo!.id,
                                                    likes: updatedLikes,
                                                    commentCount: currentVideo!.commentCount,
                                                    shareCount: currentVideo!.shareCount,
                                                    viewCount: currentVideo!.viewCount,
                                                    viewHistory: currentVideo!.viewHistory,
                                                    caption: currentVideo!.caption,
                                                    videoUrl: currentVideo!.videoUrl,
                                                    profilePhoto: currentVideo!.profilePhoto,
                                                    thumbnail: currentVideo!.thumbnail,
                                                    uploadTimestamp: currentVideo!.uploadTimestamp,
                                                  );
                                                });
                                                
                                                // Update Firestore in background
                                                videoController.likeVideo(currentVideo!.id);
                                              },
                                              child: Icon(
                                                Icons.favorite,
                                                size: 30,
                                                color: currentVideo!.likes.contains(authController.userData!.uid)
                                                    ? Colors.red
                                                    : Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 7),
                                            Text(
                                              currentVideo!.likes.length.toString(),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Comments
                                        Column(
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                Get.to(() => CommentScreen(id: currentVideo!.id));
                                              },
                                              child: const Icon(
                                                Icons.comment,
                                                size: 30,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 7),
                                            Text(
                                              currentVideo!.commentCount.toString(),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Share
                                        Column(
                                          children: [
                                            InkWell(
                                              onTap: shareVideo,
                                              child: const Icon(
                                                Icons.reply,
                                                size: 30,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 7),
                                            Text(
                                              currentVideo!.shareCount.toString(),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),

                                        CircleAnimation(
                                          child: buildMusicAlbum(currentVideo!.profilePhoto),
                                        ),
                                      ],
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
  }
}
