import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants.dart';
import '../widgets/custom_icon.dart';
import '../../controllers/video_controller.dart';
import '../../services/screen_recording_service.dart';
import '../../controllers/video_player_manager.dart';
import 'video_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _pageIdx;
  final VideoPlayerManager _playerManager = VideoPlayerManager();
  
  @override
  void initState() {
    super.initState();
    _pageIdx = widget.initialIndex;
    _updateScreenRecordingProtection();
    
    // If starting on video screen, don't auto-start as screen will handle it
    if (_pageIdx == 0) {
    }
  }
  
  void _updateScreenRecordingProtection() {
    if (_pageIdx == 0) {
      // Prevent screen recording on video feed (home page)
      ScreenRecordingService.preventScreenRecording();
    } else {
      // Allow screen recording on other pages
      ScreenRecordingService.allowScreenRecording();
    }
  }
  
  /// Handle navigation between screens and manage video playback
  void _handleNavigation(int fromIndex, int toIndex) {    
    // If leaving video screen (index 0)
    if (fromIndex == 0 && toIndex != 0) {      
      // Critical: Stop audio immediately to prevent bleeding
      _playerManager.pauseAllVideos();
      
      // Small delay to ensure pause takes effect, then dispose
      Future.delayed(const Duration(milliseconds: 50), () {
        _playerManager.disposeAll();
      });
    }
    
    // If returning to video screen (index 0)
    if (fromIndex != 0 && toIndex == 0) {
      // The VideoScreen will handle autoplay on its own initState
    }
  }
  
  @override
  void dispose() {    
    // Ensure all videos are stopped and disposed
    _playerManager.pauseAllVideos();
    _playerManager.disposeAll();
    
    // Ensure screen recording is allowed when leaving the home screen
    ScreenRecordingService.allowScreenRecording();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        onTap: (idx) async {
          // If user taps Home while already on Home screen, refresh the feed
          if (idx == 0 && _pageIdx == 0) {
            try {
              final VideoController videoController = Get.find<VideoController>();
              
              // First scroll to top, then refresh - only if we can access the current video screen state
              final currentVideoScreen = pages[_pageIdx];
              if (currentVideoScreen is VideoScreen) {
                // Can't directly access the state method, so just refresh the feed
              }
              await videoController.refreshVideoFeed();
              
              // Show a subtle feedback to user
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Fresh content loaded! 🆕✨',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.black87,
                  duration: const Duration(milliseconds: 1500),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.only(
                    bottom: 100,
                    left: 20,
                    right: 20,
                  ),
                ),
              );
            } catch (e) {
              // VideoController not found, just refresh
            }
          } else {
            // Handle navigation away from/to video screen
            _handleNavigation(_pageIdx, idx);
            
            setState(() {
              _pageIdx = idx;
            });
            _updateScreenRecordingProtection();
          }
        },
        backgroundColor: backgroundColor,
        type: BottomNavigationBarType.fixed,
        unselectedItemColor: Colors.white,
        selectedItemColor: secondaryColor,
        currentIndex: _pageIdx,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 30),
            label: "Home",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search, size: 30),
            label: "Search",
          ),
          BottomNavigationBarItem(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                // Outer green circle (bigger)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    shape: BoxShape.circle,
                  ),
                ),
                // Inner white circle (bigger)
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Color(0xFF00C853),
                      size: 35,
                    ),
                  ),
                ),
              ],
            ),
            label: '',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.message, size: 30),
            label: "Messages",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 30),
            label: "Profile",
          ),
        ],
      ),
      body: pages[_pageIdx],
    );
  }
}
