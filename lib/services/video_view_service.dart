import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import 'earnings_service.dart';

/// Service to handle intelligent video view counting with proper engagement tracking
class VideoViewService {
  static final VideoViewService _instance = VideoViewService._internal();
  factory VideoViewService() => _instance;
  VideoViewService._internal();

  // Cache to track video watch sessions in memory
  final Map<String, VideoWatchSession> _watchSessions = {};
  
  // Cache to track recently viewed videos to prevent duplicate counts
  final Map<String, DateTime> _recentlyViewedCache = {};
  
  // Timer to cleanup old cache entries
  Timer? _cleanupTimer;

  static const Duration _minimumWatchDuration = Duration(seconds: 3);
  static const Duration _viewCooldownPeriod = Duration(minutes: 3);
  static const Duration _cacheCleanupInterval = Duration(minutes: 5);

  /// Initialize the service and start cleanup timer
  void initialize() {
    _startCleanupTimer();
  }

  /// Start watching a video - begins tracking watch time
  void startWatching(String videoId, String userId) {
    if (userId.isEmpty) return;
    
    final sessionKey = '${videoId}_$userId';
    
    // Check if we're already tracking this session
    if (_watchSessions.containsKey(sessionKey)) {
      // Resume existing session if paused
      final session = _watchSessions[sessionKey]!;
      if (session.isPaused) {
        session.resume();
      }
      return;
    }
    
    // Check cooldown period
    final cooldownKey = sessionKey;
    if (_recentlyViewedCache.containsKey(cooldownKey)) {
      final lastViewTime = _recentlyViewedCache[cooldownKey]!;
      final timeSinceLastView = DateTime.now().difference(lastViewTime);
      
      if (timeSinceLastView < _viewCooldownPeriod) {
        return;
      }
    }
    
    // Create new watch session
    final session = VideoWatchSession(
      videoId: videoId,
      userId: userId,
      startTime: DateTime.now(),
    );
    
    _watchSessions[sessionKey] = session;
  }

  /// Pause watching a video - stops accumulating watch time
  void pauseWatching(String videoId, String userId) {
    if (userId.isEmpty) return;
    
    final sessionKey = '${videoId}_$userId';
    final session = _watchSessions[sessionKey];
    
    if (session != null && !session.isPaused) {
      session.pause();
      // Debug message - commenting out to reduce terminal noise
    }
  }

  /// Resume watching a video after pause
  void resumeWatching(String videoId, String userId) {
    if (userId.isEmpty) return;
    
    final sessionKey = '${videoId}_$userId';
    final session = _watchSessions[sessionKey];
    
    if (session != null && session.isPaused) {
      session.resume();
    }
  }

  /// Stop watching a video and check if it qualifies as a view
  void stopWatching(String videoId, String userId) {
    if (userId.isEmpty) return;
    
    final sessionKey = '${videoId}_$userId';
    final session = _watchSessions[sessionKey];
    
    if (session == null) return;
    
    // Finalize the session
    session.end();
    
    final totalWatchTime = session.totalWatchTime;    
    // Check if it qualifies as a valid view
    if (totalWatchTime >= _minimumWatchDuration) {
      _recordView(videoId, userId, sessionKey);
    } else {
    }
    
    // Remove the session from cache
    _watchSessions.remove(sessionKey);
  }

  /// Force stop all active sessions (e.g., when app is backgrounded)
  void stopAllSessions(String userId) {
    if (userId.isEmpty) return;
    
    final userSessions = _watchSessions.entries
        .where((entry) => entry.value.userId == userId)
        .toList();
    
    for (final entry in userSessions) {
      final session = entry.value;
      stopWatching(session.videoId, session.userId);
    }
    
    if (userSessions.isNotEmpty) {
    }
  }

  /// Record a valid view to Firebase
  void _recordView(String videoId, String userId, String sessionKey) async {
    try {
      
      DocumentReference videoRef = firestore.collection('videos').doc(videoId);
      
      await firestore.runTransaction((transaction) async {
        DocumentSnapshot videoSnapshot = await transaction.get(videoRef);
        
        if (!videoSnapshot.exists) {
          return;
        }
        
        Map<String, dynamic> videoData = videoSnapshot.data() as Map<String, dynamic>;
        Map<String, dynamic> viewHistory = Map<String, dynamic>.from(videoData['viewHistory'] ?? {});
        
        // Double-check cooldown at database level (safety check)
        if (viewHistory.containsKey(userId)) {
          Timestamp lastViewTimestamp = viewHistory[userId];
          DateTime lastViewTime = lastViewTimestamp.toDate();
          DateTime now = DateTime.now();
          
          if (now.difference(lastViewTime) < _viewCooldownPeriod) {
            return;
          }
        }
        
        // Update view count and history
        int currentViewCount = videoData['viewCount'] ?? 0;
        viewHistory[userId] = Timestamp.now();
        
        transaction.update(videoRef, {
          'viewCount': currentViewCount + 1,
          'viewHistory': viewHistory,
        });
        
        // Update local cache
        _recentlyViewedCache[sessionKey] = DateTime.now();
        
        
        // Update creator earnings after successful view recording
        String creatorUserId = videoData['uid'] ?? '';
        if (creatorUserId.isNotEmpty) {
          // Don't await to keep view recording fast, earnings update happens in background
          _updateCreatorEarningsInBackground(videoId, creatorUserId);
        }
      });
    } catch (e) {
    }
  }

  /// Get current watch time for a video (for debugging)
  Duration getCurrentWatchTime(String videoId, String userId) {
    if (userId.isEmpty) return Duration.zero;
    
    final sessionKey = '${videoId}_$userId';
    final session = _watchSessions[sessionKey];
    
    return session?.totalWatchTime ?? Duration.zero;
  }

  /// Check if a video is currently being watched
  bool isWatching(String videoId, String userId) {
    if (userId.isEmpty) return false;
    
    final sessionKey = '${videoId}_$userId';
    final session = _watchSessions[sessionKey];
    
    return session != null && !session.isPaused;
  }

  /// Start the cleanup timer to remove old cache entries
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cacheCleanupInterval, (timer) {
      _cleanupCache();
    });
  }

  /// Clean up old cache entries to prevent memory leaks
  void _cleanupCache() {
    final now = DateTime.now();
    final cutoffTime = now.subtract(_viewCooldownPeriod * 2); // Keep cache for 2x cooldown period
    
    // Clean up recently viewed cache
    final oldEntries = _recentlyViewedCache.entries
        .where((entry) => entry.value.isBefore(cutoffTime))
        .map((entry) => entry.key)
        .toList();
    
    for (final key in oldEntries) {
      _recentlyViewedCache.remove(key);
    }
    
    // Clean up any stale watch sessions (sessions that haven't been updated in a long time)
    final staleSessions = _watchSessions.entries
        .where((entry) => now.difference(entry.value.lastUpdateTime) > const Duration(minutes: 10))
        .map((entry) => entry.key)
        .toList();
    
    for (final key in staleSessions) {
      _watchSessions.remove(key);
    }
    
    if (oldEntries.isNotEmpty || staleSessions.isNotEmpty) {
    }
  }

  /// Update creator earnings in background with error handling
  void _updateCreatorEarningsInBackground(String videoId, String creatorUserId) async {
    try {
      await EarningsService().updateCreatorEarnings(videoId, creatorUserId);
    } catch (e) {
      
      // Retry once after a delay
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          await EarningsService().updateCreatorEarnings(videoId, creatorUserId);
        } catch (retryError) {
        }
      });
    }
  }

  /// Dispose of the service
  void dispose() {
    _cleanupTimer?.cancel();
    _watchSessions.clear();
    _recentlyViewedCache.clear();
  }
}

/// Represents a single video watch session
class VideoWatchSession {
  final String videoId;
  final String userId;
  final DateTime startTime;
  
  DateTime? _pauseTime;
  DateTime _lastUpdateTime;
  Duration _accumulatedWatchTime = Duration.zero;
  bool _isPaused = false;
  bool _isEnded = false;

  VideoWatchSession({
    required this.videoId,
    required this.userId,
    required this.startTime,
  }) : _lastUpdateTime = DateTime.now();

  /// Get total accumulated watch time
  Duration get totalWatchTime {
    if (_isEnded) return _accumulatedWatchTime;
    
    if (_isPaused) {
      return _accumulatedWatchTime;
    } else {
      // Add current session time
      final currentSessionTime = DateTime.now().difference(_lastUpdateTime);
      return _accumulatedWatchTime + currentSessionTime;
    }
  }

  /// Check if session is currently paused
  bool get isPaused => _isPaused;

  /// Get last update time
  DateTime get lastUpdateTime => _lastUpdateTime;

  /// Pause the session
  void pause() {
    if (!_isPaused && !_isEnded) {
      final now = DateTime.now();
      _accumulatedWatchTime += now.difference(_lastUpdateTime);
      _pauseTime = now;
      _lastUpdateTime = now;
      _isPaused = true;
    }
  }

  /// Resume the session
  void resume() {
    if (_isPaused && !_isEnded) {
      _lastUpdateTime = DateTime.now();
      _pauseTime = null;
      _isPaused = false;
    }
  }

  /// End the session permanently
  void end() {
    if (!_isEnded) {
      if (!_isPaused) {
        final now = DateTime.now();
        _accumulatedWatchTime += now.difference(_lastUpdateTime);
        _lastUpdateTime = now;
      }
      _isEnded = true;
      _isPaused = true;
    }
  }
}
