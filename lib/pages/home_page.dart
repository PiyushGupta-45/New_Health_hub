import 'dart:async';

// This file contains the main home page widget, including the UI for
// the progress card and quick actions.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Assuming these controllers and views exist in the file structure
// Replace with your actual import paths if needed.
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../controllers/health_sync_controller.dart';
import '../controllers/auth_controller.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/theme_toggle_button.dart';
import 'workout_tracker_view.dart';
import 'posture_analysis_view.dart';
import 'ai_diet_view.dart';
import 'ai_workout_plan_view.dart';
import 'auth_page.dart';
import 'habit_tracker_page.dart';
import 'meal_tracker_page.dart';
import 'recovery_checkin_page.dart';
import 'streaks_rewards_page.dart';
import 'steps_history_view.dart';
import 'walking_missions_page.dart';
import 'account_page.dart';
import 'progress_dashboard_view.dart';
import '../services/direct_step_service.dart';

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

class _StepGoalEditorDialog extends StatefulWidget {
  const _StepGoalEditorDialog({
    required this.initialGoal,
    required this.defaultGoal,
  });

  final int initialGoal;
  final int defaultGoal;

  @override
  State<_StepGoalEditorDialog> createState() => _StepGoalEditorDialogState();
}

class _StepGoalEditorDialogState extends State<_StepGoalEditorDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialGoal.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(int value) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set daily step goal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose the target shown on your home progress card.'),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Steps',
              hintText: '10000',
              suffixText: 'steps',
              errorText: _errorText,
            ),
            autofocus: true,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() {
                  _errorText = null;
                });
              }
            },
            onSubmitted: (_) {
              final value = int.tryParse(_controller.text.trim());
              if (value != null && value >= 1000 && value <= 100000) {
                _submit(value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _submit(widget.defaultGoal),
          child: const Text('Reset'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = int.tryParse(_controller.text.trim());
            if (value == null || value < 1000 || value > 100000) {
              setState(() {
                _errorText = 'Enter a step goal between 1,000 and 100,000.';
              });
              return;
            }
            _submit(value);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const int _defaultStepGoal = 10000;
  static const String _homeStepGoalKey = 'home_step_goal';
  static const int _uspBannerCount = 3;
  bool _requestedInitialSync = false;
  bool _checkedBackgroundPrompt = false;
  bool _isDebugPanelExpanded = false;
  final PageController _uspBannerController = PageController();
  Timer? _uspBannerTimer;
  int _uspBannerIndex = 0;
  int _currentStepGoal = _defaultStepGoal;
  static const String _backgroundPromptKey = 'background_tracking_prompt_shown';
  final DirectStepService _directStepService = DirectStepService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_handleControllerChanged);
    _startUspBannerAutoplay();
    unawaited(_loadStepGoal());
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
        unawaited(_performInitialStepLoad());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadStepGoal());
    }
  }

  Future<void> _performInitialStepLoad() async {
    widget.controller.clearCache();
    await widget.controller.sync(force: true);
    await _maybeShowBackgroundTrackingPrompt();
    unawaited(widget.controller.hydrateFromBackend());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uspBannerTimer?.cancel();
    _uspBannerController.dispose();
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _startUspBannerAutoplay() {
    _uspBannerTimer?.cancel();
    _uspBannerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_uspBannerController.hasClients) return;
      final nextIndex = (_uspBannerIndex + 1) % _uspBannerCount;
      _uspBannerController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadStepGoal() async {
    final profileGoal = _readStepGoalFromProfile();
    if (profileGoal != null) {
      if (!mounted || profileGoal == _currentStepGoal) return;
      setState(() {
        _currentStepGoal = profileGoal;
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final resolvedGoal = prefs.getInt(_homeStepGoalKey) ?? _defaultStepGoal;
    if (!mounted || resolvedGoal == _currentStepGoal) return;
    setState(() {
      _currentStepGoal = resolvedGoal;
    });
  }

  Future<void> _saveStepGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_homeStepGoalKey, goal);

    if (widget.authController.isAuthenticated &&
        !widget.authController.isGuest) {
      final result = await _authService.updateProfile(dailyStepGoal: goal);
      if (result['success'] == true) {
        await widget.authController.refreshUser();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error']?.toString() ??
                  'Saved locally, but failed to sync step goal to your account.',
            ),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _currentStepGoal = goal;
    });
  }

  int? _readStepGoalFromProfile() {
    final rawValue = widget.authController.currentUser?['dailyStepGoal'];
    if (rawValue is int) return rawValue;
    if (rawValue is num) return rawValue.toInt();
    if (rawValue is String) return int.tryParse(rawValue);
    return null;
  }

  Future<void> _showStepGoalEditor() async {
    final savedGoal = await showDialog<int>(
      context: context,
      builder: (dialogContext) => _StepGoalEditorDialog(
        initialGoal: _currentStepGoal,
        defaultGoal: _defaultStepGoal,
      ),
    );

    if (savedGoal == null || savedGoal == _currentStepGoal) return;
    await _saveStepGoal(savedGoal);
  }

  Future<void> _maybeShowBackgroundTrackingPrompt() async {
    if (_checkedBackgroundPrompt || !mounted) return;
    _checkedBackgroundPrompt = true;

    if (!Theme.of(
      context,
    ).platform.toString().toLowerCase().contains('android')) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_backgroundPromptKey) ?? false;
    if (alreadyShown || !mounted) return;

    await prefs.setBool(_backgroundPromptKey, true);

    final isIgnoringBatteryOptimizations = await _directStepService
        .isIgnoringBatteryOptimizations();
    if (isIgnoringBatteryOptimizations || !mounted) {
      return;
    }

    await _directStepService.requestIgnoreBatteryOptimizations();
  }

  void _onSyncPressed() async {
    // First hydrate from backend to get latest data (force refresh)
    await widget.controller.hydrateFromBackend(force: true);
    // Wait a moment for baseline alignment to complete
    await Future.delayed(const Duration(milliseconds: 500));
    // Then sync from sensor to get current steps
    await widget.controller.sync(force: true);
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
    final lastSynced =
        widget.controller.debugLastBackendSyncSuccessAt ??
        widget.controller.lastSyncedAt;
    if (lastSynced == null) return 'Not synced yet';
    final formatter = DateFormat('MMM d • h:mm a');
    return 'Last synced ${formatter.format(lastSynced)}';
  }

  String _formatDebugDateTime(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('HH:mm:ss').format(value);
  }

  Widget _buildStepDebugPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = <MapEntry<String, String>>[
      MapEntry('UI todaySteps', '${widget.controller.todaySteps}'),
      MapEntry(
        'sensor cumulative (raw)',
        '${widget.controller.debugSensorCumulative ?? '-'}',
      ),
      MapEntry(
        'sensor daily (synced)',
        '${widget.controller.debugReturnedTodaySteps ?? widget.controller.todaySteps}',
      ),
      MapEntry(
        'native today',
        '${widget.controller.debugNativeTodaySteps ?? '-'}',
      ),
      MapEntry(
        'computed today',
        '${widget.controller.debugComputedTodaySteps ?? '-'}',
      ),
      MapEntry(
        'returned today',
        '${widget.controller.debugReturnedTodaySteps ?? '-'}',
      ),
      MapEntry('baseline', '${widget.controller.debugBaseline ?? '-'}'),
      MapEntry(
        'last synced steps',
        '${widget.controller.debugLastSyncedSteps ?? '-'}',
      ),
      MapEntry(
        'sync attempt steps',
        '${widget.controller.debugLastBackendSyncAttemptSteps ?? '-'}',
      ),
      MapEntry(
        'sync attempt at',
        _formatDebugDateTime(widget.controller.debugLastBackendSyncAttemptAt),
      ),
      MapEntry(
        'sync success at',
        _formatDebugDateTime(widget.controller.debugLastBackendSyncSuccessAt),
      ),
      MapEntry(
        'sync result',
        widget.controller.debugLastBackendSyncResult ?? '-',
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _isDebugPanelExpanded = !_isDebugPanelExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Step Debug Panel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isDebugPanelExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ),
          if (_isDebugPanelExpanded) ...[
            const SizedBox(height: 8),
            ...rows.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 128,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
        border: Border.all(color: textColor.withOpacity(0.1), width: 1),
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
                  builder: (context) =>
                      AccountPage(authController: widget.authController),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      AuthPage(authController: widget.authController),
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
                    ? const [Color(0xFF2563EB), Color(0xFF3B82F6)]
                    : [Colors.grey.shade400, Colors.grey.shade600],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (isAuthenticated
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
                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
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
              leading: const Icon(
                Icons.settings_rounded,
                color: Colors.blueGrey,
              ),
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
                    builder: (context) =>
                        AccountPage(authController: widget.authController),
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

  Widget _buildUspBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = <Map<String, dynamic>>[
      {
        'title': 'Posture Analysis',
        'subtitle': 'AI-powered posture correction feedback',
        'icon': Icons.accessibility_new_rounded,
        'start': const Color(0xFF20B2AA),
        'end': const Color(0xFF0EA5A5),
        'onTap': () {
          if (widget.authController.isGuest) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sign in required to use Posture Analysis.'),
              ),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PostureAnalysisView(),
            ),
          );
        },
      },
      {
        'title': 'Diet AI',
        'subtitle': 'Create a diet plan with AI',
        'icon': Icons.restaurant_menu,
        'start': const Color(0xFF22C55E),
        'end': const Color(0xFF16A34A),
        'onTap': () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => const AiDietView()));
        },
      },
      {
        'title': 'Workout AI',
        'subtitle': 'Create a daily workout plan',
        'icon': Icons.auto_awesome_rounded,
        'start': const Color(0xFF3B82F6),
        'end': const Color(0xFF2563EB),
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AiWorkoutPlanView()),
          );
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 145,
          child: PageView.builder(
            controller: _uspBannerController,
            itemCount: items.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() {
                _uspBannerIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: item['onTap'] as VoidCallback,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            item['start'] as Color,
                            item['end'] as Color,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (item['start'] as Color).withOpacity(0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] as String,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  item['subtitle'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white.withOpacity(0.95),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (index) {
            final isActive = index == _uspBannerIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 7,
              width: isActive ? 24 : 7,
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF2563EB))
                    : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
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
    final progress = (steps / _currentStepGoal).clamp(0.0, 1.0);
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
            constraints: const BoxConstraints(
              maxWidth: 420,
            ), // Max width for cleaner look on tablets/desktop
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
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
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
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
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
                _buildStepDebugPanel(context),

                // --- Modern Progress Card with Gradient (compact) ---
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18.0,
                    vertical: 16.0,
                  ),
                  margin: const EdgeInsets.only(bottom: 20.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.0),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
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
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.28,
                                      ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'CALORIES BURNED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
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
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _showStepGoalEditor,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.flag_rounded,
                                            size: 16,
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Goal: ${_formatNumber(_currentStepGoal)} steps',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.edit_rounded,
                                            size: 15,
                                            color: Colors.white.withValues(
                                              alpha: 0.82,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
                                      color: Colors.black.withValues(
                                        alpha: 0.12,
                                      ),
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
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                      Color
                                                    >(Color(0xFF6366F1)),
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
                                        await widget.controller
                                            .resetStepBaseline();
                                      },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white.withValues(
                                    alpha: 0.85,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size
                                      .zero, // Remove default minimum size constraint
                                  tapTargetSize: MaterialTapTargetSize
                                      .shrinkWrap, // Shrink hit area
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
                                builder: (context) => ProgressDashboardView(
                                  controller: widget.controller,
                                  authController: widget.authController,
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
                            'View Dashboard & Insights',
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
                    _buildUspBanner(context),
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
                            builder: (context) => WorkoutTrackerView(
                              controller: widget.controller,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildModernActionCard(
                      context: context,
                      icon: Icons.route_rounded,
                      iconColor: const Color(0xFF2563EB),
                      iconBgColor: const Color(0xFF2563EB).withOpacity(0.1),
                      title: 'Walking Missions',
                      subtitle:
                          'Start a route goal with live distance tracking',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const WalkingMissionsPage(),
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
                            subtitle:
                                'Sign in to access personalized data history',
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
