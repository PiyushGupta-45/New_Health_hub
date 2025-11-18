import 'package:flutter/material.dart';
import 'controllers/health_sync_controller.dart';
import 'controllers/auth_controller.dart';
import 'pages/about_page.dart';
import 'pages/features_view.dart';
import 'pages/home_page.dart';
import 'pages/community_page.dart';

class MainScreen
    extends
        StatefulWidget {
  const MainScreen({
    super.key,
  });

  @override
  State<
    MainScreen
  >
  createState() => _MainScreenState();
}

class _MainScreenState
    extends
        State<
          MainScreen
        > {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final HealthSyncController _healthSyncController = HealthSyncController();
  final AuthController _authController = AuthController();

  // Navigate using bottom navigation
  void _onItemTapped(
    int index,
  ) {
    setState(
      () {
        _selectedIndex = index;
      },
    );

    _pageController.animateToPage(
      index,
      duration: const Duration(
        milliseconds: 300,
      ),
      curve: Curves.easeInOut,
    );
  }

  // Handle Android back button
  Future<
    bool
  >
  _onWillPop() async {
    if (_selectedIndex !=
        0) {
      // Go to previous page instead of exiting the app
      setState(
        () {
          _selectedIndex--;
        },
      );

      _pageController.animateToPage(
        _selectedIndex,
        duration: const Duration(
          milliseconds: 300,
        ),
        curve: Curves.easeOut,
      );

      return false; // prevent app exit
    }

    return true; // exit app normally only when on Home page
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(
          0xFFF4F6F9,
        ),

        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // Disable swipe to avoid conflicts
          onPageChanged:
              (
                index,
              ) {
                setState(
                  () {
                    _selectedIndex = index;
                  },
                );
              },
          children: [
            HomePage(
              controller: _healthSyncController,
              authController: _authController,
            ),
            FeaturesView(
              controller: _healthSyncController,
            ),
            const AboutPage(),
            const CommunityPage(),
          ],
        ),

        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.indigo.shade600,
          unselectedItemColor: Colors.grey.shade500,
          showUnselectedLabels: true,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(
                Icons.home,
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.star,
              ),
              label: 'Features',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.info_outline,
              ),
              label: 'About',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.people,
              ),
              label: 'Community',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _healthSyncController.dispose();
    _authController.dispose();
    super.dispose();
  }
}
