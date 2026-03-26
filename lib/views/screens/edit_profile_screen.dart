// ignore_for_file: prefer_final_fields

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../screens/profile_screen.dart';
import '../screens/home_screen.dart';
import '../../constants.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/video_controller.dart';
import '../../controllers/comment_controller.dart';
import '../../services/user_cleanup_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileController profileController = Get.put(ProfileController());

  // ignore: prefer_final_fields
  late TextEditingController _nameController =
      TextEditingController(text: profileController.user['name']);
  late TextEditingController _emailController =
      TextEditingController(text: profileController.user['email']);
  //current user uid
  final uid = authController.userData.uid;

  bool _isPhotoChanged = false;
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    profileController.updateUserId(uid);
  }

  // Update all videos by this user to reflect new username
  Future<void> _updateUserVideos(String uid, String newName) async {
    try {
      final videosQuery = await firestore
          .collection('videos')
          .where('uid', isEqualTo: uid)
          .get();
      
      // Use multiple batches if needed (Firestore batch limit is 500)
      final List<WriteBatch> batches = [];
      WriteBatch currentBatch = firestore.batch();
      int operationCount = 0;
      
      for (var doc in videosQuery.docs) {
        if (operationCount == 500) {
          batches.add(currentBatch);
          currentBatch = firestore.batch();
          operationCount = 0;
        }
        currentBatch.update(doc.reference, {'username': newName});
        operationCount++;
      }
      
      if (operationCount > 0) {
        batches.add(currentBatch);
      }
      
      // Commit all batches
      for (var batch in batches) {
        await batch.commit();
      }
      
    } catch (e) {
      throw e; // Re-throw to handle in main function
    }
  }
  
  // Update all comments by this user across all videos
  Future<void> _updateUserComments(String uid, String newName) async {
    try {
      // Get all videos to update comments within them
      final videosQuery = await firestore.collection('videos').get();
      
      final List<WriteBatch> batches = [];
      WriteBatch currentBatch = firestore.batch();
      int operationCount = 0;
      int updatedComments = 0;
      
      for (var videoDoc in videosQuery.docs) {
        final commentsQuery = await firestore
            .collection('videos')
            .doc(videoDoc.id)
            .collection('comments')
            .where('uid', isEqualTo: uid)
            .get();
        
        for (var commentDoc in commentsQuery.docs) {
          if (operationCount == 500) {
            batches.add(currentBatch);
            currentBatch = firestore.batch();
            operationCount = 0;
          }
          currentBatch.update(commentDoc.reference, {'username': newName});
          operationCount++;
          updatedComments++;
        }
      }
      
      if (operationCount > 0) {
        batches.add(currentBatch);
      }
      
      // Commit all batches
      for (var batch in batches) {
        await batch.commit();
      }
      
    } catch (e) {
      throw e; // Re-throw to handle in main function
    }
  }
  
  // Update withdrawal requests with new username for admin reference
  Future<void> _updateWithdrawalRequests(String uid, String newName) async {
    try {
      final withdrawalQuery = await firestore
          .collection('withdrawal_requests')
          .where('userId', isEqualTo: uid)
          .get();
      
      if (withdrawalQuery.docs.isEmpty) {
        return;
      }
      
      final List<WriteBatch> batches = [];
      WriteBatch currentBatch = firestore.batch();
      int operationCount = 0;
      
      for (var doc in withdrawalQuery.docs) {
        if (operationCount == 500) {
          batches.add(currentBatch);
          currentBatch = firestore.batch();
          operationCount = 0;
        }
        // Add username field for admin reference if not exists
        currentBatch.update(doc.reference, {'username': newName});
        operationCount++;
      }
      
      if (operationCount > 0) {
        batches.add(currentBatch);
      }
      
      // Commit all batches
      for (var batch in batches) {
        await batch.commit();
      }
      
    } catch (e) {
      throw e; // Re-throw to handle in main function
    }
  }
  
  // Update chat contacts where this user appears
  Future<void> _updateChatContacts(String uid, String newName) async {
    try {
      // Find all chat_contacts documents where this user is referenced
      final chatContactsQuery = await firestore
          .collection('chat_contacts')
          .where('contactId', isEqualTo: uid)
          .get();
      
      if (chatContactsQuery.docs.isEmpty) {
        return;
      }
      
      final List<WriteBatch> batches = [];
      WriteBatch currentBatch = firestore.batch();
      int operationCount = 0;
      
      for (var doc in chatContactsQuery.docs) {
        if (operationCount == 500) {
          batches.add(currentBatch);
          currentBatch = firestore.batch();
          operationCount = 0;
        }
        currentBatch.update(doc.reference, {'name': newName});
        operationCount++;
      }
      
      if (operationCount > 0) {
        batches.add(currentBatch);
      }
      
      // Commit all batches
      for (var batch in batches) {
        await batch.commit();
      }
      
    } catch (e) {
      throw e; // Re-throw to handle in main function
    }
  }
  
  // Update subscription documents if they store username
  Future<void> _updateSubscriptions(String uid, String newName) async {
    try {
      final subscriptionDoc = await firestore
          .collection('subscriptions')
          .doc(uid)
          .get();
      
      if (subscriptionDoc.exists) {
        await firestore
            .collection('subscriptions')
            .doc(uid)
            .update({'username': newName});
      } else {
      }
    } catch (e) {
      // Don't throw here as subscription might not have username field
    }
  }
  
  // Comprehensive username update across all collections
  Future<void> _updateUsernameAcrossCollections(String uid, String newName) async {    
    // Update all collections in parallel for better performance
    final List<Future> updateFutures = [
      _updateUserVideos(uid, newName),
      _updateUserComments(uid, newName),
      _updateWithdrawalRequests(uid, newName),
      _updateChatContacts(uid, newName),
      _updateSubscriptions(uid, newName),
    ];
    
    // Wait for all updates to complete
    try {
      await Future.wait(updateFutures);
    } catch (e) {
      throw e;
    }
  }
  
  // Update profile picture across all collections
  Future<void> _updateProfilePhotoAcrossCollections(String uid, String newProfilePhotoUrl) async {    
    try {
      // Update videos posted by this user
      final videosQuery = await firestore
          .collection('videos')
          .where('uid', isEqualTo: uid)
          .get();
      
      final List<WriteBatch> batches = [];
      WriteBatch currentBatch = firestore.batch();
      int operationCount = 0;
      
      // Update profile photo in all videos
      for (var doc in videosQuery.docs) {
        if (operationCount == 500) {
          batches.add(currentBatch);
          currentBatch = firestore.batch();
          operationCount = 0;
        }
        currentBatch.update(doc.reference, {'profilePhoto': newProfilePhotoUrl});
        operationCount++;
      }
      
      // Update comments by this user across all videos
      final allVideosQuery = await firestore.collection('videos').get();
      int updatedComments = 0;
      
      for (var videoDoc in allVideosQuery.docs) {
        final commentsQuery = await firestore
            .collection('videos')
            .doc(videoDoc.id)
            .collection('comments')
            .where('uid', isEqualTo: uid)
            .get();
        
        for (var commentDoc in commentsQuery.docs) {
          if (operationCount == 500) {
            batches.add(currentBatch);
            currentBatch = firestore.batch();
            operationCount = 0;
          }
          currentBatch.update(commentDoc.reference, {'profilePhoto': newProfilePhotoUrl});
          operationCount++;
          updatedComments++;
        }
      }
      
      // Update chat contacts where this user appears
      final chatContactsQuery = await firestore
          .collection('chat_contacts')
          .where('contactId', isEqualTo: uid)
          .get();
      
      for (var doc in chatContactsQuery.docs) {
        if (operationCount == 500) {
          batches.add(currentBatch);
          currentBatch = firestore.batch();
          operationCount = 0;
        }
        currentBatch.update(doc.reference, {'profilePic': newProfilePhotoUrl});
        operationCount++;
      }
      
      if (operationCount > 0) {
        batches.add(currentBatch);
      }
      
      // Commit all batches
      for (var batch in batches) {
        await batch.commit();
      }
      
    } catch (e) {
      throw e;
    }
  }
  
  // Refresh profile controller specifically
  Future<void> _refreshProfileController() async {
    try {
      final profileController = Get.find<ProfileController>();
      await profileController.refreshProfile();
    } catch (e) {
    }
  }
  
  // Force refresh all controllers to pick up changes
  Future<void> _refreshAllControllers() async {
    try {
      // Refresh profile controller
      final profileController = Get.find<ProfileController>();
      profileController.updateUserId(uid);
      
      // Refresh video controller if it exists
      try {
        final videoController = Get.find<VideoController>();
        await videoController.refreshVideoFeed();
      } catch (e) {
      }
      
    } catch (e) {
    }
  }

  //onsave function
  void profileOnSave() async {
    try {
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();
      final oldName = profileController.user['name'];
      
      // Validate input
      if (newName.isEmpty || newEmail.isEmpty) {
        Get.snackbar('Error', 'Name and email cannot be empty',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // Validate username length and format
      if (newName.length < 3) {
        Get.snackbar('Invalid Username', 'Username must be at least 3 characters long',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // Check if username actually changed to avoid unnecessary updates
      final usernameChanged = newName != oldName;
      
      // If username changed, check if the new username is available
      if (usernameChanged) {
        // Show loading indicator specifically for username validation
        Get.dialog(
          WillPopScope(
            onWillPop: () async => false,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Checking username availability...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          barrierDismissible: false,
        );
        
        try {
          // Check if the new username is already taken by another user (case-insensitive)
          // Get all users and check for case-insensitive matches
          final allUsersQuery = await firestore.collection('users').get();
          
          bool isUsernameTaken = false;
          for (var doc in allUsersQuery.docs) {
            final userData = doc.data();
            final existingUsername = userData['name'] as String?;
            
            // Case-insensitive comparison, excluding current user
            if (existingUsername != null && 
                existingUsername.toLowerCase() == newName.toLowerCase() &&
                doc.id != uid) {
              isUsernameTaken = true;
              break;
            }
          }
          
          Get.back(); // Close username validation loading dialog
          
          if (isUsernameTaken) {
            Get.snackbar(
              'Username Taken', 
              'This username is already taken. Please choose another one.',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 4),
              snackPosition: SnackPosition.TOP,
            );
            return;
          }
        } catch (e) {
          Get.back(); // Close username validation loading dialog
          Get.snackbar(
            'Validation Error',
            'Failed to validate username. Please try again.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          return;
        }
      }
    
      // Show enhanced loading indicator with progress
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false, // Prevent dismissing during update
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Updating profile across all data...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'This may take a moment',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );
      
      // Update user document in Firestore first
      await firestore.collection('users').doc(uid).update({
        'name': newName,
        'email': newEmail,
      });
      
      // Only update across collections if username actually changed
      if (usernameChanged) {
        await _updateUsernameAcrossCollections(uid, newName);
      } else {
      }
      
      // Force refresh all controllers to pick up the changes
      await _refreshAllControllers();
      
      Get.back(); // Close loading dialog
      
      // Navigate back to HomeScreen to show the profile with bottom navigation
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 4)),
          (route) => false);

      // Show success message with details
      final message = usernameChanged 
          ? 'Profile updated! Username changed across all your content.'
          : 'Profile updated successfully!';
      
      Get.snackbar('Profile Updated!', message,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      
    } catch (e) {
      Get.back(); // Close loading dialog      
      // Show detailed error message
      Get.snackbar(
        'Update Failed', 
        'Failed to update profile: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

  void changeProfilePhoto() async {
    try {
      // Show loading dialog with progress indicator
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false, // Prevent dismissing during update
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Updating profile picture...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'This may take a moment',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );
      
      // Upload new profile picture to Firebase Storage
      String newProfilePhotoUrl = await authController.uploadToStorage(authController.editPhoto!);
      
      // Update user document in Firestore
      await firestore
          .collection('users')
          .doc(authController.userData.uid)
          .update({'profilePhoto': newProfilePhotoUrl});
      
      // Update profile picture across all collections
      await _updateProfilePhotoAcrossCollections(uid, newProfilePhotoUrl);
      
      // Update the profile controller with the new photo URL immediately
      profileController.updateProfilePhoto(newProfilePhotoUrl);
      
      // Clear the cached network image to force refresh
      try {
        await CachedNetworkImage.evictFromCache(profileController.user['profilePhoto']);
        await CachedNetworkImage.evictFromCache(newProfilePhotoUrl);
      } catch (e) {
      }
      
      // Force refresh profile controller to get the latest data
      await _refreshProfileController();
      
      // Reset photo changed state and clear selected image
      setState(() {
        _isPhotoChanged = false;
        _selectedImagePath = null;
      });
      
      Get.back(); // Close loading dialog
      
      // Show success message
      Get.snackbar(
        "Photo Updated!", 
        "Your profile picture has been updated everywhere in the app!",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      
    } catch (e) {
      Get.back(); // Close loading dialog      
      // Reset photo changed state on error and clear selected image
      setState(() {
        _isPhotoChanged = false;
        _selectedImagePath = null;
      });
      
      // Show error message
      Get.snackbar(
        'Update Failed', 
        'Failed to update profile picture: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

    return GetBuilder<ProfileController>(
        init: ProfileController(),
        builder: (controller) {
          if (controller.user.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.black,
                leading: IconButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 4)),
                          (route) => false);
                    },
                    icon: const Icon(Icons.arrow_back_ios)),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: InkWell(
                      //on save function
                      onTap: () {
                        profileOnSave();
                      },
                      child: const Text("Save",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueAccent,
                          )),
                    ),
                  ),
                ],
                title: Text(
                  controller.user['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                    child: Column(
                  children: [
                    //profile pic
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipOval(
                          child: _isPhotoChanged && _selectedImagePath != null
                              ? Image.file(
                                  File(_selectedImagePath!),
                                  fit: BoxFit.cover,
                                  height: 100,
                                  width: 100,
                                )
                              : CachedNetworkImage(
                                  fit: BoxFit.cover,
                                  imageUrl: controller.user['profilePhoto'],
                                  height: 100,
                                  width: 100,
                                  placeholder: (context, url) =>
                                      const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) => const Icon(
                                    Icons.error,
                                  ),
                                  // Add cache key with timestamp to force refresh
                                  cacheKey: '${controller.user['profilePhoto']}_${DateTime.now().millisecondsSinceEpoch}',
                                ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    Center(
                        child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isPhotoChanged != true
                            ? Container(
                                width: 35,
                                height: 35,
                                decoration: const BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(9))),
                                child: InkWell(
                                    onTap: () async {
                                      String res =
                                          await authController.pickEditImg();
                                      if (res == "success" && authController.editPhoto != null) {
                                        setState(() {
                                          _isPhotoChanged = true;
                                          _selectedImagePath = authController.editPhoto!.path;
                                        });
                                        // Show success message
                                        Get.snackbar(
                                          'Image Selected',
                                          'Tap "Save New Profile Photo" to upload',
                                          backgroundColor: Colors.blue,
                                          colorText: Colors.white,
                                        );
                                      }
                                    },
                                    child: const Icon(
                                      Icons.upload,
                                      color: Colors.black,
                                    )))
                            : Container(),
                        const SizedBox(width: 9),
                        (_isPhotoChanged == true)
                            ? InkWell(
                                onTap: () => changeProfilePhoto(),
                                child: const Text("Save New Profile Photo",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    )))
                            : InkWell(
                                onTap: () async {
                                  String res = await authController.pickEditImg();
                                  if (res == "success" && authController.editPhoto != null) {
                                    setState(() {
                                      _isPhotoChanged = true;
                                      _selectedImagePath = authController.editPhoto!.path;
                                    });
                                    // Show success message
                                    Get.snackbar(
                                      'Image Selected',
                                      'Tap "Save New Profile Photo" to upload',
                                      backgroundColor: Colors.blue,
                                      colorText: Colors.white,
                                    );
                                  }
                                },
                                child: const Text("Update Profile Photo",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue,
                                    )))
                      ],
                    )),

                    const SizedBox(height: 20),

                    //text fields
                    Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Username',
                                helperText: 'Username must be unique and at least 3 characters',
                                helperStyle: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 20),
                            //email
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Email',
                              ),
                            ),
                          ],
                        ))
                  ],
                )),
              ));
        });
  }
}
