import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';

class UserCleanupService {
  // Check if a user still exists in Firebase Auth
  static Future<bool> doesUserExist(String uid) async {
    try {
      // For Firebase Auth, we can't directly check if a user exists from client side
      // So we'll use Firestore as the source of truth and periodically clean up
      final userDoc = await firestore.collection('users').doc(uid).get();
      return userDoc.exists;
    } catch (e) {
      return false;
    }
  }

  // Simple cleanup for deleted users (you'll handle manual deletion)
  static Future<void> cleanupUserVideos(String uid) async {
    try {      
      // Since you'll manually delete users, we just need to clean up basic references
      // This ensures the app doesn't break when trying to show deleted user content
      
      // Clean up user's followers and following collections
      await _cleanupUserRelations(uid);

    } catch (e) {
    }
  }

  // Clean up user's social relations
  static Future<void> _cleanupUserRelations(String uid) async {
    try {
      // Delete followers subcollection
      final followersQuery = await firestore
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();
      
      for (final doc in followersQuery.docs) {
        await doc.reference.delete();
      }

      // Delete following subcollection
      final followingQuery = await firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      
      for (final doc in followingQuery.docs) {
        await doc.reference.delete();
      }

      // Remove this user from other users' followers/following lists
      await _removeFromOtherUsersLists(uid);
    } catch (e) {
    }
  }

  // Remove deleted user from other users' followers/following lists
  static Future<void> _removeFromOtherUsersLists(String deletedUid) async {
    try {
      // Find all users who were following the deleted user
      final allUsersQuery = await firestore.collection('users').get();
      
      for (final userDoc in allUsersQuery.docs) {
        try {
          // Check if this user was following the deleted user
          final followingDoc = await firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('following')
              .doc(deletedUid)
              .get();
          
          if (followingDoc.exists) {
            await followingDoc.reference.delete();
          }

          // Check if the deleted user was following this user
          final followerDoc = await firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('followers')
              .doc(deletedUid)
              .get();
          
          if (followerDoc.exists) {
            await followerDoc.reference.delete();
          }
        } catch (e) {
        }
      }
    } catch (e) {
    }
  }

  // Clean up user's subscription data
  static Future<void> _cleanupUserSubscription(String uid) async {
    try {
      // Delete subscription document
      final subscriptionDoc = await firestore
          .collection('subscriptions')
          .doc(uid)
          .get();
      
      if (subscriptionDoc.exists) {
        await subscriptionDoc.reference.delete();
      }
    } catch (e) {
    }
  }

  // Clean up comments by this user from all videos
  static Future<void> _cleanupUserComments(String uid) async {
    try {
      // Get all videos to check for comments by this user
      final videosQuery = await firestore.collection('videos').get();
      
      for (final videoDoc in videosQuery.docs) {
        try {
          // Check comments subcollection for this video
          final commentsQuery = await firestore
              .collection('videos')
              .doc(videoDoc.id)
              .collection('comments')
              .where('uid', isEqualTo: uid)
              .get();
          
          // Delete all comments by this user
          for (final commentDoc in commentsQuery.docs) {
            await commentDoc.reference.delete();
          }
        } catch (e) {
        }
      }
    } catch (e) {
    }
  }

  // Clean up messages and chat rooms involving this user
  static Future<void> _cleanupUserMessages(String uid) async {
    try {
      // Clean up chat contacts where this user is involved
      final chatContactsQuery = await firestore
          .collection('users')
          .get();
      
      for (final userDoc in chatContactsQuery.docs) {
        try {
          // Check if this user has a chat contact with the deleted user
          final contactDoc = await firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('chats')
              .doc(uid)
              .get();
          
          if (contactDoc.exists) {
            await contactDoc.reference.delete();
          }
        } catch (e) {
        }
      }
      
      // Clean up message rooms where this user is a participant
      final messageRoomsQuery = await firestore
          .collection('messages')
          .where('participants', arrayContains: uid)
          .get();
      
      for (final roomDoc in messageRoomsQuery.docs) {
        try {
          // Get all messages in this room
          final messagesQuery = await firestore
              .collection('messages')
              .doc(roomDoc.id)
              .collection('chats')
              .get();
          
          // Delete all messages in the room
          for (final messageDoc in messagesQuery.docs) {
            await messageDoc.reference.delete();
          }
          
          // Delete the room itself
          await roomDoc.reference.delete();
        } catch (e) {
        }
      }
    } catch (e) {
    }
  }

  // Check if username is available (case-insensitive)
  static Future<bool> isUsernameAvailable(String username) async {
    try {
      // Get all users and check for case-insensitive matches
      final allUsersQuery = await firestore.collection('users').get();
      
      for (var doc in allUsersQuery.docs) {
        final userData = doc.data();
        final existingUsername = userData['name'] as String?;
        
        // Case-insensitive comparison
        if (existingUsername != null && 
            existingUsername.toLowerCase() == username.trim().toLowerCase()) {
          return false; // Username is taken
        }
      }
      
      return true; // Username is available
    } catch (e) {
      return false;
    }
  }

  // Validate user before showing their content
  static Future<bool> validateUserAndCleanup(String uid) async {
    try {
      // Check if user document exists in Firestore
      final userExists = await doesUserExist(uid);
      
      if (!userExists) {
        // User doesn't exist, clean up their content
        await cleanupUserVideos(uid);
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Validate and clean up user silently (for background processes)
  static Future<bool> validateUserSilently(String uid) async {
    try {
      final userDoc = await firestore.collection('users').doc(uid).get();
      return userDoc.exists;
    } catch (e) {
      return false;
    }
  }

  // Periodic cleanup function (can be called manually or scheduled)
  static Future<void> performSystemCleanup() async {
    try {      
      // Get all videos
      final videosQuery = await firestore.collection('videos').get();
      final videosToDelete = <String>[];
      
      // Check each video's user
      for (final videoDoc in videosQuery.docs) {
        final videoData = videoDoc.data();
        final uid = videoData['uid'] as String?;
        
        if (uid != null) {
          final userExists = await doesUserExist(uid);
          if (!userExists) {
            videosToDelete.add(videoDoc.id);
          }
        }
      }
      
      // Delete orphaned videos
      for (final videoId in videosToDelete) {
        await firestore.collection('videos').doc(videoId).delete();
      }
      
    } catch (e) {
    }
  }
}
