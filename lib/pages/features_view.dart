import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../controllers/health_sync_controller.dart';
import 'ai_diet_view.dart';
import 'ai_workout_plan_view.dart';
import 'habit_tracker_page.dart';
import 'health_metrics_view.dart';
import 'meal_tracker_page.dart';
import 'posture_analysis_view.dart';
import 'recovery_checkin_page.dart';
import 'streaks_rewards_page.dart';
import 'walking_missions_page.dart';
import 'workout_tracker_view.dart';

const Color kPrimaryColor = Color(0xFF2563EB);

class FeatureData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final String kicker;
  final Color accentColor;
  final WidgetBuilder builder;

  const FeatureData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.kicker,
    required this.accentColor,
    required this.builder,
  });
}

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

class FeaturesView extends StatelessWidget {
  const FeaturesView({
    super.key,
    required this.controller,
    required this.authController,
  });

  final HealthSyncController controller;
  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    final quickActions = [
      FeatureData(
        icon: Icons.accessibility_new_rounded,
        title: 'Posture Analysis',
        subtitle: 'AI-powered posture correction and movement feedback.',
        badge: 'AI Form Lab',
        kicker: 'Camera-guided coaching',
        accentColor: const Color(0xFF14B8A6),
        builder: (context) => const PostureAnalysisView(),
      ),
      FeatureData(
        icon: Icons.directions_run_rounded,
        title: 'Track Workout',
        subtitle: 'Log sessions, capture effort, and monitor training output.',
        badge: 'Tracker',
        kicker: 'Realtime workout logging',
        accentColor: const Color(0xFFF97316),
        builder: (context) => WorkoutTrackerView(controller: controller),
      ),
      FeatureData(
        icon: Icons.auto_awesome_rounded,
        title: 'Workout AI',
        subtitle: 'Generate a sharp daily workout plan matched to your needs.',
        badge: 'AI Planner',
        kicker: 'Adaptive training ideas',
        accentColor: const Color(0xFF3B82F6),
        builder: (context) => const AiWorkoutPlanView(),
      ),
      FeatureData(
        icon: Icons.restaurant_menu_rounded,
        title: 'Diet AI',
        subtitle:
            'Build a diet plan with AI around goals, calories, and habits.',
        badge: 'Nutrition',
        kicker: 'Meal structure support',
        accentColor: const Color(0xFF22C55E),
        builder: (context) => const AiDietView(),
      ),
      FeatureData(
        icon: Icons.photo_camera_back_rounded,
        title: 'Meal Tracker',
        subtitle: 'Log meals, calories, and food photos with less friction.',
        badge: 'Food Log',
        kicker: 'Meals, photos, and calories',
        accentColor: const Color(0xFF16A34A),
        builder: (context) => const MealTrackerPage(),
      ),
      FeatureData(
        icon: Icons.calculate_rounded,
        title: 'Health Metrics',
        subtitle: 'Check BMI, BMR, and body metrics in a cleaner dashboard.',
        badge: 'Numbers',
        kicker: 'Body stats snapshot',
        accentColor: const Color(0xFF8B5CF6),
        builder: (context) => const HealthMetricsView(),
      ),
      FeatureData(
        icon: Icons.water_drop_rounded,
        title: 'Habit Tracker',
        subtitle: 'Stay on top of water, sleep, mood, and recovery patterns.',
        badge: 'Consistency',
        kicker: 'Everyday habit rituals',
        accentColor: const Color(0xFF0EA5E9),
        builder: (context) => const HabitTrackerPage(),
      ),
      FeatureData(
        icon: Icons.spa_rounded,
        title: 'Recovery Check-In',
        subtitle: 'Score readiness before training and adjust the day wisely.',
        badge: 'Coach',
        kicker: 'Readiness before you push',
        accentColor: const Color(0xFF10B981),
        builder: (context) => const RecoveryCheckInPage(),
      ),
      FeatureData(
        icon: Icons.workspace_premium_rounded,
        title: 'Streaks & Rewards',
        subtitle: 'Watch streaks, XP, and badges turn progress into momentum.',
        badge: 'Motivation',
        kicker: 'XP, streaks, unlocks',
        accentColor: const Color(0xFFEAB308),
        builder: (context) => StreaksRewardsPage(
          controller: controller,
          authController: authController,
        ),
      ),
      FeatureData(
        icon: Icons.route_rounded,
        title: 'Walking Missions',
        subtitle: 'Take on route goals and live distance missions outdoors.',
        badge: 'Adventure',
        kicker: 'Distance-led challenges',
        accentColor: const Color(0xFF2563EB),
        builder: (context) => const WalkingMissionsPage(),
      ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundTop = isDark
        ? const Color(0xFF0B1324)
        : const Color(0xFFF8FAFC);
    final backgroundBottom = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundTop, backgroundBottom],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              const Positioned.fill(child: _BackdropOrbs()),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Health Hub Features',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.1,
                              color: isDark
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFD6E4FF),
                            ),
                          ),
                          child: Text(
                            '${quickActions.length} tools',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFBFDBFE)
                                  : const Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FeatureHero(
                      isDark: isDark,
                      featureCount: quickActions.length,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Explore your tools',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: isDark
                            ? const Color(0xFFF8FAFC)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Training, nutrition, recovery, and AI tools in a cleaner layout that matches the rest of the app.',
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = constraints.maxWidth > 760
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (var i = 0; i < quickActions.length; i++)
                              SizedBox(
                                width: cardWidth,
                                child: _ActionTile(
                                  data: quickActions[i],
                                  index: i,
                                  isLocked:
                                      authController.isGuest &&
                                      quickActions[i].title ==
                                          'Posture Analysis',
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureHero extends StatelessWidget {
  const _FeatureHero({required this.isDark, required this.featureCount});

  final bool isDark;
  final int featureCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF162033), Color(0xFF1E293B)]
              : const [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFC7D2FE),
              ),
            ),
            child: Text(
              'All-in-one tools',
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF4338CA),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Everything you need to train, recover, and stay consistent.',
            style: TextStyle(
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              fontSize: 26,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Explore $featureCount features across workouts, nutrition, posture, recovery, and habit tracking.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 14.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _HeroChip(icon: Icons.auto_awesome_rounded, label: 'AI planning'),
              _HeroChip(
                icon: Icons.monitor_heart_outlined,
                label: 'Health metrics',
              ),
              _HeroChip(
                icon: Icons.local_fire_department_outlined,
                label: 'Momentum tools',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            size: 16,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropOrbs extends StatelessWidget {
  const _BackdropOrbs();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -50,
              right: -30,
              child: _Orb(
                size: 180,
                color: isDark
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.08)
                    : const Color(0xFF60A5FA).withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              top: 220,
              left: -70,
              child: _Orb(
                size: 160,
                color: isDark
                    ? const Color(0xFF34D399).withValues(alpha: 0.05)
                    : const Color(0xFF34D399).withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              bottom: 120,
              right: -60,
              child: _Orb(
                size: 220,
                color: isDark
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.05)
                    : const Color(0xFFFDE68A).withValues(alpha: 0.09),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.data,
    required this.index,
    this.isLocked = false,
  });

  final FeatureData data;
  final int index;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = data.accentColor;
    final cardColors = isDark
        ? [
            const Color(0xFF162033).withValues(alpha: 0.96),
            const Color(0xFF1E293B).withValues(alpha: 0.96),
          ]
        : [Colors.white, accent.withValues(alpha: 0.03)];

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in required to use Posture Analysis.'),
            ),
          );
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: data.builder));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cardColors,
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -18,
              right: -12,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: (index.isEven ? 1 : -1) * (math.pi / 14),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.22),
                          accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CapsuleLabel(
                            text: data.badge,
                            background: accent.withValues(alpha: 0.14),
                            foreground: accent,
                          ),
                          _CapsuleLabel(
                            text: data.kicker,
                            background: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF8FAFC),
                            foreground: isDark
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF334155),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.86),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : accent.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Icon(
                        isLocked
                            ? Icons.lock_outline_rounded
                            : Icons.arrow_outward_rounded,
                        color: isLocked ? const Color(0xFF94A3B8) : accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.2),
                            accent.withValues(alpha: 0.34),
                          ],
                        ),
                      ),
                      child: Icon(data.icon, color: accent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            data.title,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: isDark
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data.subtitle,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      isLocked ? 'Unlock by signing in' : 'Open feature',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 1.5,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: isLocked
                          ? const Color(0xFF94A3B8)
                          : accent.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleLabel extends StatelessWidget {
  const _CapsuleLabel({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
