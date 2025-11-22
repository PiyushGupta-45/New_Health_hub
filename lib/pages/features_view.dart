// features_view.dart

import 'package:flutter/material.dart';

import '../controllers/health_sync_controller.dart';
import 'health_metrics_view.dart'; // Import the calculator page
import 'posture_analysis_view.dart'; // Import the new posture page
import 'personalized_goals_view.dart';
import 'workout_tracker_view.dart';

// --- Global Constants (for colors) ---
const Color kPrimaryColor = Color(0xFF6366F1);
const Color kBackgroundColor = Color(0xFFF8FAFC);

// --- Feature Data Structure ---
class FeatureData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final WidgetBuilder builder;

  const FeatureData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.builder,
  });
}

// --- Placeholder for Features Not Yet Built ---
class PlaceholderFeatureView extends StatelessWidget {
  final String title;
  const PlaceholderFeatureView({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          '$title UI Coming Soon!',
          style: const TextStyle(fontSize: 24, color: Colors.grey),
        ),
      ),
    );
  }
}

// --- The Main Feature Page (List of Cards) ---
class FeaturesView extends StatelessWidget {
  const FeaturesView({super.key, required this.controller});

  final HealthSyncController controller;

  @override
  Widget build(BuildContext context) {
    final quickActions = [
      FeatureData(
        icon: Icons.calculate,
        title: 'Health Metrics',
        subtitle: 'BMR, BMI, and body analysis.',
        iconColor: const Color(0xFF8A2BE2),
        builder: (context) => const HealthMetricsView(),
      ),
      FeatureData(
        icon: Icons.accessibility_new,
        title: 'Posture Analysis',
        subtitle: 'AI-powered posture correction.',
        iconColor: const Color(0xFF20B2AA),
        builder: (context) => const PostureAnalysisView(),
      ),
      FeatureData(
        icon: Icons.check_circle_outline,
        title: 'Personalized Goals',
        subtitle: 'Set and manage your health goals.',
        iconColor: const Color(0xFFFFA500),
        builder: (context) => const PersonalizedGoalsView(),
      ),
      FeatureData(
        icon: Icons.directions_run,
        title: 'Track Workout',
        subtitle: 'Log and analyze your workouts.',
        iconColor: const Color(0xFFFF4500),
        builder: (context) => WorkoutTrackerView(controller: controller),
      ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Health Hub Features',
          style: TextStyle(
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Explore your tools for a healthier life',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 15),
            // Build the Feature Cards
            ...quickActions.map((data) => _ActionTile(data: data)).toList(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 110),
          ],
        ),
      ),
    );
  }
}

// --- The Clickable Feature Card Widget ---
class _ActionTile extends StatelessWidget {
  final FeatureData data;

  const _ActionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigation Logic to the Feature Page
        Navigator.push(context, MaterialPageRoute(builder: data.builder));
      },
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                width: 1,
              ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    data.iconColor.withOpacity(0.15),
                    data.iconColor.withOpacity(0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: data.iconColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(data.icon, color: data.iconColor, size: 28),
            ),
            const SizedBox(width: 15),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
      );
        },
      ),
    );
  }
}
