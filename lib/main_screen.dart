import 'package:flutter/material.dart';
import 'controllers/health_sync_controller.dart';
import 'controllers/auth_controller.dart';
import 'pages/about_page.dart';
import 'pages/features_view.dart';
import 'pages/home_page.dart';
import 'pages/community_page.dart';
import 'widgets/health_chatbot_widget.dart';

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

  Future<
    bool
  >
  _onWillPop() async {
    if (_selectedIndex !=
        0) {
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
      return false;
    }
    return true;
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

        body: Stack(
          children: [
            // Page content with bottom padding for chatbot and bottom nav
            Padding(
              padding: const EdgeInsets.only(bottom: 140),
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
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
                  const CommunityPage(),
                  FeaturesView(
                    controller: _healthSyncController,
                  ),
                  const AboutPage(),
                ],
              ),
            ),
<<<<<<< HEAD
            CommunityPage(
              healthSyncController: _healthSyncController,
            ),
            FeaturesView(
              controller: _healthSyncController,
            ),
            const AboutPage(),
=======
            // Floating Health Chatbot - always visible at bottom
            const HealthChatbotWidget(),
>>>>>>> 4c909540169ba0865e0284fdcc204f225deef3c8
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
                Icons.people,
              ),
              label: 'Community',
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
