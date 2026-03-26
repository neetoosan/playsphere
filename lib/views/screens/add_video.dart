//<------- functionality: Add video button to select a video. On successful selection of video, user is redirected to confirm screen. -->

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../constants.dart';
import './confirm_screen.dart';
import 'subscription_screen.dart';
import 'home_screen.dart';
import '../../services/payment_service.dart';
import '../widgets/custom_icon.dart';

class AddVideoScreen extends StatefulWidget {
  const AddVideoScreen({super.key});

  @override
  State<AddVideoScreen> createState() => _AddVideoScreenState();
}

class _AddVideoScreenState extends State<AddVideoScreen> {
  final PaymentService _paymentService = Get.find<PaymentService>();
  bool _hasActiveSubscription = false;
  bool _isCheckingSubscription = true;
  
  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }
  
  Future<void> _checkSubscriptionStatus() async {
    final userId = authController.userData?.uid;
    if (userId != null) {
      try {
        final hasSubscription = await _paymentService.hasActiveSubscription(userId);
        if (mounted) {
          setState(() {
            _hasActiveSubscription = hasSubscription;
            _isCheckingSubscription = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _hasActiveSubscription = false;
            _isCheckingSubscription = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _hasActiveSubscription = false;
          _isCheckingSubscription = false;
        });
      }
    }
  }

  Future<bool> _checkPermissions(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.status;
        final microphoneStatus = await Permission.microphone.status;
        
        // If permissions are permanently denied, we can't request them
        if (cameraStatus.isPermanentlyDenied || microphoneStatus.isPermanentlyDenied) {
          _showPermissionDialog('Camera and microphone permissions are required. Please enable them in your device settings.');
          return false;
        }
        
        if (cameraStatus.isDenied || microphoneStatus.isDenied) {
          final permissions = await [
            Permission.camera,
            Permission.microphone,
          ].request();
          
          return permissions[Permission.camera]!.isGranted && 
                 permissions[Permission.microphone]!.isGranted;
        }
        return cameraStatus.isGranted && microphoneStatus.isGranted;
      } else {
        // For gallery access - try different permission strategies
        
        // First try modern permissions (Android 13+)
        try {
          final videosStatus = await Permission.videos.status;
          if (videosStatus.isGranted) {
            return true;
          }
          
          if (!videosStatus.isPermanentlyDenied && videosStatus.isDenied) {
            final result = await Permission.videos.request();
            if (result.isGranted) {
              return true;
            }
          }
        } catch (e) {
        }
        
        // Try photos permission
        try {
          final photosStatus = await Permission.photos.status;
          if (photosStatus.isGranted) {
            return true;
          }
          
          if (!photosStatus.isPermanentlyDenied && photosStatus.isDenied) {
            final result = await Permission.photos.request();
            if (result.isGranted) {
              return true;
            }
          }
        } catch (e) {
        }
        
        // Fallback to storage permission for older Android versions
        try {
          final storageStatus = await Permission.storage.status;
          if (storageStatus.isGranted) {
            return true;
          }
          
          if (!storageStatus.isPermanentlyDenied && storageStatus.isDenied) {
            final result = await Permission.storage.request();
            return result.isGranted;
          }
          
          if (storageStatus.isPermanentlyDenied) {
            _showPermissionDialog('Storage permission is required to access your videos. Please enable it in your device settings.');
            return false;
          }
        } catch (e) {
        }
        
        // If we reach here, try to proceed anyway as some devices might work without explicit permissions
        return true;
      }
    } catch (e) {
      // If permission checking fails, let's try to proceed anyway
      return true;
    }
  }

  void _showErrorDialog(String message, {bool navigateBackOnDismiss = false}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Error',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (navigateBackOnDismiss) {
                  _resetToAddVideoScreen();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: secondaryColor,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  void _resetToAddVideoScreen() {
    if (!mounted) return;
    
    // Refresh the subscription status to ensure clean state
    if (mounted) {
      setState(() {
        _isCheckingSubscription = true;
      });
      
      // Re-check subscription status for a clean reset
      _checkSubscriptionStatus();
    }
  }

  void _showPermissionDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  pickVideo(ImageSource src, BuildContext context) async {
    try {
      // Try to check permissions, but don't block if they fail
      try {
        await _checkPermissions(src);
      } catch (e) {
      }

      final ImagePicker picker = ImagePicker();
      final video = await picker.pickVideo(
        source: src,
        maxDuration: const Duration(seconds: 60),
      );

      // Close the dialog first if still mounted
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (video != null) {    
        try {
          // Read the video file as bytes to verify it's accessible
          final bytes = await video.readAsBytes();          
          if (bytes.isNotEmpty) {
            // Create a temporary file if needed
            final videoFile = File(video.path);
            
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ConfirmScreen(
                    videoFile: videoFile,
                    videoPath: video.path,
                  ),
                ),
              );
            }
          } else {
            if (mounted) {
              _showErrorDialog('Selected video is empty or corrupted.');
            }
          }
        } catch (fileError) {
          if (mounted) {
            _showErrorDialog('Cannot access the selected video. Please try another video.');
          }
        }
      } else {
        if (mounted) {
          _showErrorDialog('No video selected. Please try again.');
        }
      }
    } catch (e) {
      // Close the dialog if still open and mounted
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
      }      
      String errorMessage = 'Error selecting video.';
      if (e.toString().contains('no_valid_video_uri')) {
        errorMessage = 'Cannot access the selected video. This might be due to Android security restrictions. Please try:';
        errorMessage += '\n• Select a different video';
        errorMessage += '\n• Record a new video with the camera';
        errorMessage += '\n• Check if the video file is corrupted';
      }
      
      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    }
  }

//dialog options
  showOptionsDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        children: [
          SimpleDialogOption(
            onPressed: () => pickVideo(ImageSource.gallery, context),
            child: Row(
              children: const [
                Icon(Icons.image),
                Padding(
                  padding: EdgeInsets.all(7.0),
                  child: Text(
                    'Gallery',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => pickVideo(ImageSource.camera, context),
            child: Row(
              children: const [
                Icon(Icons.camera_alt),
                Padding(
                  padding: EdgeInsets.all(7.0),
                  child: Text(
                    'Camera',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: Row(
              children: const [
                Icon(Icons.cancel),
                Padding(
                  padding: EdgeInsets.all(7.0),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildAddVideoContent() {
    if (_isCheckingSubscription) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (!_hasActiveSubscription) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 
                     MediaQuery.of(context).padding.top -
                     MediaQuery.of(context).padding.bottom - 80, // Account for bottom nav
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                backgroundColor,
                Colors.grey[900]!,
                backgroundColor,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: secondaryColor,
              ),
              const SizedBox(height: 30),
              Text(
                'Subscription Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Get access to video uploads and all premium features!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => SubscriptionScreen()),
                ),
                child: Container(
                  width: 200,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [secondaryColor, secondaryColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: secondaryColor.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.black,
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Get Premium",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height - 
                   MediaQuery.of(context).padding.top -
                   MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundColor,
              Colors.grey[900]!,
              backgroundColor,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Welcome header section
            Container(
              padding: EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
              child: Column(
                children: [
                  Text(
                    "Create & Share",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: secondaryColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Your story matters",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            // Enhanced main content section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: 280,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey[800]!,
                      Colors.grey[700]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: secondaryColor.withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated SVG container
                    Container(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 120,
                              child: SvgPicture.asset(
                                'assets/video.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Share your favorite memories through video",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "Let the world experience your special moments!",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: secondaryColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quick tips section
                    Container(
                      margin: EdgeInsets.only(left: 30, right: 30, bottom: 20),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: secondaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: secondaryColor,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Tip: Videos up to 60 seconds get more engagement!",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[300],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),
            // Enhanced action section with proper spacing
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Main upload button with glow effect
                  GestureDetector(
                    onTap: () => showOptionsDialog(context),
                    child: Container(
                      width: 200,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [secondaryColor, secondaryColor.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: secondaryColor.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam,
                            color: Colors.black,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Start Creating",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Quick access buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickActionButton(
                        icon: Icons.camera_alt,
                        label: "Camera",
                        onTap: () => pickVideo(ImageSource.camera, context),
                      ),
                      _buildQuickActionButton(
                        icon: Icons.photo_library,
                        label: "Gallery",
                        onTap: () => pickVideo(ImageSource.gallery, context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bottom spacing with flexible expansion
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey[600]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: secondaryColor,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
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
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: _buildAddVideoContent(),
        ),
      ),
    );
  }
}
