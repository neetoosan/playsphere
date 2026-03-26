import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants.dart';
import '../../controllers/comment_controller.dart';
import '../widgets/subscription_badge.dart';
import 'profile_screen.dart';
import '../../services/user_cleanup_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentScreen extends StatelessWidget {
  final String id;
  const CommentScreen({super.key, required this.id});

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      if (authController.userData != null) {
        final userDoc = await firestore
            .collection('users')
            .doc(authController.userData!.uid)
            .get();
        if (userDoc.exists) {
          return userDoc.data();
        }
      }
    } catch (e) {
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController _commentController = TextEditingController();
    CommentController commentController = Get.put(CommentController());

    commentController.updatePostId(id);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Obx(() => Text(
          '${commentController.comments.length} Comments',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        )),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Comments list
          Expanded(
            child: Obx(() {
              if (commentController.comments.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Be the first to comment',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                itemCount: commentController.comments.length,
                itemBuilder: (context, index) {
                  final comment = commentController.comments[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User avatar - tappable to navigate to profile
                        InkWell(
                          onTap: () async {
                            // Validate user exists before navigating
                            final userExists = await UserCleanupService.validateUserAndCleanup(comment.uid);
                            if (userExists) {
                              // Navigate using consistent Get.to() pattern used throughout the app
                              Get.to(() => ProfileScreen(uid: comment.uid));
                            } else {
                              Get.snackbar(
                                'User Not Found',
                                'This user account no longer exists.',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                                margin: const EdgeInsets.all(16),
                                duration: const Duration(seconds: 3),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(20), // Match the circular avatar
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: NetworkImage(comment.profilePhoto),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Comment content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Username and comment text
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          WidgetSpan(
                                            child: InkWell(
                                              onTap: () async {
                                                // Validate user exists before navigating
                                                final userExists = await UserCleanupService.validateUserAndCleanup(comment.uid);
                                                if (userExists) {
                                                  // Navigate using consistent Get.to() pattern used throughout the app
                                                  Get.to(() => ProfileScreen(uid: comment.uid));
                                                } else {
                                                  Get.snackbar(
                                                    'User Not Found',
                                                    'This user account no longer exists.',
                                                    snackPosition: SnackPosition.TOP,
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                    margin: const EdgeInsets.all(16),
                                                    duration: const Duration(seconds: 3),
                                                  );
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(4),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                                    child: Text(
                                                      comment.username,
                                                      style: TextStyle(
                                                        color: secondaryColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        decoration: TextDecoration.underline,
                                                        decorationColor: secondaryColor.withOpacity(0.7),
                                                        decorationThickness: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                  ConditionalSubscriptionBadge(
                                                    userId: comment.uid,
                                                    size: 14.0,
                                                    margin: const EdgeInsets.only(left: 4.0),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' ${comment.comment}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Time and likes info
                              Row(
                                children: [
                                  Text(
                                    timeago.format(comment.datePublished.toDate()),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '${comment.likes.length} likes',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Like button
                        InkWell(
                          onTap: () => commentController.likeComment(comment.id),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.favorite,
                              color: comment.likes.contains(authController.userData?.uid)
                                  ? Colors.red
                                  : Colors.grey,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
          // Comment input section
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(
                top: BorderSide(color: Colors.grey[800]!, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Current user avatar
                FutureBuilder<Map<String, dynamic>?>(
                  future: getCurrentUserData(),
                  builder: (context, snapshot) {
                    String? profilePhoto;
                    if (snapshot.hasData && snapshot.data != null) {
                      profilePhoto = snapshot.data!['profilePhoto'];
                    }
                    
                    return CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[700],
                      backgroundImage: profilePhoto != null
                          ? NetworkImage(profilePhoto)
                          : null,
                      child: profilePhoto == null
                          ? const Icon(Icons.person, color: Colors.white, size: 20)
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 12),
                // Comment input field
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.black,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final commentText = _commentController.text.trim();
                      
                      // Validation checks
                      if (authController.userData == null) {
                        Get.snackbar(
                          'Authentication Required',
                          'Please log in to comment on videos.',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(16),
                        );
                        return;
                      }
                      
                      if (commentText.isEmpty) {
                        Get.snackbar(
                          'Invalid Input',
                          'Comment cannot be empty.',
                          backgroundColor: Colors.orange,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(16),
                        );
                        return;
                      }
                      
                      try {
                        await commentController.postComment(commentText);
                        _commentController.clear();
                      } catch (e) {
                        Get.snackbar(
                          'Error',
                          'Failed to post comment. Please try again.',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(16),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.send,
                        color: secondaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
