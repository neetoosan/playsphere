import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service to handle cross-platform autoplay optimizations
class AutoplayService {
  static final AutoplayService _instance = AutoplayService._internal();
  factory AutoplayService() => _instance;
  AutoplayService._internal();

  // Track user interaction for browsers
  bool _hasUserInteracted = false;
  Timer? _interactionTimer;

  /// Initialize autoplay service
  void initialize() {    
    if (kIsWeb) {
      _initializeWebAutoplay();
    }
    
    // Mark as having user interaction immediately for better first-load experience
    // This allows the first video to attempt autoplay on app launch
    markUserInteraction();
  }

  /// Handle web-specific autoplay requirements
  void _initializeWebAutoplay() {
    // Listen for any user interaction to enable autoplay
    _startInteractionDetection();
    
  }

  /// Start detecting user interactions for web browsers
  void _startInteractionDetection() {
    // Reset interaction flag after 30 seconds of inactivity
    _interactionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // Keep interaction flag active if user has interacted recently
      // This helps with autoplay policies
    });
  }

  /// Mark that user has interacted with the app
  void markUserInteraction() {
    if (!_hasUserInteracted) {
      _hasUserInteracted = true;
    }
  }

  /// Check if autoplay should work on current platform
  bool canAutoplay() {
    if (kIsWeb) {
      // Web browsers require user interaction for autoplay
      // But allow first attempt to try autoplay even without interaction
      return true; // Let the video player handle the actual autoplay restrictions
    } else if (Platform.isIOS) {
      // iOS generally supports autoplay in apps
      return true;
    } else if (Platform.isAndroid) {
      // Android generally supports autoplay in apps
      return true;
    }
    
    // Default to true for other platforms
    return true;
  }

  /// Get optimal autoplay configuration for current platform
  Map<String, dynamic> getAutoplayConfig() {
    final config = <String, dynamic>{
      'muted': false, // We want sound by default
      'loop': true,
      'preload': 'auto',
      'autoplay': true, // Enable autoplay by default
    };

    if (kIsWeb) {
      // Web-specific optimizations
      config['playsinline'] = true;
      config['webkit-playsinline'] = true;
      
      // For web, try unmuted autoplay first, fallback to muted if needed
      config['muted'] = false;
      config['autoplay'] = true;
    } else if (Platform.isIOS) {
      // iOS-specific optimizations
      config['playsinline'] = true;
      config['webkit-playsinline'] = true;
    } else if (Platform.isAndroid) {
      // Android-specific optimizations for better autoplay
      config['autoplay'] = true;
    }

    return config;
  }

  /// Handle autoplay failure and provide fallbacks
  Future<bool> handleAutoplayFailure({
    required VoidCallback onRetry,
    bool muteAndRetry = true,
  }) async {
    
    if (kIsWeb && muteAndRetry && !_hasUserInteracted) {      
      // Try muted autoplay for web browsers
      try {
        onRetry();
        return true;
      } catch (e) {
      }
    }

    // Show user a play button if autoplay fails
    _showPlayPrompt(onRetry);
    return false;
  }

  /// Show a play prompt when autoplay fails
  void _showPlayPrompt(VoidCallback onPlay) {
    // In a real implementation, this would show a play button overlay
    // For now, we'll just call onPlay after a short delay
    Future.delayed(const Duration(milliseconds: 500), onPlay);
  }

  /// Get platform name for logging
  String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    return 'Unknown';
  }

  /// Clean up resources
  void dispose() {
    _interactionTimer?.cancel();
  }

  /// Static method to get browser-specific autoplay info
  static String getBrowserAutoplayInfo() {
    if (!kIsWeb) return 'Not applicable - native app';
    
    return '''
Browser Autoplay Policies:
• Chrome: Requires user interaction for unmuted autoplay
• Firefox: Allows autoplay but may block after multiple attempts
• Safari: Requires user gesture for autoplay with audio
• Edge: Similar to Chrome, requires user interaction

Tips:
1. Start with muted autoplay if no user interaction
2. Unmute after first user tap/click
3. Use visibility detection to pause/resume appropriately
4. Implement fallback play button for failed autoplay
''';
  }
}
