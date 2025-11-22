// This file contains the main home page widget, including the UI for
// the progress card and quick actions.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Assuming these controllers and views exist in the file structure
// Replace with your actual import paths if needed.
import 'package:provider/provider.dart';
import '../controllers/health_sync_controller.dart';
import '../controllers/auth_controller.dart';
import '../services/theme_service.dart';
import '../widgets/theme_toggle_button.dart';
import 'workout_tracker_view.dart';
import 'personalized_goals_view.dart';
import 'posture_analysis_view.dart';
import 'auth_page.dart';
import 'steps_history_view.dart';
import 'account_page.dart';

// Helper extensions for modifying color values slightly
extension on Color {
  Color withValues({double? alpha}) {
    if (alpha != null) {
      return this.withOpacity(alpha);
    }
    return this;
  }
}

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
        widget.controller.hydrateFromBackend();
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
    widget.controller.hydrateFromBackend();
    widget.controller.sync(force: true);
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
    final formatter = NumberFormat.compact(locale: 'en_US');
    return formatter.format(steps);
  }
  
  String _formatNumber(int number) {
    return NumberFormat('#,##0').format(number);
  }


  double _calculateCaloriesFromSteps(int steps) {
    // Average: 0.04 calories per step
    return steps * 0.04;
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

    // Only show banner if status is NOT ready or idle
    if (status == HealthSyncStatus.ready || status == HealthSyncStatus.idle) {
      return null;
    }

    Color backgroundColor = const Color(0xFFE0E7FF);
    Color textColor = const Color(0xFF1E3A8A);
    String title = 'Sync in progress';
    List<Widget> actions = <Widget>[];
    IconData icon = Icons.info_outline_rounded;

    switch (status) {
      case HealthSyncStatus.syncing:
        title = 'Getting step data...';
        icon = Icons.sync;
        actions = const <Widget>[
          Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: LinearProgressIndicator(color: Color(0xFF1E3A8A)),
          ),
        ];
        break;
      case HealthSyncStatus.permissionsRequired:
        title = 'Grant permissions to continue syncing';
        icon = Icons.lock_open_rounded;
        backgroundColor = const Color(0xFFFFF7ED);
        textColor = const Color(0xFF9A3412);
        actions = <Widget>[
          ElevatedButton.icon(
            onPressed: widget.controller.isSyncing ? null : _onSyncPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB923C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Grant Permissions'),
          ),
        ];
        break;
      case HealthSyncStatus.healthConnectUnavailable:
        // Show info about using phone sensor
        title = 'Using local phone sensor for steps';
        icon = Icons.phone_android_rounded;
        backgroundColor = const Color(0xFFEEF2FF); // Lighter blue
        textColor = const Color(0xFF374151); // Darker grey text
        break;
      case HealthSyncStatus.platformNotSupported:
        title = 'Android device required for Samsung Health syncing';
        icon = Icons.block_rounded;
        backgroundColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF7F1D1D);
        break;
      case HealthSyncStatus.error:
        title = 'Something went wrong while syncing';
        icon = Icons.warning_rounded;
        backgroundColor = const Color(0xFFFFF7ED);
        textColor = const Color(0xFF9A3412);
        actions = <Widget>[
          ElevatedButton.icon(
            onPressed: widget.controller.isSyncing ? null : _onSyncPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB923C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry Sync'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          if (message != null && status == HealthSyncStatus.error) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                message,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
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

  Widget _buildUserAvatar() {
    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, child) {
        final isAuthenticated = widget.authController.isAuthenticated;
        final userInitial = widget.authController.userInitial;

        return GestureDetector(
          onTap: () {
            if (isAuthenticated) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AccountPage(
                    authController: widget.authController,
                  ),
                ),
              );
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
                    ? const [
                        Color(0xFF2563EB),
                        Color(0xFF3B82F6),
                      ]
                    : [
                        Colors.grey.shade400,
                        Colors.grey.shade600,
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isAuthenticated
                              ? const Color(0xFF2563EB)
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
    // ... (Your existing _showUserMenu implementation remains here)
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
                // Avatar in the menu
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18.0),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF3B82F6),
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
              leading: const Icon(Icons.settings_rounded, color: Colors.blueGrey),
              title: const Text(
                'Account Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AccountPage(
                      authController: widget.authController,
                    ),
                  ),
                );
              },
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF1E293B),
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
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

  @override
  Widget build(BuildContext context) {
    final steps = widget.controller.todaySteps;
    final progress = (steps / _defaultStepGoal).clamp(0.0, 1.0);
    final percentage = (progress * 100).clamp(0, 100).toStringAsFixed(0);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0F172A), // Dark slate
                    Color(0xFF1E293B), // Slightly lighter dark
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF8FAFC), // Lightest grey/off-white
                    Color(0xFFF1F5F9), // Slightly darker grey
                  ],
                ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420), // Max width for cleaner look on tablets/desktop
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
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFF1F5F9)
                                    : const Color(0xFF1E293B),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Let\'s make today count!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade400
                                    : const Color(0xFF64748B),
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
                
                // --- Modern Progress Card with Gradient (compact) ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                  margin: const EdgeInsets.only(bottom: 20.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.0),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E40AF),
                        Color(0xFF2563EB),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E40AF).withOpacity(0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Percentage
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Progress",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$percentage%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Progress Bar
                      Container(
                        height: 10,
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
                            minHeight: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Step Count Display
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatSteps(steps),
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -1.2,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        'steps',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 10),

                                // Calories Burned Card
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.28),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        color: Colors.orange.shade300,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'CALORIES BURNED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withValues(alpha: 0.8),
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_calculateCaloriesFromSteps(steps).toStringAsFixed(0)} kcal',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                
                                // Step Goal Info
                                Row(
                                  children: [
                                    Icon(
                                      Icons.flag_rounded,
                                      size: 16,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Goal: ${_formatNumber(_defaultStepGoal)} steps',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Sync Button Column
                          Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
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
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (widget.controller.isSyncing)
                                            SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                valueColor: const AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF6366F1),
                                                ),
                                              ),
                                            )
                                          else
                                            Icon(
                                              Icons.refresh_rounded,
                                              size: 20,
                                              color: const Color(0xFF6366F1),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.controller.isSyncing
                                                ? 'Syncing…'
                                                : 'Sync',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Color(0xFF6366F1),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Reset Button
                              TextButton(
                                onPressed: widget.controller.isSyncing
                                    ? null
                                    : () async {
                                        await widget.controller.resetStepBaseline();
                                      },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white.withValues(alpha: 0.85),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero, // Remove default minimum size constraint
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Shrink hit area
                                ),
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // View Details Button
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
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.show_chart_rounded, size: 18),
                          label: const Text(
                            'View Step History & Details',
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
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Tap an action to get started',
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
                      iconColor: const Color(0xFFFF4500), // Orange-Red
                      iconBgColor: const Color(0xFFFF4500).withOpacity(0.1),
                      title: 'Set Personalized Goals',
                      subtitle: 'Customize your health targets',
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
                      iconColor: const Color(0xFF20B2AA), // Sea Green
                      iconBgColor: const Color(0xFF20B2AA).withOpacity(0.1),
                      title: 'Posture Analysis',
                      subtitle: 'AI-powered posture correction feedback',
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
                      iconColor: Colors.deepPurple, // Purple
                      iconBgColor: Colors.deepPurple.withOpacity(0.1),
                      title: 'Track a New Workout',
                      subtitle: 'Start logging a run, walk, or activity',
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
                            icon: Icons.calendar_today_rounded,
                            iconColor: Colors.lightBlue,
                            iconBgColor: Colors.lightBlue.withOpacity(0.1),
                            title: 'View Daily Step Log',
                            subtitle: 'Explore your steps history by date',
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
                            icon: Icons.lock_rounded,
                            iconColor: Colors.grey.shade400,
                            iconBgColor: Colors.grey.shade100,
                            title: 'Sign In Required',
                            subtitle: 'Sign in to access personalized data history',
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
                SizedBox(height: MediaQuery.of(context).padding.bottom + 170),
              ],
            ),
          ),
        ),
      ),
    );
  }
}