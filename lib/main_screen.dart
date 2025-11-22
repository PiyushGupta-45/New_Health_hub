import 'package:flutter/material.dart';
import 'controllers/health_sync_controller.dart';
import 'controllers/auth_controller.dart';
import 'pages/about_page.dart';
import 'pages/features_view.dart';
import 'pages/home_page.dart';
import 'pages/community_page.dart';
import 'widgets/health_chatbot_widget.dart';

// Chatbot Dialog Wrapper
class HealthChatbotDialog extends StatelessWidget {
  const HealthChatbotDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const HealthChatbotWidget(),
      ),
    );
  }
}

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

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2563EB).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade500,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade500,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        body: Stack(
          children: [
            // Page content
            PageView(
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
                  CommunityPage(
                    healthSyncController: _healthSyncController,
                  ),
                  FeaturesView(
                    controller: _healthSyncController,
                  ),
                  const AboutPage(),
                ],
              ),
            // Floating Health Chatbot - positioned above About button
            const HealthChatbotWidget(),
          ],
        ),

        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_rounded, 'Home', 0),
                  _buildNavItem(Icons.people_rounded, 'Community', 1),
                  _buildNavItem(Icons.star_rounded, 'Features', 2),
                  _buildNavItem(Icons.info_outline_rounded, 'About', 3),
                ],
              ),
            ),
          ),
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
