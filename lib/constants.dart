import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:play_sphere/views/screens/subscription_wrapper.dart';
import 'package:play_sphere/views/screens/profile_screen.dart';
import 'package:play_sphere/views/screens/video_screen.dart';
import 'controllers/auth_controllers.dart';
import 'views/screens/gotomessage.dart';
import 'views/screens/search_screen.dart';

// Route observer to track screen navigation
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Global VideoScreen instance for home navigation (recreated each time)
VideoScreen? _globalVideoScreen;

VideoScreen get globalVideoScreen {
  // Always create a fresh instance to prevent state issues
  _globalVideoScreen = VideoScreen();
  return _globalVideoScreen!;
}

// Dynamic page generation to ensure proper user context and fresh instances
List getPages() {
  return [
    globalVideoScreen, // This will create a fresh instance
    SearchScreen(),
    SubscriptionWrapper(),
    GoToMsgScreen(),
    ProfileScreen(uid: firebaseAuth.currentUser?.uid ?? ''),
  ];
}

// For backward compatibility
List get pages => getPages();
// COLORS
const backgroundColor = Colors.black;
var buttonColor = Colors.white;
var secondaryColor = Colors.greenAccent;
const borderColor = Colors.grey;

//FIREBASE
var firebaseAuth = FirebaseAuth.instance;
var firebaseStorage = FirebaseStorage.instance;
var firestore = FirebaseFirestore.instance;

var authController = AuthController.instance;

// Default profile image URL
const String defaultProfileImageUrl = 'https://www.pngitem.com/pimgs/m/150-1503945_transparent-user-png-default-user-image-png-png.png';
