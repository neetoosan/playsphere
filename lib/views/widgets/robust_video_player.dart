import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../controllers/video_controller.dart';
import '../../controllers/video_player_manager.dart';
import '../../controllers/auth_controllers.dart';
import '../../services/video_view_service.dart';

class RobustVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String videoId;
  final int? pageIndex;
  final Function(String)? onDoubleTapLike;
  
  const RobustVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.videoId,
    this.pageIndex,
    this.onDoubleTapLike,
  }) : super(key: key);

  @override
  State<RobustVideoPlayer> createState() => _RobustVideoPlayerState();
}

class _RobustVideoPlayerState extends State<RobustVideoPlayer>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Keep alive to prevent rebuilds
  @override
  bool get wantKeepAlive => true;

  final VideoPlayerManager _playerManager = VideoPlayerManager();
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _viewCountUpdated = false;
  bool _showPlayPause = false;
  
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
  
  VideoController? _videoController;
  VideoViewService? _videoViewService;
  
  // Playback monitoring
  Timer? _playbackMonitor;
  DateTime? _lastPlaybackCheck;
  
  // Track if video has ever started playing (for proper indicator hiding)
  bool _hasStartedPlaying = false;
  
  // Track view session state
  bool _isWatchingStarted = false;

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Get video controller reference
    try {
      _videoController = Get.find<VideoController>();
    } catch (e) {
    }
    
    // Initialize VideoViewService
    try {
      _videoViewService = Get.find<VideoViewService>();
    } catch (e) {
    }
    
    // Initialize heart animation
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _heartScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
    ));
    
    _heartOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (_isDisposed) return;
    
    try {      
      _controller = await _playerManager.initializeController(widget.videoId, widget.videoUrl);
      
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitialized = true;
        });
        
        // Initialize intelligent view tracking (no longer update view count directly)
        if (!_viewCountUpdated) {
          _viewCountUpdated = true;
        }
        
        // Add controller listener for immediate state updates
        _controller!.addListener(_onVideoPlayerStateChanged);
        
        // Start continuous playback monitoring
        _startPlaybackMonitoring();
        
        // Configure controller for aggressive autoplay
        await _configureControllerForAutoplay();
        
        // Trigger immediate autoplay check for first load
        _triggerInitialAutoplayCheck();
        
      }
    } catch (e) {      
      // Retry after delay
      if (mounted && !_isDisposed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_isDisposed) {
            _initializeVideo();
          }
        });
      }
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_isDisposed) return;
    
    final visibilityFraction = info.visibleFraction;    
    // Update visibility in manager - this will trigger autoplay if this becomes most visible
    _playerManager.updateVideoVisibility(widget.videoId, visibilityFraction);
    
    // Handle immediate autoplay when video becomes sufficiently visible
    if (visibilityFraction > 0.7 && _controller != null && _isInitialized) {      
      // For first-time visibility, trigger autoplay immediately without delay
      if (!_playerManager.isPlaying(widget.videoId)) {
        _ensureAutoplayWorks();
      }
      
      // Use a small delay for subsequent checks to ensure smooth transitions
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_isDisposed && _playerManager.mostVisibleVideoId == widget.videoId) {
          _ensureAutoplayWorks();
        }
      });
    }
    
    // If video becomes hidden, ensure it's paused
    if (visibilityFraction < 0.3 && _controller != null && _isInitialized) {
      if (_playerManager.isPlaying(widget.videoId)) {
        _playerManager.pauseVideo(widget.videoId);
      }
    }
    
    // Force state update to reflect current playing state
    if (mounted) {
      setState(() {
        // This will update the play/pause indicator
      });
    }
  }

  void _handleTap() {
    if (_controller == null || !_isInitialized) {
      return;
    }
    
    final now = DateTime.now();    
    // Cancel any pending single tap timer
    _tapTimer?.cancel();
    
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 300) {
      // Double tap detected - trigger like immediately and prevent single tap
      _triggerLike();
      _tapCount = 0;
      _lastTapTime = null;
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
    });
  }

  void _triggerLike() {
    // Trigger like animation
    if (mounted) {
      setState(() {
        _showHeartAnimation = true;
      });
    }
    
    _heartAnimationController.forward().then((_) {
      if (mounted) {
        setState(() {
          _showHeartAnimation = false;
        });
        _heartAnimationController.reset();
      }
    });
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Call like function
    if (widget.onDoubleTapLike != null) {
      widget.onDoubleTapLike!(widget.videoId);
    } else if (_videoController != null) {
      _videoController!.likeVideo(widget.videoId, forceLike: true);
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) {
      return;
    }
    
    // Get the actual controller state, not just the manager state
    final isControllerPlaying = _controller!.value.isPlaying;
    final isManagerPlaying = _playerManager.isPlaying(widget.videoId);
        
    // Use the actual controller state as the source of truth
    if (isControllerPlaying) {
      // Video is playing, so pause it
      _playerManager.pauseVideo(widget.videoId);
      _controller!.pause(); // Also pause directly
    } else {
      // Video is paused, so play it
      _playerManager.playVideo(widget.videoId);
    }
    
    // Immediate visual feedback
    if (mounted) {
      setState(() {
        _showPlayPause = true;
      });
      
      // Hide indicator after delay
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _showPlayPause = false;
          });
        }
      });
    }
    
    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _playerManager.pauseAllVideos();
        _pauseWatchSession(); // Pause intelligent view tracking
        break;
      case AppLifecycleState.resumed:
        _playerManager.resumePlayback();
        // Resume view tracking only if video was actually playing
        if (_hasStartedPlaying && _controller != null && _controller!.value.isPlaying) {
          _resumeWatchSession();
        }
        break;
      case AppLifecycleState.detached:
        _playerManager.pauseAllVideos();
        _stopWatchSession(); // Stop intelligent view tracking
        break;
      case AppLifecycleState.hidden:
        _pauseWatchSession(); // Pause view tracking when app is hidden
        break;
    }
  }

  /// Handle video player state changes for immediate UI updates
  void _onVideoPlayerStateChanged() {
    if (_isDisposed || !mounted || _controller == null) return;
    
    final value = _controller!.value;
    final isPlaying = value.isPlaying;
    
    // Track if video has started playing for the first time
    if (isPlaying && !_hasStartedPlaying) {
      _hasStartedPlaying = true;
      _startWatchSession();
    }
    
    // Handle play/pause state changes for view tracking
    if (_hasStartedPlaying) {
      if (isPlaying && !_isWatchingStarted) {
        _startWatchSession();
      } else if (!isPlaying && _isWatchingStarted) {
        _pauseWatchSession();
      }
    }
    
    // Force UI update when playback state changes
    setState(() {
      // This will cause _showPlayPauseIndicator to be re-evaluated
    });
  }
  
  /// Get current user ID safely
  String _getCurrentUserId() {
    try {
      final authController = Get.find<AuthController>();
      return authController.userData?.uid ?? '';
    } catch (e) {
      return '';
    }
  }
  
  /// Start a view tracking session with the VideoViewService
  void _startWatchSession() {
    if (_videoViewService == null || _isWatchingStarted) return;
    
    final userId = _getCurrentUserId();
    if (userId.isEmpty) {
      return;
    }
    
    _isWatchingStarted = true;
    _videoViewService!.startWatching(widget.videoId, userId);
  }
  
  /// Pause the current view tracking session
  void _pauseWatchSession() {
    if (_videoViewService == null || !_isWatchingStarted) return;
    
    final userId = _getCurrentUserId();
    if (userId.isEmpty) return;
    
    _videoViewService!.pauseWatching(widget.videoId, userId);
  }
  
  /// Resume the current view tracking session
  void _resumeWatchSession() {
    if (_videoViewService == null || !_isWatchingStarted) return;
    
    final userId = _getCurrentUserId();
    if (userId.isEmpty) return;
    
    _videoViewService!.resumeWatching(widget.videoId, userId);
  }
  
  /// Stop the current view tracking session
  void _stopWatchSession() {
    if (_videoViewService == null || !_isWatchingStarted) return;
    
    final userId = _getCurrentUserId();
    if (userId.isEmpty) {
      _isWatchingStarted = false;
      return;
    }
    
    _isWatchingStarted = false;
    _videoViewService!.stopWatching(widget.videoId, userId);
  }
  
  /// Start continuous monitoring of playback state
  void _startPlaybackMonitoring() {
    // Cancel existing timer if any
    _playbackMonitor?.cancel();
    
    // Start monitoring every 2 seconds
    _playbackMonitor = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isDisposed || _controller == null || !_isInitialized) {
        timer.cancel();
        return;
      }
      
      _checkPlaybackHealth();
    });
    
  }
  
  /// Check if video playback is healthy and recover if needed
  void _checkPlaybackHealth() {
    if (_controller == null || !_playerManager.isPlaying(widget.videoId)) return;
    
    try {
      final value = _controller!.value;
      final now = DateTime.now();
      
      // Check if video should be playing but isn't
      if (value.isInitialized && !value.hasError) {
        final isPlaying = value.isPlaying;
        final isBuffering = value.isBuffering;
        final position = value.position;
        final duration = value.duration;
        
        // If this is the currently playing video but it's not actually playing
        if (!isPlaying && !isBuffering && 
            position < duration && 
            duration.inMilliseconds > 0 && 
            position.inMilliseconds < duration.inMilliseconds - 1000) { // 1 second buffer
          
          // Check if position hasn't changed in the last check
          if (_lastPlaybackCheck != null && 
              now.difference(_lastPlaybackCheck!).inSeconds >= 3) {
            _attemptPlaybackRecovery();
          }
        }
        
        _lastPlaybackCheck = now;
      }
    } catch (e) {
    }
  }
  
  /// Configure controller for aggressive autoplay across all platforms
  Future<void> _configureControllerForAutoplay() async {
    if (_controller == null || _isDisposed) return;
    
    try {
      
      // Set optimal configuration for autoplay
      await _controller!.setVolume(1.0);
      await _controller!.setLooping(true);
      
      // Enable playback ready for autoplay when visible    
    } catch (e) {
    }
  }
  
  /// Ensure autoplay works when video becomes visible
  Future<void> _ensureAutoplayWorks() async {
    if (_controller == null || _isDisposed || !_isInitialized) return;
    
    try {      
      // Double-check that this video should be playing
      if (_playerManager.mostVisibleVideoId == widget.videoId) {
        
        // First, tell the player manager this should be playing
        _playerManager.playVideo(widget.videoId);
        
        // Verify the controller state
        if (!_controller!.value.isPlaying && !_controller!.value.isBuffering) {
          await _controller!.play();
        }
                
        // Verification check after a delay
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (_controller != null && 
              _controller!.value.isInitialized && 
              !_controller!.value.isPlaying && 
              !_controller!.value.isBuffering &&
              _playerManager.mostVisibleVideoId == widget.videoId &&
              !_isDisposed) {
            
            try {
              await _controller!.seekTo(_controller!.value.position);
              await _controller!.play();
            } catch (e) {
            }
          }
        });
      } else {
      }
      
    } catch (e) {
    }
  }

  /// Attempt to recover playback from various issues
  void _attemptPlaybackRecovery() async {
    if (_controller == null || !_playerManager.isPlaying(widget.videoId)) return;
    
    try {      
      // First, try to simply resume playback
      await _controller!.play();
      
      // Wait a moment and check if it worked
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_controller!.value.isInitialized && 
          !_controller!.value.isPlaying && 
          !_controller!.value.isBuffering &&
          _playerManager.isPlaying(widget.videoId)) {
                
        // If basic recovery failed, try seeking to current position and playing
        final currentPosition = _controller!.value.position;
        await _controller!.seekTo(currentPosition);
        await _controller!.play();
        
        // Final check after advanced recovery
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (_controller!.value.isInitialized && 
            !_controller!.value.isPlaying && 
            !_controller!.value.isBuffering &&
            _playerManager.isPlaying(widget.videoId)) {          
          // If all else fails, restart from beginning
          await _controller!.seekTo(Duration.zero);
          await _controller!.play();
        }
      }
            
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    
    // Stop watch session if active
    _stopWatchSession();
    
    // Cancel playback monitor
    _playbackMonitor?.cancel();
    
    // Cancel tap timer to prevent conflicts
    _tapTimer?.cancel();
    
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Remove video controller listener if it exists
    if (_controller != null) {
      _controller!.removeListener(_onVideoPlayerStateChanged);
    }
    
    // Dispose heart animation
    _heartAnimationController.dispose();
    
    // Note: Don't dispose the video controller here - let the manager handle it
    // The manager will dispose it when appropriate
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final size = MediaQuery.of(context).size;
    
    return VisibilityDetector(
      key: Key('video_${widget.videoId}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(color: Colors.black),
        child: _isInitialized && _controller != null
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleTap,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Video player
                    SizedBox(
                      width: size.width,
                      height: size.height,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.size?.width ?? size.width,
                          height: _controller!.value.size?.height ?? size.height,
                          child: VideoPlayer(_controller!),
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
                    
                    // Play/pause indicator
                    AnimatedOpacity(
                      opacity: _showPlayPauseIndicator() ? 0.8 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Icon(
                            _playerManager.isPlaying(widget.videoId) ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 60,
                          ),
                        ),
                      ),
                    ),
                    
                    // Double-tap heart animation
                    if (_showHeartAnimation)
                      IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _heartAnimationController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _heartOpacityAnimation.value,
                              child: Transform.scale(
                                scale: _heartScaleAnimation.value,
                                child: const Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                  size: 60,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              )
            : const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
      ),
    );
  }

  bool _showPlayPauseIndicator() {
    if (_controller == null || !_isInitialized) return false;
    
    final isActuallyPlaying = _controller!.value.isPlaying;
    final isBuffering = _controller!.value.isBuffering;
    final isManagerPlaying = _playerManager.isPlaying(widget.videoId);
    
    // Show temporary feedback after user tap (but not during buffering)
    if (_showPlayPause && !isBuffering) {
      return true;
    }
    
    // Hide indicator if video is currently playing
    if (isActuallyPlaying) {
      return false;
    }
    
    // Hide indicator during buffering - we'll show a spinner instead
    if (isBuffering) {
      return false;
    }
    
    // Hide indicator if manager thinks video should be playing (autoplay scenario)
    if (isManagerPlaying) {
      return false;
    }
    
    // Hide indicator if video has started playing before (prevents showing during brief pauses)
    if (_hasStartedPlaying && !isActuallyPlaying && !isBuffering) {
      // Only show if user explicitly paused (manager not playing)
      return !isManagerPlaying;
    }
    
    // For videos that haven't started playing yet, only show if truly paused
    return !isActuallyPlaying && !isManagerPlaying;
  }
  
  /// Determine if we should show the loading/buffering indicator
  bool _showLoadingIndicator() {
    if (_controller == null || !_isInitialized) return true; // Show loading while initializing
    
    final isBuffering = _controller!.value.isBuffering;
    final isActuallyPlaying = _controller!.value.isPlaying;
    final isManagerPlaying = _playerManager.isPlaying(widget.videoId);
    
    // Always show loading during buffering
    if (isBuffering) {
      return true;
    }
    
    // Show loading if manager thinks video should be playing but it's not actually playing
    // and it's not buffering (indicates a network/loading issue)
    if (isManagerPlaying && !isActuallyPlaying && !isBuffering) {
      return true;
    }
    
    return false;
  }
  
  /// Trigger initial autoplay check immediately after video initialization
  void _triggerInitialAutoplayCheck() {
    // Small delay to ensure the widget is fully mounted and visible
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_isDisposed && mounted && _controller != null) {        
        // Check if this video should autoplay based on its current visibility
        // This covers the case where the video loads and is immediately visible
        final renderObject = context.findRenderObject();
        if (renderObject != null && renderObject is RenderBox) {
          final size = renderObject.size;
          final position = renderObject.localToGlobal(Offset.zero);
          final screenSize = MediaQuery.of(context).size;
          
          // Calculate rough visibility
          final visibleHeight = (screenSize.height - position.dy).clamp(0, size.height);
          final visibilityFraction = visibleHeight / size.height;          
          // If the video is sufficiently visible, ensure it starts playing
          if (visibilityFraction > 0.5) {
            _playerManager.forceAutoplay(widget.videoId);
          }
        }
      }
    });
  }
}
