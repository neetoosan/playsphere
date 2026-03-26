//<--- functionality: preview the video, add song name and caption and upload button-->

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:play_sphere/controllers/upload_video_controller.dart';
import 'package:play_sphere/controllers/video_controller.dart';
import 'package:play_sphere/views/screens/add_video.dart';
import 'package:play_sphere/views/screens/home_screen.dart';
import 'package:play_sphere/views/widgets/text_input.dart';
import 'package:play_sphere/views/widgets/full_screen_loader.dart';
import 'package:video_player/video_player.dart';

class ConfirmScreen extends StatefulWidget {
  final File videoFile;
  final String videoPath;
  const ConfirmScreen({
    Key? key,
    required this.videoFile,
    required this.videoPath,
  }) : super(key: key);

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late VideoPlayerController controller;
  TextEditingController _songController = TextEditingController();
  TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;

  UploadVideoController uploadVideoController =
      Get.put(UploadVideoController());

  @override
  void initState() {
    super.initState();
    setState(() {
      controller = VideoPlayerController.file(widget.videoFile);
    });
    controller.initialize();
    controller.play();
    controller.setVolume(1);
    controller.setLooping(true);
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }
  
  /// Handle video upload with full-screen loading and feed refresh
  Future<void> _handleVideoUpload() async {
    // Validate caption
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a caption for your video'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    
    try {
      // Step 1: Upload the video
      String uploadResult = await uploadVideoController.uploadVideo(
        _songController.text,
        _captionController.text,
        widget.videoPath,
      );

      if (uploadResult == "success") {
        // Step 2: Navigate to home screen immediately
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
          
          // Step 3: Trigger feed refresh after navigation
          // The HomeScreen will handle showing the loading spinner during refresh
          uploadVideoController.refreshFeedAfterUpload();
        }
      } else {
        // Upload failed - show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $uploadResult'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Handle any errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 30,
            ),

            //video preview
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height / 1.4,
              child: VideoPlayer(controller),
            ),
            const SizedBox(
              height: 20,
            ),
            SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  //song name input
                  // Container(
                  //   margin: const EdgeInsets.symmetric(horizontal: 10),
                  //   width: MediaQuery.of(context).size.width - 20,
                  //   child: TextInputField(
                  //     controller: _songController,
                  //     labelText: 'Song Name',
                  //     icon: Icons.music_note,
                  //   ),
                  // ),
                  const SizedBox(
                    height: 10,
                  ),

                  //caption controller
                  Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: MediaQuery.of(context).size.width - 20,
                    child: TextInputField(
                      controller: _captionController,
                      labelText: 'Caption',
                      icon: Icons.closed_caption,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                      onPressed: _isUploading ? null : () => _handleVideoUpload(),
                      child: _isUploading 
                        ? Obx(() => Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      value: uploadVideoController.uploadProgress.value,
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    uploadVideoController.uploadStatus.value,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(uploadVideoController.uploadProgress.value * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ))
                        : const Text(
                            'Share!',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ))
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
