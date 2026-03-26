import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart' as modelUser;
import '../constants.dart';
import '../services/user_cleanup_service.dart';
import '../services/payment_service.dart';
import '../views/screens/home_screen.dart';
import '../views/screens/auth/login_screen.dart';
import '../views/screens/auth/email_verification_screen.dart';
import '../views/screens/plan_selection_screen.dart';

class AuthController extends GetxController {
  static AuthController instance = Get.find();

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Reactive Firebase user object
  late Rx<User?> _user;

  // Safely initialized image file pickers
  final Rx<File?> _pickedImage = Rx<File?>(null);
  final Rx<File?> _pickedEditImg = Rx<File?>(null);
  bool _isPicked = false;
  
  // Track if user just logged in to show success message
  bool _justLoggedIn = false;


  // Getters
  File? get profilePhoto => _pickedImage.value;
  File? get editPhoto => _pickedEditImg.value;
  bool get photoPicked => _isPicked;
  User get userData => _user.value!;

  @override
  void onReady() {
    super.onReady();
    _user = Rx<User?>(firebaseAuth.currentUser);
    _user.bindStream(firebaseAuth.authStateChanges());
    ever(_user, _setInitialScreen);
  }

  void _setInitialScreen(User? user) async {
    if (user == null) {
      Get.offAll(() => LoginScreen());
    } else {
      // Google users are automatically verified, so we check both email verification
      // and if the user was created via Google (which means they're verified)
      bool isVerified = user.emailVerified || 
          user.providerData.any((provider) => provider.providerId == 'google.com');
      
      if (isVerified) {
        // Check if user has active subscription or trial
        try {
          final PaymentService paymentService = Get.find<PaymentService>();
          final hasSubscription = await paymentService.hasActiveSubscription(user.uid);
          final hasTrial = await paymentService.hasActiveTrial(user.uid);
          
          if (hasSubscription || hasTrial) {
            // User has access, go to home screen
            Get.offAll(() => const HomeScreen());
            // Show login success message only if user just logged in
            if (_justLoggedIn) {
              Get.snackbar('Login Successful', 'Welcome back!');
              _justLoggedIn = false; // Reset the flag
            }
          } else {
            // User needs to select a plan
            Get.offAll(() => const PlanSelectionScreen());
            if (_justLoggedIn) {
              Get.snackbar('Welcome!', 'Please choose a plan to get started.');
              _justLoggedIn = false; // Reset the flag
            }
          }
        } catch (e) {
          // If payment service is not available, redirect to plan selection
          Get.offAll(() => const PlanSelectionScreen());
        }
      } else {
        Get.offAll(() => const EmailVerificationScreen());
      }
    }
  }

  Future<String> pickEditImg() async {
    String res = "Unsuccessful!";
    try {
      final pickedEditImg = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (pickedEditImg != null) {
        final File imageFile = File(pickedEditImg.path);
        
        // Validate file size (max 5MB)
        final int fileSizeInBytes = await imageFile.length();
        final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
        
        if (fileSizeInMB > 5) {
          Get.snackbar(
            'File Too Large', 
            'Please select an image smaller than 5MB. Current size: ${fileSizeInMB.toStringAsFixed(1)}MB',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return "file_too_large";
        }
        
        // Basic validation - ImagePicker already ensures it's an image file
        // We'll trust the system's image picker to provide valid image files
        
        _pickedEditImg.value = imageFile;
        _isPicked = true;
        res = "success";
        } else {
        Get.snackbar(
          'No Image Selected', 
          'Please select an image to continue',
          backgroundColor: Colors.grey,
          colorText: Colors.white,
        );
        return "no_image_selected";
      }
    } catch (e) {
      Get.snackbar(
        'Selection Error', 
        'Failed to select image. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return "selection_error";
    }
    return res;
  }

  void pickImage() async {
    try {
      final pickedImage = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedImage != null) {
        _pickedImage.value = File(pickedImage.path);
        Get.snackbar('Profile Picture', 'You have successfully selected your profile picture!');
      }
    } catch (e) {
      Get.snackbar('Profile Picture', 'Something went wrong! Try again!');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return; // User cancelled the sign-in
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken, accessToken: googleAuth.accessToken);

      UserCredential userCredential = await firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Check Firestore for existing user
        final userDoc = await firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          // If user doc doesn't exist, create a new one
          await firestore.collection('users').doc(user.uid).set({
            'name': user.displayName ?? 'User',
            'email': user.email,
            'profilePhoto': user.photoURL,
            'uid': user.uid,
            'creationTime': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }

      _justLoggedIn = true; // Flag for successful login
    } catch (e) {
      Get.snackbar('Google Sign-In Error', e.toString());
    }
  }


  Future<void> resetPassword(String email) async {
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
      Get.snackbar(
        'Password Reset Sent',
        'A reset link has been sent to $email',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'Reset Failed',
        e.toString(),
        snackPosition: SnackPosition.TOP,
      );
    }
  }


  Future<String> uploadToStorage(File image) async {
    Reference ref = firebaseStorage
        .ref()
        .child('profilePics')
        .child(firebaseAuth.currentUser!.uid);

    UploadTask uploadTask = ref.putFile(image);
    TaskSnapshot snap = await uploadTask;
    String downloadUrl = await snap.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<String> registerUser(
      String username, String email, String password, File? image) async {
    String res = "Some error occurred";
    try {
      // Validate required fields are filled
      if (username.isEmpty || email.isEmpty || password.isEmpty) {
        res = "Please fill all required fields";
        Get.snackbar('Missing Information', res);
        return res;
      }

      // Validate password length
      if (password.length < 8) {
        res = "Password must be at least 8 characters long";
        Get.snackbar('Weak Password', res);
        return res;
      }

      // Validate username length and format
      if (username.length < 3) {
        res = "Username must be at least 3 characters long";
        Get.snackbar('Invalid Username', res);
        return res;
      }

      // Check if username is available (using the cleanup service)
      final isUsernameAvailable = await UserCleanupService.isUsernameAvailable(username.trim());
      
      if (!isUsernameAvailable) {
        res = "Username '$username' is already taken. Please choose a different username.";
        Get.snackbar('Username Taken', res);
        return res;
      }

      // Create user account
      UserCredential cred = await firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Use default profile photo if no image is provided
      String downloadUrl;
      if (image != null) {
        downloadUrl = await uploadToStorage(image);
      } else {
        downloadUrl = defaultProfileImageUrl;
      }

      modelUser.UserModel user = modelUser.UserModel(
        name: username.trim(),
        email: email.trim(),
        uid: cred.user!.uid,
        profilePhoto: downloadUrl,
      );

      await firestore
          .collection('users')
          .doc(cred.user!.uid)
          .set(user.toJson());
      res = "success";
      // Success message will be shown after email verification
    } catch (e) {
      // Handle specific Firebase Auth errors
      if (e.toString().contains('email-already-in-use')) {
        res = "An account with this email already exists";
      } else if (e.toString().contains('weak-password')) {
        res = "Password is too weak. Please use at least 8 characters";
      } else if (e.toString().contains('invalid-email')) {
        res = "Please enter a valid email address";
      } else {
        res = "Registration failed: ${e.toString()}";
      }
      Get.snackbar('Registration Error', res);
    }
    return res;
  }

  void loginUser(String email, String password) async {
    try {
      // Validate fields
      if (email.isEmpty || password.isEmpty) {
        Get.snackbar('Missing Information', 'Please enter both email and password');
        return;
      }

      if (password.length < 8) {
        Get.snackbar('Invalid Password', 'Password must be at least 8 characters long');
        return;
      }

      await firebaseAuth.signInWithEmailAndPassword(email: email, password: password);

      await createUserDocumentIfNotExists();
      
      // Set flag to show login success message after auth state change
      _justLoggedIn = true;

      // Success message will be shown after email verification or directly if already verified
    } catch (e) {
      // Handle specific Firebase Auth errors
      String errorMessage = "Login failed";
      if (e.toString().contains('user-not-found')) {
        errorMessage = "No account found with this email address";
      } else if (e.toString().contains('wrong-password')) {
        errorMessage = "Incorrect password. Please try again";
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = "Please enter a valid email address";
      } else if (e.toString().contains('user-disabled')) {
        errorMessage = "This account has been disabled";
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = "Too many failed attempts. Please try again later";
      }
      Get.snackbar('Login Error', errorMessage);
    }
  }

  Future<void> createUserDocumentIfNotExists() async {
    try {
      final user = firebaseAuth.currentUser;
      if (user != null) {
        final userDoc = await firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          final userData = {
            'name': user.displayName ?? 'User',
            'email': user.email ?? '',
            'uid': user.uid,
            'profilePhoto': user.photoURL ?? defaultProfileImageUrl,
          };

          await firestore.collection('users').doc(user.uid).set(userData);        }
      }
    } catch (e) {
    }
  }

  void signOut() async {
    // Sign out from Google if user was signed in with Google
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
    await firebaseAuth.signOut();
  }

  // Get current user
  User? get currentUser => firebaseAuth.currentUser;

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        Get.snackbar(
          'Verification Email Sent',
          'Please check your email for the verification link.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to send verification email';
      
      if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Too many requests. Please wait before requesting another email.';
      }
      
      Get.snackbar(
        'Error',
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Check if email is verified
  Future<bool> checkEmailVerified() async {
    try {
      final user = firebaseAuth.currentUser;
      if (user != null) {
        await user.reload();
        final updatedUser = firebaseAuth.currentUser;
        if (updatedUser != null && updatedUser.emailVerified) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }


  // Delete user account and all associated data
  Future<String> deleteUserAccount(String password) async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) {
        return "No user is currently signed in";
      }

      // Re-authenticate the user before deletion (security requirement)
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      
      await user.reauthenticateWithCredential(credential);

      final uid = user.uid;
      // Clean up Firestore data first (backup cleanup)
      // The Cloud Function will also handle this, but we do it here as well
      try {
        await UserCleanupService.cleanupUserVideos(uid);
      } catch (e) {
        // Continue with account deletion even if cleanup fails
      }

      // Delete the Firebase Auth user (this will trigger the Cloud Function)
      await user.delete();
      
      Get.snackbar(
        'Account Deleted',
        'Your account and all associated data have been deleted.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
      return "success";
    } catch (e) {
      String errorMessage = "Failed to delete account";
      
      if (e.toString().contains('wrong-password')) {
        errorMessage = "Incorrect password. Please try again.";
      } else if (e.toString().contains('requires-recent-login')) {
        errorMessage = "Please sign out and sign in again before deleting your account.";
      } else if (e.toString().contains('network-request-failed')) {
        errorMessage = "Network error. Please check your connection and try again.";
      } else {
        errorMessage = "Failed to delete account: ${e.toString()}";
      }
      
      Get.snackbar(
        'Deletion Error',
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      
      return errorMessage;
    }
  }
}
