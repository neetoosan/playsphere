import 'package:cloud_firestore/cloud_firestore.dart';

class Video {
  String username;
  String uid;
  String id;
  List likes;
  int commentCount;
  int shareCount;
  int viewCount;
  Map<String, dynamic> viewHistory; // Track user view history with timestamps
  String caption;
  String videoUrl;
  String thumbnail;
  String profilePhoto;
  Timestamp uploadTimestamp; // Track when the video was uploaded

  Video({
    required this.username,
    required this.uid,
    required this.id,
    required this.likes,
    required this.commentCount,
    required this.shareCount,
    required this.viewCount,
    required this.viewHistory,
    required this.caption,
    required this.videoUrl,
    required this.profilePhoto,
    required this.thumbnail,
    required this.uploadTimestamp,
  });

  Map<String, dynamic> toJson() => {
        "username": username,
        "uid": uid,
        "profilePhoto": profilePhoto,
        "id": id,
        "likes": likes,
        "commentCount": commentCount,
        "shareCount": shareCount,
        "viewCount": viewCount,
        "viewHistory": viewHistory,
        "caption": caption,
        "videoUrl": videoUrl,
        "thumbnail": thumbnail,
        "uploadTimestamp": uploadTimestamp,
      };

  static Video fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;

    return Video(
      username: snapshot['username'],
      uid: snapshot['uid'],
      id: snapshot['id'],
      likes: snapshot['likes'],
      commentCount: snapshot['commentCount'],
      shareCount: snapshot['shareCount'],
      viewCount: snapshot['viewCount'] ?? 0, // Default to 0 for existing videos
      viewHistory: Map<String, dynamic>.from(snapshot['viewHistory'] ?? {}), // Track user view history
      caption: snapshot['caption'],
      videoUrl: snapshot['videoUrl'],
      profilePhoto: snapshot['profilePhoto'],
      thumbnail: snapshot['thumbnail'],
      uploadTimestamp: snapshot['uploadTimestamp'] ?? Timestamp.fromMillisecondsSinceEpoch(0), // Default to epoch for old videos
    );
  }
}
