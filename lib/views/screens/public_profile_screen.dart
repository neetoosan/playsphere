import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants.dart';
import '../../controllers/profile_controller.dart';
import '../../models/user.dart';
import '../../views/screens/single_video_screen.dart';
import '../../views/widgets/subscription_badge.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  
  const PublicProfileScreen({Key? key, required this.userId}) : super(key: key);
  
  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late ProfileController profileController;
  
  @override
  void initState() {
    super.initState();
    profileController = Get.put(ProfileController());
    profileController.updateUserId(widget.userId);
  }
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            // Ensure smooth navigation back to previous screen
            Navigator.of(context).pop();
          },
        ),
        title: GetBuilder<ProfileController>(
          builder: (controller) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    controller.user.isNotEmpty ? controller.user['name'] ?? 'Profile' : 'Profile',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (controller.user.isNotEmpty)
                  ConditionalSubscriptionBadge(
                    userId: widget.userId,
                    size: 18.0,
                    margin: const EdgeInsets.only(left: 6.0),
                  ),
              ],
            );
          },
        ),
      ),
      body: GetBuilder<ProfileController>(
        builder: (controller) {
          if (controller.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          
          if (controller.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    controller.errorMessage,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          if (controller.user.isEmpty) {
            return const Center(
              child: Text(
                'User not found',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }
          
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    child: Column(
                      children: [
                        // Profile Picture
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipOval(
                              child: Image.network(
                                controller.user['profilePhoto'] ?? '',
                                fit: BoxFit.cover,
                                height: 100,
                                width: 100,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 100,
                                  width: 100,
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        
                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatColumn('Following', controller.user['following']),
                            Container(
                              color: Colors.black54,
                              width: 1,
                              height: 15,
                              margin: const EdgeInsets.symmetric(horizontal: 15),
                            ),
                            _buildStatColumn('Followers', controller.user['followers']),
                            Container(
                              color: Colors.black54,
                              width: 1,
                              height: 15,
                              margin: const EdgeInsets.symmetric(horizontal: 15),
                            ),
                            _buildStatColumn('Likes', controller.user['likes']),
                          ],
                        ),
                        const SizedBox(height: 15),
                        
                        // Follow Button (only show if not current user)
                        if (widget.userId != authController.userData?.uid)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: controller.followUser,
                                child: Container(
                                  alignment: Alignment.center,
                                  width: size.width / 3,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: secondaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    controller.user['isFollowing'] ? 'Unfollow' : 'Follow',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 15),
                        
                        // Divider
                        const Divider(thickness: 3),
                        
                        // Videos Grid or No Videos Message
                        (controller.user['thumbnails'] as List).isEmpty
                            ? const Column(
                                children: [
                                  SizedBox(height: 190),
                                  Text(
                                    "No videos to show",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              )
                            : Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: (controller.user['thumbnails'] as List).length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.7,
                                    crossAxisSpacing: 2,
                                    mainAxisSpacing: 2,
                                  ),
                                  itemBuilder: (context, index) {
                                    String thumbnail = (controller.user['thumbnails'] as List)[index];
                                    String videoId = (controller.user['videoIds'] as List)[index];
                                    
                                    return InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SingleVideoScreen(videoId: videoId),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            thumbnail,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[800],
                                                child: const Icon(
                                                  Icons.error,
                                                  color: Colors.white,
                                                  size: 30,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
