import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../models/comment.dart';

class CommentController extends GetxController {
  final Rx<List<Comment>> _comments = Rx<List<Comment>>([]);
  List<Comment> get comments => _comments.value;

  String _postId = "";

  updatePostId(String id) {
    // Clear existing comments when switching to a new video
    if (_postId != id) {
      _comments.value = [];
    }
    _postId = id;
    getComment();
  }

  getComment() async {
    _comments.bindStream(
      firestore
          .collection('videos')
          .doc(_postId)
          .collection('comments')
          .snapshots()
          .map(
        (QuerySnapshot query) {
          List<Comment> retValue = [];
          for (var element in query.docs) {
            retValue.add(Comment.fromSnap(element));
          }
          return retValue;
        },
      ),
    );
  }

  postComment(String commentText) async {
    try {
      if (commentText.isNotEmpty) {
        DocumentSnapshot userDoc = await firestore
            .collection('users')
            .doc(authController.userData!.uid)
            .get();
        var allDocs = await firestore
            .collection('videos')
            .doc(_postId)
            .collection('comments')
            .get();
        int len = allDocs.docs.length;

        String commentDocId = 'comment $len';
        Comment comment = Comment(
          username: (userDoc.data()! as dynamic)['name'],
          comment: commentText.trim(),
          datePublished: DateTime.now(),
          likes: [],
          profilePhoto: (userDoc.data()! as dynamic)['profilePhoto'],
          uid: authController.userData!.uid,
          id: commentDocId,  // Use the document ID
        );
        await firestore
            .collection('videos')
            .doc(_postId)
            .collection('comments')
            .doc(commentDocId)
            .set(
              comment.toJson(),
            );
        DocumentSnapshot doc =
            await firestore.collection('videos').doc(_postId).get();
        await firestore.collection('videos').doc(_postId).update({
          'commentCount': (doc.data()! as dynamic)['commentCount'] + 1,
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error While Commenting',
        e.toString(),
      );
    }
  }

  likeComment(String commentId) async {
    try {
      // Check if user is authenticated
      if (authController.userData == null) {
        Get.snackbar('Error', 'User not authenticated');
        return;
      }
      
      var uid = authController.userData!.uid;
      
      // Validate postId
      if (_postId.isEmpty) {
        Get.snackbar('Error', 'Invalid post ID');
        return;
      }
            
      // First, try to find the comment document
      // The comment ID stored in the comment object might not match the document ID
      var commentsQuery = await firestore
          .collection('videos')
          .doc(_postId)
          .collection('comments')
          .get();
      
      String? actualDocId;
      
      // Find the actual document that contains this comment ID
      for (var doc in commentsQuery.docs) {
        var data = doc.data();
        if (data['id'] == commentId) {
          actualDocId = doc.id;
          break;
        }
      }
      
      if (actualDocId == null) {
        Get.snackbar('Error', 'Comment not found');
        return;
      }
            
      DocumentSnapshot doc = await firestore
          .collection('videos')
          .doc(_postId)
          .collection('comments')
          .doc(actualDocId)
          .get();

      var docData = doc.data() as Map<String, dynamic>?;
      if (docData == null) {
        Get.snackbar('Error', 'Comment data is invalid');
        return;
      }
      
      List<dynamic> likes = docData['likes'] ?? [];

      // Toggle like status
      if (likes.contains(uid)) {
        // Remove like
        await firestore
            .collection('videos')
            .doc(_postId)
            .collection('comments')
            .doc(actualDocId)
            .update({
          'likes': FieldValue.arrayRemove([uid]),
        });
      } else {
        // Add like
        await firestore
            .collection('videos')
            .doc(_postId)
            .collection('comments')
            .doc(actualDocId)
            .update({
          'likes': FieldValue.arrayUnion([uid]),
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to like comment. Please try again.');
    }
  }
}
