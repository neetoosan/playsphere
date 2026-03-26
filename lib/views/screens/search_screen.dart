import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../controllers/search_controller.dart' as my_search;
import 'package:get/get.dart';
import 'package:play_sphere/views/screens/profile_screen.dart';
import '../../models/user.dart';
import 'home_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SearchScreen extends StatefulWidget {
  SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  late final my_search.SearchController searchController;
  final TextEditingController _textController = TextEditingController();
  late AnimationController _fadeAnimationController;
  late AnimationController _searchIconAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _searchIconScaleAnimation;
  late Animation<double> _searchIconGlowAnimation;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _searchIconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    // Setup fade animation with delayed start
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    ));
    
    // Setup search icon animations
    _searchIconScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _searchIconAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _searchIconGlowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchIconAnimationController,
      curve: Curves.easeOut,
    ));
    
    // Setup focus node listener for search icon animation
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        _searchIconAnimationController.forward().then((_) {
          _searchIconAnimationController.reverse();
        });
      }
    });
    
    // Get existing controller or create new one if it doesn't exist
    // This ensures search results persist across navigation
    try {
      searchController = Get.find<my_search.SearchController>();
    } catch (e) {
      searchController = Get.put(my_search.SearchController());
    }
    
    // Only clear text field when screen is initialized, preserve search results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textController.clear();
      // Start fade animation after 300ms delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _fadeAnimationController.forward();
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Clear text field when returning to this screen
    // Search results remain intact in the controller
    _textController.clear();
  }

  @override
  void dispose() {
    _textController.dispose();
    _fadeAnimationController.dispose();
    _searchIconAnimationController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void clearSeachScreen() {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => HomeScreen()));
    }

    var height = AppBar().preferredSize.height;
    return Obx(() {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => clearSeachScreen()),
          leadingWidth: 35,
          backgroundColor: Colors.black,
          title: Container(
            height: height / 1.4,
            // color: Colors.white,
            decoration: BoxDecoration(
              color: Colors.grey[500]?.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _searchIconScaleAnimation,
                      _searchIconGlowAnimation,
                    ]),
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          boxShadow: _searchIconGlowAnimation.value > 0
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent
                                        .withOpacity(_searchIconGlowAnimation.value * 0.5),
                                    blurRadius: 8.0 * _searchIconGlowAnimation.value,
                                    spreadRadius: 2.0 * _searchIconGlowAnimation.value,
                                  ),
                                ]
                              : null,
                        ),
                        child: Transform.scale(
                          scale: _searchIconScaleAnimation.value,
                          child: const Icon(
                            Icons.search,
                            size: 28,
                            color: Colors.greenAccent,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _textController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        enabledBorder:
                            UnderlineInputBorder(borderSide: BorderSide.none),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide.none,
                        ),
                        filled: false,
                        hintText: 'Start typing to discover',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      onFieldSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          searchController.searchUser(value);
                          _textController.clear(); // Clear immediately after search
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: searchController.searchedUsers.isEmpty
            ? Center(
                child: AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/playsphere_search.svg',
                              height: 240.0,
                              width: 240.0,
                            ),
                            const SizedBox(height: 20),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 39),
                              child: Text(
                                'Start typing a name to find creators fast.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w300,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            : ListView.builder(
                itemCount: searchController.searchedUsers.length,
                itemBuilder: (context, index) {
                  UserModel user = searchController.searchedUsers[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(
                          uid: user.uid,
                          fromSearch: true,
                        ),
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          user.profilePhoto,
                        ),
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () {
                          searchController.removeUser(user.uid);
                        },
                      ),
                    ),
                  );
                },
              ),
      );
    });
  }
}
