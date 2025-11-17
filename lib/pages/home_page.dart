// This file contains the main home page widget, including the UI for
// the progress card and quick actions.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/health_sync_controller.dart';
import '../controllers/auth_controller.dart';
import 'workout_tracker_view.dart';
import 'personalized_goals_view.dart';
import 'posture_analysis_view.dart';
import 'auth_page.dart';
import 'steps_history_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.authController,
  });

  final HealthSyncController controller;
  final AuthController authController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _defaultStepGoal = 10000;
  bool _requestedInitialSync = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requestedInitialSync) {
      _requestedInitialSync = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Clear any old cached data and force a fresh sync
        widget.controller.clearCache();
        widget.controller.sync(force: true);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onSyncPressed() {
    widget.controller.sync(force: true);
  }

  String _formatLastSyncedAt() {
    final lastSynced = widget.controller.lastSyncedAt;
    if (lastSynced == null) return 'Not synced yet';
    final formatter = DateFormat('MMM d • h:mm a');
    return 'Last synced ${formatter.format(lastSynced)}';
  }

  Widget? _buildStatusBanner() {
    final status = widget.controller.status;
    final message = widget.controller.errorMessage;

    if (status == HealthSyncStatus.ready || status == HealthSyncStatus.idle) {
      return null;
    }

    Color backgroundColor = const Color(0xFFE0E7FF);
    Color textColor = const Color(0xFF1E3A8A);
    String title = 'Sync in progress';
    List<Widget> actions = <Widget>[];

    switch (status) {
      case HealthSyncStatus.syncing:
        title = 'Getting step data...';
        actions = const <Widget>[
          Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: LinearProgressIndicator(),
          ),
        ];
        break;
      case HealthSyncStatus.permissionsRequired:
        title = 'Grant permissions to continue syncing';
        backgroundColor = const Color(0xFFFFF7ED);
        textColor = const Color(0xFF9A3412);
        actions = <Widget>[
          ElevatedButton.icon(
            onPressed: widget.controller.isSyncing ? null : _onSyncPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB923C),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.settings),
            label: const Text('Try Again'),
          ),
        ];
        break;
      case HealthSyncStatus.healthConnectUnavailable:
        // Don't show error if we're using direct sensor successfully
        if (widget.controller.status == HealthSyncStatus.ready) {
          return null;
        }
        title = 'Using phone sensor for steps';
        backgroundColor = const Color(0xFFE0E7FF);
        textColor = const Color(0xFF1E3A8A);
        break;
      case HealthSyncStatus.platformNotSupported:
        title = 'Android device required for Samsung Health syncing';
        backgroundColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF7F1D1D);
        break;
      case HealthSyncStatus.error:
        title = 'Something went wrong while syncing';
        backgroundColor = const Color(0xFFFFF7ED);
        textColor = const Color(0xFF9A3412);
        actions = <Widget>[
          ElevatedButton.icon(
            onPressed: widget.controller.isSyncing ? null : _onSyncPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB923C),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ];
        break;
      case HealthSyncStatus.idle:
      case HealthSyncStatus.ready:
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: textColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == HealthSyncStatus.syncing
                    ? Icons.sync
                    : status == HealthSyncStatus.error ||
                            status == HealthSyncStatus.permissionsRequired
                        ? Icons.warning_rounded
                        : Icons.info_outline_rounded,
                color: textColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                message,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, children: actions),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.controller.todaySteps;
    final progress = (steps / _defaultStepGoal).clamp(0.0, 1.0);
    final percentage = (progress * 100).clamp(0, 100).toStringAsFixed(0);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFF8FAFC),
              const Color(0xFFF1F5F9),
            ],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            margin: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modern Header Section
                Padding(
                  padding: const EdgeInsets.only(top: 32.0, bottom: 28.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Let\'s make today count!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.sync,
                                  size: 14,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatLastSyncedAt(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildUserAvatar(),
                    ],
                  ),
                ),
                
                // Status Banner
                if (_buildStatusBanner() != null) _buildStatusBanner()!,
                
                // Modern Progress Card with Gradient
                Container(
                  padding: const EdgeInsets.all(28.0),
                  margin: const EdgeInsets.only(bottom: 28.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28.0),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.indigo.shade600,
                        Colors.indigo.shade800,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.shade400.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Progress",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$percentage%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Modern Progress Bar
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress.isNaN ? 0 : progress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatSteps(steps),
                                      style: const TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -1,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        'steps',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      size: 16,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Goal: ${_formatSteps(_defaultStepGoal)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.controller.primaryStepsSource != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Source: ${widget.controller.primaryStepsSource}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: widget.controller.isSyncing
                                        ? null
                                        : _onSyncPressed,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (widget.controller.isSyncing)
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Colors.indigo,
                                                ),
                                              ),
                                            )
                                          else
                                            Icon(
                                              Icons.refresh_rounded,
                                              size: 18,
                                              color: Colors.indigo.shade600,
                                            ),
                                          const SizedBox(width: 8),
                                          Text(
                                            widget.controller.isSyncing
                                                ? 'Syncing…'
                                                : 'Sync',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Colors.indigo.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: widget.controller.isSyncing
                                    ? null
                                    : () async {
                                        await widget.controller.resetStepBaseline();
                                      },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white.withOpacity(0.8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => WorkoutTrackerView(
                                  controller: widget.controller,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text(
                            'View Workout Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Quick Actions Section
                Row(
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_formatNumber(_defaultStepGoal)} steps goal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    _buildModernActionCard(
                      context: context,
                      icon: Icons.flag_rounded,
                      iconColor: const Color(0xFFFFA500),
                      iconBgColor: const Color(0xFFFFA500).withOpacity(0.1),
                      title: 'Personalized Goals',
                      subtitle: 'Set and manage your health goals',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PersonalizedGoalsView(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildModernActionCard(
                      context: context,
                      icon: Icons.accessibility_new_rounded,
                      iconColor: const Color(0xFF20B2AA),
                      iconBgColor: const Color(0xFF20B2AA).withOpacity(0.1),
                      title: 'Posture Analysis',
                      subtitle: 'AI-powered posture correction',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PostureAnalysisView(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildModernActionCard(
                      context: context,
                      icon: Icons.directions_run_rounded,
                      iconColor: const Color(0xFFFF4500),
                      iconBgColor: const Color(0xFFFF4500).withOpacity(0.1),
                      title: 'Track Workout',
                      subtitle: 'Log and analyze your workouts',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                WorkoutTrackerView(controller: widget.controller),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ListenableBuilder(
                      listenable: widget.authController,
                      builder: (context, child) {
                        if (widget.authController.isAuthenticated) {
                          return _buildModernActionCard(
                            context: context,
                            icon: Icons.history_rounded,
                            iconColor: Colors.purple.shade600,
                            iconBgColor: Colors.purple.shade600.withOpacity(0.1),
                            title: 'Steps History',
                            subtitle: 'View your daily steps history',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => StepsHistoryView(
                                    authController: widget.authController,
                                  ),
                                ),
                              );
                            },
                          );
                        } else {
                          return _buildModernActionCard(
                            context: context,
                            icon: Icons.history_rounded,
                            iconColor: Colors.grey.shade400,
                            iconBgColor: Colors.grey.shade100,
                            title: 'Steps History',
                            subtitle: 'Sign in to view your steps history',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => AuthPage(
                                    authController: widget.authController,
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning!';
    } else if (hour < 17) {
      return 'Good Afternoon!';
    } else {
      return 'Good Evening!';
    }
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildUserAvatar() {
    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, child) {
        final isAuthenticated = widget.authController.isAuthenticated;
        final userInitial = widget.authController.userInitial;

        return GestureDetector(
          onTap: () {
            if (isAuthenticated) {
              _showUserMenu(context);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AuthPage(
                    authController: widget.authController,
                  ),
                ),
              );
            }
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.0),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isAuthenticated
                    ? [
                        Colors.indigo.shade400,
                        Colors.indigo.shade600,
                      ]
                    : [
                        Colors.grey.shade400,
                        Colors.grey.shade600,
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isAuthenticated
                          ? Colors.indigo.shade300
                          : Colors.grey.shade300)
                      .withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: isAuthenticated
                  ? Text(
                      userInitial,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.login_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
        );
      },
    );
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18.0),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.indigo.shade400,
                        Colors.indigo.shade600,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.authController.userInitial,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.authController.userName ?? 'User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.authController.userEmail ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await widget.authController.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed out successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildModernActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: Colors.grey.shade100,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey.shade400,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
