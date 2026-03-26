import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../models/user.dart';
import '../services/user_cleanup_service.dart';

class SearchController extends GetxController {
  final Rx<List<UserModel>> _searchedUsers = Rx<List<UserModel>>([]);

  List<UserModel> get searchedUsers => _searchedUsers.value;

  searchUser(String typedUser) async {
    final searchTerm = typedUser.trim().toLowerCase();
    
    // Get all users and filter client-side for case-insensitive search
    _searchedUsers.bindStream(firestore
        .collection('users')
        .snapshots()
        .asyncMap((QuerySnapshot query) async {
      List<UserModel> users = [];
      for (var element in query.docs) {
        try {
          final user = UserModel.fromSnap(element);
          
          // Validate user exists before checking name match
          final userExists = await UserCleanupService.validateUserAndCleanup(user.uid);
          if (userExists) {
            // Case-insensitive username comparison
            if (user.name.toLowerCase().contains(searchTerm)) {
              users.add(user);
            }
          }
        } catch (e) {
          // Continue with next user if there's an error
        }
      }
      return users;
    }));
  }

  // Clear all search results
  void clearSearch() {
    _searchedUsers.value = [];
  }

  // Remove individual user from search results
  void removeUser(String userId) {
    List<UserModel> currentUsers = List.from(_searchedUsers.value);
    currentUsers.removeWhere((user) => user.uid == userId);
    _searchedUsers.value = currentUsers;
  }
}
