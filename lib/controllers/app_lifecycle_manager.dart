import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'video_player_manager.dart';

/// Global app lifecycle manager to handle video playback during app state changes
class AppLifecycleManager extends GetxController with WidgetsBindingObserver {
  final VideoPlayerManager _videoPlayerManager = VideoPlayerManager();
  
  // Track current app state
  AppLifecycleState? _currentState;
  bool _isAppVisible = true;
  
  // Timer for handling web focus changes
  Timer? _focusCheckTimer;
  
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _currentState = WidgetsBinding.instance.lifecycleState;
    _startFocusMonitoring();
  }
  
  @override
  void onClose() {
    _focusCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previousState = _currentState;
    _currentState = state;
    
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isAppVisible = false;
        _handleAppBackgrounded();
        break;
        
      case AppLifecycleState.resumed:
        _isAppVisible = true;
        _handleAppForegrounded();
        break;
        
      case AppLifecycleState.detached:
        _isAppVisible = false;
        _handleAppTerminated();
        break;
        
      case AppLifecycleState.hidden:
        _isAppVisible = false;
        _handleAppBackgrounded();
        break;
    }
  }
  
  /// Handle when app goes to background or loses focus
  void _handleAppBackgrounded() {
    _videoPlayerManager.pauseAllVideos();
  }
  
  /// Handle when app comes to foreground or gains focus
  void _handleAppForegrounded() {
    // Add a small delay to ensure the app is fully visible before resuming
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_isAppVisible) {
        _videoPlayerManager.resumePlayback();
      }
    });
  }
  
  /// Handle when app is terminated
  void _handleAppTerminated() {
    _videoPlayerManager.disposeAll();
  }
  
  /// Start monitoring for focus changes (especially useful for web)
  void _startFocusMonitoring() {
    // Check app focus state every second (mainly for web browsers)
    _focusCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkAppFocus();
    });
  }
  
  /// Check if app has focus and handle accordingly
  void _checkAppFocus() {
    try {
      // This primarily helps with web browsers where tab changes might not
      // trigger lifecycle events immediately
      final currentState = WidgetsBinding.instance.lifecycleState;
      
      // If the lifecycle state indicates the app should be visible but our
      // internal state doesn't match, update it
      if (currentState == AppLifecycleState.resumed && !_isAppVisible) {
        _isAppVisible = true;
        _handleAppForegrounded();
      } else if ((currentState == AppLifecycleState.paused || 
                 currentState == AppLifecycleState.inactive ||
                 currentState == AppLifecycleState.hidden) && _isAppVisible) {
        _isAppVisible = false;
        _handleAppBackgrounded();
      }
    } catch (e) {
      // Silently handle any errors in focus checking
      // This is non-critical functionality
    }
  }
  
  /// Public method to manually pause all videos (can be called by other parts of the app)
  void pauseAllVideos() {
    _videoPlayerManager.pauseAllVideos();
  }
  
  /// Public method to manually resume playback
  void resumePlayback() {
    if (_isAppVisible) {
      _videoPlayerManager.resumePlayback();
    }
  }
  
  /// Get current visibility state
  bool get isAppVisible => _isAppVisible;
}
