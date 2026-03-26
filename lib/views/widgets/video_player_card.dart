import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../../controllers/video_controller.dart';

class VideoPlayerCard extends StatefulWidget {
  final String videoUrl;
  final String? videoId; // Optional video ID for view count tracking
  final int? pageIndex; // Track which page this video is on
  final Function(String)? onDoubleTapLike; // Callback for double-tap like
  const VideoPlayerCard({
    Key? key,
    required this.videoUrl,
    this.videoId,
    this.pageIndex,
    this.onDoubleTapLike,
  }) : super(key: key);

  @override
  _VideoPlayerCardSate createState() => _VideoPlayerCardSate();
}

class _VideoPlayerCardSate extends State<VideoPlayerCard> with TickerProviderStateMixin, WidgetsBindingObserver {
  late VideoPlayerController videoPlayerController;
  bool _showPlayPause = false;
  bool _isInitialized = false;
  bool _viewCountUpdated = false; // Track if view count has been updated
  bool _isDisposed = false;
  bool _shouldAutoPlay = true;
  VideoController? _videoController;
  
  // Double-tap like animation variables
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  bool _showHeartAnimation = false;
  
  // Tap detection variables
  int _tapCount = 0;
  DateTime? _lastTapTime;
  Timer? _tapTimer; // Timer for handling delayed single tap
  bool _processingTap = false; // Flag to prevent tap conflicts
  
  // Track if video has ever started playing (for proper indicator hiding)
  bool _hasStartedPlaying = false;

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Get video controller reference for view count tracking only
    try {
      _videoController = Get.find<VideoController>();
    } catch (e) {
    }
    
    // Initialize heart animation controller
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Heart scale animation (grows then shrinks)
    _heartScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 0.8, // Further reduced for a more subtle, TikTok-like effect
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
    ));
    
    // Heart opacity animation (fades out)
    _heartOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    _initializeVideo();
  }
  
  void _initializeVideo() {
    if (_isDisposed) return;    
    videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((value) {
        if (mounted && !_isDisposed) {          
          // Set volume and looping
          videoPlayerController.setVolume(1.0);
          videoPlayerController.setLooping(true);
          
          // Add listener for video events to handle completion, errors, etc.
          videoPlayerController.addListener(_videoPlayerListener);
          
          // Auto-play video immediately after initialization
          if (_shouldAutoPlay) {
            videoPlayerController.play();
          }
          
          setState(() {
            _isInitialized = true;
          });
          
          // Update view count when video starts playing (only once per instance)
          if (widget.videoId != null && !_viewCountUpdated) {
            _updateViewCount();
          }
        }
      }).catchError((error) {
        // Retry initialization after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_isDisposed) {
            _initializeVideo();
          }
        });
      });
  }
  
  // Video player listener to handle playback events
  void _videoPlayerListener() {
    if (_isDisposed || !mounted) return;
    
    final VideoPlayerValue value = videoPlayerController.value;
    final isPlaying = value.isPlaying;
    
    // Track if video has started playing for the first time
    if (isPlaying && !_hasStartedPlaying) {
      _hasStartedPlaying = true;
      // Force UI update to hide play indicator immediately
      setState(() {});
    }
    
    // Handle video completion (shouldn't happen with looping, but just in case)
    if (value.position >= value.duration && value.duration.inMilliseconds > 0) {
      _restartVideo();
    }
    
    // Handle video errors
    if (value.hasError) {
      // Try to restart the video after an error
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_isDisposed) {
          _restartVideo();
        }
      });
    }
    
    // Handle buffering - ensure video keeps playing after buffering
    if (value.isBuffering && _shouldAutoPlay) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isDisposed && !videoPlayerController.value.isPlaying && _shouldAutoPlay) {
          videoPlayerController.play();
        }
      });
    }
  }
  
  // Restart video from beginning
  void _restartVideo() async {
    if (_isDisposed || !mounted) return;
    
    try {
      await videoPlayerController.seekTo(Duration.zero);
      if (_shouldAutoPlay && !videoPlayerController.value.isPlaying) {
        await videoPlayerController.play();
      }
    } catch (e) {
    }
  }
  
  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Pause video when app goes to background
        if (_isInitialized && videoPlayerController.value.isPlaying) {
          videoPlayerController.pause();
          _shouldAutoPlay = true; // Remember to resume when app comes back
        }
        break;
      case AppLifecycleState.resumed:
        // Resume video when app comes back to foreground
        if (_isInitialized && _shouldAutoPlay && !videoPlayerController.value.isPlaying) {
          videoPlayerController.play();
        }
        break;
      case AppLifecycleState.detached:
        // Dispose video when app is terminated
        _shouldAutoPlay = false;
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }
  
  
  void _updateViewCount() {
    if (_videoController != null && widget.videoId != null && !_viewCountUpdated) {
      _videoController!.updateViewCount(widget.videoId!);
      _viewCountUpdated = true;
    }
  }

  void _handleTap() {
    if (!_isInitialized || _processingTap) {
      return;
    }
    
    final now = DateTime.now();    
    _processingTap = true;
    
    // Cancel any pending single tap timer
    _tapTimer?.cancel();
    
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 300) {
      // Double tap detected - trigger like immediately and prevent single tap
      _triggerLike();
      _tapCount = 0;
      _lastTapTime = null;
      _processingTap = false;
      return;
    }
    
    // Potential single tap - wait for double tap timeout before executing
    _lastTapTime = now;
    _tapCount = 1;
    
    // Set a timer to execute single tap action after double-tap timeout
    _tapTimer = Timer(const Duration(milliseconds: 300), () {
      if (_tapCount == 1 && mounted && !_isDisposed) {
        _togglePlayPause();
      }
      _tapCount = 0;
      _processingTap = false;
    });
  }
  
  void _triggerLike() {
    // Trigger like animation
    setState(() {
      _showHeartAnimation = true;
    });
    
    _heartAnimationController.forward().then((_) {
      if (mounted) {
        setState(() {
          _showHeartAnimation = false;
        });
        _heartAnimationController.reset();
      }
    });
    
    // Trigger haptic feedback
    HapticFeedback.lightImpact();
    
    // Call like function (only if not already liked)
    if (widget.videoId != null) {
      if (widget.onDoubleTapLike != null) {
        widget.onDoubleTapLike!(widget.videoId!);
      } else if (_videoController != null) {
        _videoController!.likeVideo(widget.videoId!, forceLike: true);
      }
    }
  }
  
  void _togglePlayPause() {
    setState(() {
      if (videoPlayerController.value.isPlaying) {
        videoPlayerController.pause();
        _shouldAutoPlay = false; // User manually paused, don't auto-resume
      } else {
        videoPlayerController.play();
        _shouldAutoPlay = true; // User manually played, enable auto-resume
      }
      _showPlayPause = true;
    });
    
    // Hide the play/pause icon after a short delay when playing
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && videoPlayerController.value.isPlaying) {
        setState(() {
          _showPlayPause = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _shouldAutoPlay = false;
    
    // Cancel tap timer to prevent conflicts
    _tapTimer?.cancel();
    
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Remove video player listener
    if (_isInitialized) {
      videoPlayerController.removeListener(_videoPlayerListener);
    }
    
    // Dispose controllers
    _heartAnimationController.dispose();
    videoPlayerController.dispose();
    
    super.dispose();
  }

  bool _showPlayPauseIndicator() {
    if (!_isInitialized) return false;
    
    final isActuallyPlaying = videoPlayerController.value.isPlaying;
    final isBuffering = videoPlayerController.value.isBuffering;
    
    // Show temporary feedback after user tap (but not during buffering)
    if (_showPlayPause && !isBuffering) {
      return true;
    }
    
    // Hide indicator during buffering - we'll show a spinner instead
    if (isBuffering) {
      return false;
    }
    
    // Show play button only when video is truly paused (not during autoplay)
    // If we should autoplay but controller isn't playing, don't show indicator
    // (this handles autoplay startup delays)
    if (!isActuallyPlaying && !_shouldAutoPlay) {
      return true;
    }
    
    // Hide indicator in all other cases (playing, autoplaying, etc.)
    return false;
  }
  
  /// Determine if we should show the loading/buffering indicator
  bool _showLoadingIndicator() {
    if (!_isInitialized) return true; // Show loading while initializing
    
    final isBuffering = videoPlayerController.value.isBuffering;
    final isActuallyPlaying = videoPlayerController.value.isPlaying;
    
    // Always show loading during buffering
    if (isBuffering) {
      return true;
    }
    
    // Show loading if video should be autoplaying but isn't actually playing
    // and it's not buffering (indicates a network/loading issue)
    if (_shouldAutoPlay && !isActuallyPlaying && !isBuffering) {
      return true;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      width: size.width,
      height: size.height,
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: GestureDetector(
        onTap: _handleTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ensure video fits properly without overscroll effects
            SizedBox(
              width: size.width,
              height: size.height,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: videoPlayerController.value.size?.width ?? size.width,
                  height: videoPlayerController.value.size?.height ?? size.height,
                  child: VideoPlayer(videoPlayerController),
                ),
              ),
            ),
            
            // Buffering/Loading indicator
            AnimatedOpacity(
              opacity: _showLoadingIndicator() ? 0.9 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(24),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
            ),
            
            // Show play/pause icon with TikTok-like behavior
            // Only show icon when video is paused OR briefly when user taps during playback
            AnimatedOpacity(
              opacity: _showPlayPauseIndicator() ? 0.8 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(20),
                child: Icon(
                  videoPlayerController.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
            // Double-tap heart animation
            if (_showHeartAnimation)
              AnimatedBuilder(
                animation: _heartAnimationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _heartOpacityAnimation.value,
                    child: Transform.scale(
                      scale: _heartScaleAnimation.value,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red, // Red color for like animation
                        size: 60, // Further reduced from 80
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
