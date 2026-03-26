import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Singleton manager to handle multiple video players and ensure only one plays at a time
class VideoPlayerManager {
  static final VideoPlayerManager _instance = VideoPlayerManager._internal();
  factory VideoPlayerManager() => _instance;
  VideoPlayerManager._internal();

  // Track the currently playing video
  String? _currentPlayingVideoId;
  VideoPlayerController? _currentPlayingController;
  
  // Map to store all video controllers
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, StreamSubscription> _listeners = {};
  
  // Visibility tracking
  final Set<String> _visibleVideos = {};
  String? _mostVisibleVideoId;

  /// Initialize a video controller for a specific video
  Future<VideoPlayerController> initializeController(String videoId, String videoUrl) async {    
    // Return existing controller if already initialized
    if (_controllers.containsKey(videoId)) {
      return _controllers[videoId]!;
    }

    // Create new controller
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    
    try {
      await controller.initialize();
      
      // Configure controller for optimal autoplay
      await controller.setVolume(1.0);
      await controller.setLooping(true);
      
      // Store controller
      _controllers[videoId] = controller;
      
      // Add error listener
      controller.addListener(() {
        _handleControllerEvent(videoId, controller);
      });
            
      // Trigger immediate autoplay check after initialization
      // This ensures videos start playing as soon as they're ready and visible
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_controllers.containsKey(videoId)) {
          _checkAndTriggerAutoplay(videoId);
        }
      });
      
      return controller;
    } catch (e) {
      controller.dispose();
      throw e;
    }
  }

  /// Handle controller events (errors, completion, etc.)
  void _handleControllerEvent(String videoId, VideoPlayerController controller) {
    if (!_controllers.containsKey(videoId)) return;
    
    final value = controller.value;
    
    // Handle errors
    if (value.hasError) {
      _restartVideo(videoId);
      return;
    }
    
    // Handle completion (backup for looping)
    if (value.position >= value.duration && value.duration.inMilliseconds > 0) {
      _restartVideo(videoId);
      return;
    }
    
    // Handle buffering state - don't pause video during buffering, just wait
    if (value.isBuffering && _currentPlayingVideoId == videoId) {
      // Video is buffering - this is normal, don't interrupt
      return;
    }
    
    // Check for unexpected stops during playback (only if not buffering)
    if (_currentPlayingVideoId == videoId && controller.value.isInitialized && !value.isBuffering) {
      final isPlaying = controller.value.isPlaying;
      final position = controller.value.position;
      final duration = controller.value.duration;
      
      // Detect unexpected pauses (not at end, not buffering, but not playing)
      if (!isPlaying && 
          position < duration && 
          duration.inMilliseconds > 0 && 
          position.inMilliseconds < duration.inMilliseconds - 500) { // Allow 500ms buffer before end
        
        // Only attempt recovery if video has been stopped for a while
        // This prevents interfering with normal buffering
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (_controllers.containsKey(videoId) && 
              _currentPlayingVideoId == videoId && 
              !controller.value.isPlaying && 
              !controller.value.isBuffering) {
            _recoverPlayback(videoId);
          }
        });
      }
    }
  }

  /// Restart a video from the beginning
  void _restartVideo(String videoId) async {
    final controller = _controllers[videoId];
    if (controller == null) return;
    
    try {
      await controller.seekTo(Duration.zero);
      if (_currentPlayingVideoId == videoId) {
        await controller.play();
      }
    } catch (e) {
    }
  }

  /// Recover playback from unexpected stops
  void _recoverPlayback(String videoId) async {
    final controller = _controllers[videoId];
    if (controller == null || _currentPlayingVideoId != videoId) return;
    
    try {
      // Attempt to resume playback from current position
      if (controller.value.isInitialized) {
        await controller.play();        
        // Double-check after a short delay to ensure recovery worked
        Future.delayed(const Duration(milliseconds: 500), () {
          if (controller.value.isInitialized && 
              !controller.value.isPlaying && 
              !controller.value.isBuffering &&
              _currentPlayingVideoId == videoId) {
            _restartVideo(videoId);
          }
        });
      }
    } catch (e) {
      _restartVideo(videoId);
    }
  }

  /// Update visibility of a video
  void updateVideoVisibility(String videoId, double visibilityFraction) {
    
    if (visibilityFraction > 0.7) {
      _visibleVideos.add(videoId);
      
      // Update most visible video and trigger immediate autoplay
      if (_mostVisibleVideoId != videoId) {
        String? previousMostVisible = _mostVisibleVideoId;
        _mostVisibleVideoId = videoId;
        
        // Immediately handle the visibility change
        _handleVisibilityChange();
      } else {
        // Even if it's the same video, ensure it's playing (fixes first load issue)
        if (_currentPlayingVideoId != videoId) {
          playVideo(videoId);
        }
      }
    } else if (visibilityFraction < 0.3) {
      _visibleVideos.remove(videoId);
      
      // If this was the most visible video, find a new one
      if (_mostVisibleVideoId == videoId) {
        String? newMostVisible = _visibleVideos.isNotEmpty ? _visibleVideos.first : null;
        _mostVisibleVideoId = newMostVisible;
        _handleVisibilityChange();
      }
    }
    
    // For videos with medium visibility (between 0.3 and 0.7), keep them in the visible set
    // but don't change the most visible unless they exceed 0.7
    if (visibilityFraction >= 0.3 && visibilityFraction <= 0.7) {
      _visibleVideos.add(videoId);
    }
  }

  /// Handle visibility changes
  void _handleVisibilityChange() {    
    // Pause current video if different from most visible
    if (_currentPlayingVideoId != null && 
        _currentPlayingVideoId != _mostVisibleVideoId &&
        _currentPlayingController != null) {
      _currentPlayingController!.pause();
      _currentPlayingVideoId = null;
      _currentPlayingController = null;
    }

    // Play most visible video immediately
    if (_mostVisibleVideoId != null && 
        _mostVisibleVideoId != _currentPlayingVideoId) {
      playVideo(_mostVisibleVideoId!);
    }
  }

  /// Play a specific video
  void playVideo(String videoId) async {
    final controller = _controllers[videoId];
    if (controller == null) {
      return;
    }

    // Pause current video if different
    if (_currentPlayingController != null && _currentPlayingVideoId != videoId) {
      _currentPlayingController!.pause();
    }

    // Set new playing video
    _currentPlayingVideoId = videoId;
    _currentPlayingController = controller;
    
    try {
      if (!controller.value.isPlaying) {
        await controller.play();
      } else {
      }
    } catch (e) {
      // Try again after a short delay
      Future.delayed(const Duration(milliseconds: 300), () async {
        try {
          if (_currentPlayingVideoId == videoId && controller.value.isInitialized) {
            await controller.play();
          }
        } catch (retryError) {
        }
      });
    }
  }

  /// Pause a specific video
  void pauseVideo(String videoId) {
    final controller = _controllers[videoId];
    if (controller == null) return;

    try {
      controller.pause();
    } catch (e) {
    }
    
    if (_currentPlayingVideoId == videoId) {
      _currentPlayingVideoId = null;
      _currentPlayingController = null;
    }
  }

  /// Pause all videos
  void pauseAllVideos() {    
    for (final entry in _controllers.entries) {
      try {
        entry.value.pause();
      } catch (e) {
      }
    }
    
    _currentPlayingVideoId = null;
    _currentPlayingController = null;
  }

  /// Resume playing the most visible video
  void resumePlayback() {
    if (_mostVisibleVideoId != null) {
      playVideo(_mostVisibleVideoId!);
    } else {
    }
  }

  /// Get controller for a video
  VideoPlayerController? getController(String videoId) {
    return _controllers[videoId];
  }

  /// Check if a video is currently playing
  bool isPlaying(String videoId) {
    return _currentPlayingVideoId == videoId;
  }

  /// Dispose a specific video controller
  void disposeController(String videoId) {    
    final controller = _controllers.remove(videoId);
    final listener = _listeners.remove(videoId);
    
    if (listener != null) {
      listener.cancel();
    }
    
    if (controller != null) {
      controller.dispose();
    }
    
    _visibleVideos.remove(videoId);
    
    if (_currentPlayingVideoId == videoId) {
      _currentPlayingVideoId = null;
      _currentPlayingController = null;
    }
    
    if (_mostVisibleVideoId == videoId) {
      _mostVisibleVideoId = _visibleVideos.isNotEmpty ? _visibleVideos.first : null;
      _handleVisibilityChange();
    }
  }

  /// Dispose all controllers
  void disposeAll() {    
    // First, pause all videos to stop audio immediately
    pauseAllVideos();
    
    // Cancel all listeners
    for (final entry in _listeners.entries) {
      try {
        entry.value.cancel();
      } catch (e) {
      }
    }
    
    // Dispose all controllers
    for (final entry in _controllers.entries) {
      try {
        entry.value.dispose();
      } catch (e) {
      }
    }
    
    // Clear all state
    _controllers.clear();
    _listeners.clear();
    _visibleVideos.clear();
    _currentPlayingVideoId = null;
    _currentPlayingController = null;
    _mostVisibleVideoId = null;
}

  /// Get current playing video ID
  String? get currentPlayingVideoId => _currentPlayingVideoId;
  
  /// Get most visible video ID
  String? get mostVisibleVideoId => _mostVisibleVideoId;
  
  /// Check if a video should autoplay immediately after initialization
  void _checkAndTriggerAutoplay(String videoId) {
    // Only trigger autoplay if this video is in the visible set
    if (_visibleVideos.contains(videoId)) {      
      // If no video is currently set as most visible, or this video has higher visibility, make it play
      if (_mostVisibleVideoId == null || _mostVisibleVideoId == videoId) {
        _mostVisibleVideoId = videoId;
        playVideo(videoId);
      }
    }
  }
  
  /// Force autoplay for a specific video (used when screen loads)
  void forceAutoplay(String videoId) {
    if (_controllers.containsKey(videoId)) {
      _mostVisibleVideoId = videoId;
      playVideo(videoId);
    } else {
    }
  }
}
