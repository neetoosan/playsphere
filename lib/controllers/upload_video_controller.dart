//<-- functionality: task of uplaoding the video to Firestore  -->
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:play_sphere/constants.dart';
import 'package:video_compress/video_compress.dart';
import 'package:play_sphere/models/video.dart';
import 'video_controller.dart';

class UploadVideoController extends GetxController {
  // Observable for upload progress
  final RxDouble uploadProgress = 0.0.obs;
  final RxString uploadStatus = 'Preparing...'.obs;

//compress video function with optimized settings
  _compressVideo(String videoPath) async {
    uploadStatus.value = 'Compressing video...';
    final compressedVideo = await VideoCompress.compressVideo(
      videoPath,
      quality: VideoQuality.MediumQuality, // Medium quality for better video quality
      deleteOrigin: false, // Don't delete original
      includeAudio: true,
    );

    return compressedVideo!.file;
  }

//upload video to firebase storage function with progress tracking
  Future<String> _uploadVideoToStorage(String id, String videoPath) async {
    Reference ref = firebaseStorage.ref().child('videos').child(id);

    var compressedVideo = await _compressVideo(videoPath);
    
    uploadStatus.value = 'Uploading video...';
    UploadTask uploadTask = ref.putFile(compressedVideo);
    
    // Track upload progress
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      double progress = snapshot.bytesTransferred / snapshot.totalBytes;
      uploadProgress.value = progress * 0.8; // 80% for video upload
    });
    
    TaskSnapshot snap = await uploadTask;
    String downloadUrl = await snap.ref.getDownloadURL();
    return downloadUrl;
  }

  _getThumbnail(String videoPath) async {
    uploadStatus.value = 'Generating thumbnail...';
    final thumbnail = await VideoCompress.getFileThumbnail(videoPath);
    return thumbnail;
  }

  Future<String> _uploadImageToStorage(String id, String videoPath) async {
    Reference ref = firebaseStorage.ref().child('thumbnails').child(id);

    var thumbnail = await _getThumbnail(videoPath);
    
    uploadStatus.value = 'Uploading thumbnail...';
    UploadTask uploadTask = ref.putFile(thumbnail);
    
    // Track thumbnail upload progress
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      double progress = snapshot.bytesTransferred / snapshot.totalBytes;
      uploadProgress.value = 0.8 + (progress * 0.15); // 15% for thumbnail upload
    });
    
    TaskSnapshot snap = await uploadTask;
    String downloadUrl = await snap.ref.getDownloadURL();
    return downloadUrl;
  }

  
//upload the video
  Future<String> uploadVideo(
      String songName, String caption, String videoPath) async {
    String res = "Upload was unsuccessful, please try again later";
    try {
      String uid = firebaseAuth.currentUser!.uid;

      DocumentSnapshot userSnap =
          await firestore.collection('users').doc(uid).get();

      // Create a unique identifier using current timestamp
      String videoId = Timestamp.now().millisecondsSinceEpoch.toString();

      // Start uploads in parallel
      final videoUploadFuture = _uploadVideoToStorage(videoId, videoPath);
      final thumbnailUploadFuture = _uploadImageToStorage(videoId, videoPath);

      // Wait for parallel uploads to complete
      final results = await Future.wait([videoUploadFuture, thumbnailUploadFuture]);

      String videoUrl = results[0];
      String thumbnailUrl = results[1];

      // Make a video instance from video model
      Video video = Video(
          username: (userSnap.data() as Map<String, dynamic>)['name'],
          uid: uid,
          id: videoId,
          likes: [],
          commentCount: 0,
          shareCount: 0,
          viewCount: 0, // Initialize with 0 views for new videos
          viewHistory: <String, dynamic>{}, // Initialize empty view history
          caption: caption,
          videoUrl: videoUrl,
          profilePhoto: (userSnap.data() as Map<String, dynamic>)['profilePhoto'],
          thumbnail: thumbnailUrl,
          uploadTimestamp: Timestamp.now());

      // Store video in firestore
      await firestore
          .collection('videos')
          .doc(videoId)
          .set(video.toJson());

      res = "success";
    } catch (e) {
      res = "Unsuccessful";
    }
    return res;
  }
  
  /// Refresh the video feed after successful upload with enhanced synchronization
  Future<void> refreshFeedAfterUpload() async {
    try {
      uploadStatus.value = 'Refreshing feed...';
      uploadProgress.value = 0.95; // 95% progress
      
      // Wait a moment to ensure Firestore has propagated the new video
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Get the video controller and refresh the feed
      final videoController = Get.find<VideoController>();
      
      // Force a complete refresh to ensure new video appears with correct metadata
      await videoController.refreshVideoFeedWithSync();
      
      uploadProgress.value = 1.0; // 100% complete
      uploadStatus.value = 'Complete!';
      
    } catch (e) {
      // Fallback to regular refresh if enhanced sync fails
      try {
        final videoController = Get.find<VideoController>();
        await videoController.refreshVideoFeed();
      } catch (fallbackError) {
      }
    }
  }
}
