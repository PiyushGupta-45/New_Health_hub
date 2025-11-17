// features_view.dart

import 'package:flutter/material.dart';

import '../controllers/health_sync_controller.dart';
import 'health_metrics_view.dart'; // Import the calculator page
import 'posture_analysis_view.dart'; // Import the new posture page
import 'personalized_goals_view.dart';
import 'workout_tracker_view.dart';

// --- Global Constants (for colors) ---
const Color kPrimaryColor = Color(0xFF4C5BF1);
const Color kBackgroundColor = Color(0xFFF7F8FC);

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

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Health Hub Features',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: kBackgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Explore your tools for a healthier life:',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            // Build the Feature Cards
            ...quickActions.map((data) => _ActionTile(data: data)).toList(),
            const SizedBox(height: 20),
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
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: data.iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
