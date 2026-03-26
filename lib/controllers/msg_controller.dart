import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:play_sphere/models/message.dart';
import 'package:play_sphere/models/messages.dart';
import '../models/chat_contact.dart';
import '../models/msg_room.dart';
import '../models/user.dart';
import '../constants.dart';
import 'package:uuid/uuid.dart';

class MessageController {
  // ✅ Get current user UID from the auth controller
  final _currentUserUid = authController.userData.uid;


  /// ✅ Fetches a stream of ChatContact objects for the current user
  Stream<List<ChatContact>> getChatContacts() {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // ✅ Return empty list if user is not authenticated
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('chats')
        .snapshots()
        .asyncMap((event) async {
      List<ChatContact> contacts = [];

      for (var document in event.docs) {
        if (!document.exists) continue;

        // ✅ Parse document into ChatContact model
        var chatContact = ChatContact.fromSnap(document);

        if (chatContact.contactId.isEmpty) continue;

        // ✅ Fetch user profile of contact
        var userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(chatContact.contactId)
            .get();

        if (!userData.exists) continue;

        var user = UserModel.fromSnap(userData);

        // ✅ Add formatted ChatContact
        contacts.add(ChatContact(
          name: user.name,
          profilePic: user.profilePhoto,
          contactId: chatContact.contactId,
        ));
      }

      return contacts;
    });
  }

  /// ✅ Fetches the chat messages stream between current user and a specific contact
  Stream<List<Messages>> getChatStream(String recieverUserId) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('chats')
        .doc(recieverUserId)
        .collection('messages')
        .orderBy('timeSent')
        .snapshots()
        .map((event) {
      List<Messages> messages = [];
      try {
        for (var document in event.docs) {
          if (!document.exists) continue;

          // ✅ Parse message document
          messages.add(Messages.fromSnap(document));
        }
      } catch (e) {
      }
      return messages;
    });
  }

  /// ✅ Saves the chat summary in both sender’s and receiver’s contact subcollections
  void _saveDataToContactsSubcollection(
    UserModel senderUserData,
    UserModel? recieverUserData,
    DateTime timeSent,
    String recieverUserId,
  ) async {
    // ✅ Save receiver's view of chat
    var recieverChatContact = ChatContact(
      name: senderUserData.name,
      profilePic: senderUserData.profilePhoto,
      contactId: senderUserData.uid,
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(recieverUserId)
        .collection('chats')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .set(recieverChatContact.toJson());

    // ✅ Save sender's view of chat
    var senderChatContact = ChatContact(
      name: recieverUserData!.name,
      profilePic: recieverUserData.profilePhoto,
      contactId: recieverUserData.uid,
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('chats')
        .doc(recieverUserId)
        .set(senderChatContact.toJson());
  }

  /// ✅ Saves message to the messages subcollection for both sender and receiver
  void _saveMessageToMessageSubcollection({
    required String recieverUserId,
    required String? recieverUserName,
    required String text,
    required DateTime timeSent,
    required String messageId,
    required String username,
    required String senderUsername,
  }) async {
    final message = Messages(
      senderId: FirebaseAuth.instance.currentUser!.uid,
      receiverId: recieverUserId,
      text: text,
      timeSent: timeSent,
      messageId: messageId,
    );

    // ✅ Save message for sender
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('chats')
        .doc(recieverUserId)
        .collection('messages')
        .doc(messageId)
        .set(message.toJson());

    // ✅ Save message for receiver
    await FirebaseFirestore.instance
        .collection('users')
        .doc(recieverUserId)
        .collection('chats')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('messages')
        .doc(messageId)
        .set(message.toJson());
  }

  /// ✅ Sends a text message between users
  void sendTextMessage({
    required String text,
    required String receiverUsedId,
    required String senderUserId,
  }) async {
    try {
      var timeSent = DateTime.now();

      // ✅ Fetch receiver and sender user models
      var userDataMap = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverUsedId)
          .get();
      var receiverUserData = UserModel.fromSnap(userDataMap);

      var senderDataMap = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderUserId)
          .get();
      var senderUserData = UserModel.fromSnap(senderDataMap);

      var messageId = const Uuid().v1();

      // ✅ Save contacts
      _saveDataToContactsSubcollection(
        senderUserData,
        receiverUserData,
        timeSent,
        receiverUsedId,
      );

      // ✅ Save message
      _saveMessageToMessageSubcollection(
        messageId: messageId,
        recieverUserName: receiverUserData.name,
        text: text,
        recieverUserId: receiverUsedId,
        senderUsername: senderUserData.name,
        timeSent: timeSent,
        username: senderUserData.name,
      );
    } catch (e) {
      Get.snackbar('Failed!', '${e.toString()}');
    }
  }
}
