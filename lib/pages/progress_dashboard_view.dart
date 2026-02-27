import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/auth_controller.dart';
import '../controllers/health_sync_controller.dart';
import '../pages/personalized_goals_view.dart';
import '../services/goals_storage_service.dart';
import '../services/steps_sync_service.dart';
import '../services/workout_log_service.dart';

class ProgressDashboardView extends StatefulWidget {
  const ProgressDashboardView({
    super.key,
    required this.controller,
    required this.authController,
  });

  final HealthSyncController controller;
  final AuthController authController;

  @override
  State<ProgressDashboardView> createState() => _ProgressDashboardViewState();
}

class _ProgressDashboardViewState extends State<ProgressDashboardView> {
  final WorkoutLogService _workoutLogService = WorkoutLogService();
  final GoalsStorageService _goalsStorageService = GoalsStorageService();
  final StepsSyncService _stepsSyncService = StepsSyncService();

  bool _isLoading = true;
  String? _error;
  List<ManualWorkoutLog> _logs = const [];
  List<Goal> _goals = const [];
  List<Map<String, dynamic>> _stepsHistory = const [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final logsFuture = _workoutLogService.fetchLogs(limit: 300);
      final goalsFuture = _goalsStorageService.loadGoals();
      final stepsFuture = widget.authController.isAuthenticated
          ? _stepsSyncService.getStepsHistory(limit: 30)
          : Future.value(<String, dynamic>{'success': false, 'data': const []});

      final results = await Future.wait([logsFuture, goalsFuture, stepsFuture]);
      final logs = results[0] as List<ManualWorkoutLog>;
      final goals = results[1] as List<Goal>;
      final stepsResult = results[2] as Map<String, dynamic>;
      final stepsData = stepsResult['data'] is List
          ? List<Map<String, dynamic>>.from(stepsResult['data'] as List)
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _logs = logs;
        _goals = goals;
        _stepsHistory = stepsData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<DateTime> _last7Dates() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return List<DateTime>.generate(
      7,
      (index) => todayDate.subtract(Duration(days: 6 - index)),
    );
  }

  List<int> _stepsByDay() {
    final dates = _last7Dates();
    final values = List<int>.filled(dates.length, 0);
    final mapByDate = <String, int>{};

    for (final entry in _stepsHistory) {
      final rawDate = entry['date']?.toString();
      if (rawDate == null || rawDate.isEmpty) continue;
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;
      final localDate = parsed.toLocal();
      final key = DateFormat('yyyy-MM-dd').format(localDate);
      final value = entry['steps'];
      mapByDate[key] = value is num ? value.toInt() : 0;
    }

    for (int i = 0; i < dates.length; i++) {
      final key = DateFormat('yyyy-MM-dd').format(dates[i]);
      values[i] = mapByDate[key] ?? 0;
    }

    final todayIndex = dates.length - 1;
    final todaySteps = widget.controller.todaySteps;
    if (todaySteps > values[todayIndex]) {
      values[todayIndex] = todaySteps;
    }
    return values;
  }

  List<int> _workoutsByDay() {
    final dates = _last7Dates();
    final values = List<int>.filled(dates.length, 0);
    final mapByDate = <String, int>{};

    for (final log in _logs) {
      final day = DateTime(
        log.startTime.year,
        log.startTime.month,
        log.startTime.day,
      );
      final key = DateFormat('yyyy-MM-dd').format(day);
      mapByDate[key] = (mapByDate[key] ?? 0) + 1;
    }

    for (int i = 0; i < dates.length; i++) {
      final key = DateFormat('yyyy-MM-dd').format(dates[i]);
      values[i] = mapByDate[key] ?? 0;
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final weeklyLogs = _logs
        .where((log) => log.startTime.isAfter(startOfWeek))
        .toList();
    final weeklyWorkoutCount = weeklyLogs.length;
    final weeklyMinutes = weeklyLogs.fold<int>(
      0,
      (sum, log) => sum + (log.durationSeconds / 60).round(),
    );
    final weeklyCalories = weeklyLogs.fold<double>(
      0,
      (sum, log) => sum + log.calories,
    );
    final activeGoals = _goals
        .where((goal) => goal.deadline.isAfter(now))
        .length;
    final overdueGoals = _goals
        .where((goal) => !goal.deadline.isAfter(now))
        .length;

    final weeklyStepData = _stepsByDay();
    final weeklyWorkoutData = _workoutsByDay();
    final weeklyStepTotal = weeklyStepData.fold<int>(0, (a, b) => a + b);
    final weeklyStepAvg = (weeklyStepTotal / 7).round();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF030712)
          : const Color(0xFFF3F6FF),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: text,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned(
                  top: -80,
                  left: -40,
                  child: _GlowOrb(
                    size: 220,
                    color: isDark
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF93C5FD),
                  ),
                ),
                Positioned(
                  top: 180,
                  right: -50,
                  child: _GlowOrb(
                    size: 180,
                    color: isDark
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFC4B5FD),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_error != null)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 14),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF3F1D1D)
                                        : const Color(0xFFFFE4E6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.red.shade200
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              _HeroBand(
                                isDark: isDark,
                                totalSteps: weeklyStepTotal,
                                avgSteps: weeklyStepAvg,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 108,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    _StatPill(
                                      title: 'Workouts',
                                      value: '$weeklyWorkoutCount',
                                      subtitle: 'this week',
                                      icon: Icons.fitness_center_rounded,
                                      color: const Color(0xFF7C3AED),
                                    ),
                                    const SizedBox(width: 10),
                                    _StatPill(
                                      title: 'Active',
                                      value: '$weeklyMinutes min',
                                      subtitle: 'movement time',
                                      icon: Icons.bolt_rounded,
                                      color: const Color(0xFF0EA5E9),
                                    ),
                                    const SizedBox(width: 10),
                                    _StatPill(
                                      title: 'Calories',
                                      value: weeklyCalories.toStringAsFixed(0),
                                      subtitle: 'kcal burned',
                                      icon: Icons.local_fire_department_rounded,
                                      color: const Color(0xFFF97316),
                                    ),
                                    const SizedBox(width: 10),
                                    _StatPill(
                                      title: 'Goals',
                                      value: '$activeGoals',
                                      subtitle: '$overdueGoals overdue',
                                      icon: Icons.flag_rounded,
                                      color: const Color(0xFF22C55E),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Trends',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: text,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _TimelineTrendCard(
                                title: 'Steps Trend',
                                subtitle: 'Last 7 days',
                                values: weeklyStepData,
                                labels: _last7Dates()
                                    .map((d) => DateFormat('E').format(d))
                                    .toList(),
                                color: const Color(0xFF2563EB),
                                isDark: isDark,
                              ),
                              const SizedBox(height: 12),
                              _TimelineTrendCard(
                                title: 'Workout Sessions',
                                subtitle: 'Last 7 days',
                                values: weeklyWorkoutData,
                                labels: _last7Dates()
                                    .map((d) => DateFormat('E').format(d))
                                    .toList(),
                                color: const Color(0xFF8B5CF6),
                                isDark: isDark,
                              ),
                              const SizedBox(height: 20),
                              _InsightStrip(
                                isDark: isDark,
                                lines: [
                                  'You averaged ${NumberFormat.decimalPattern().format(weeklyStepAvg)} steps/day.',
                                  weeklyWorkoutCount >= 4
                                      ? 'Strong workout consistency this week.'
                                      : 'Add 1-2 more workouts for better progress.',
                                  activeGoals == 0
                                      ? 'Create a goal to unlock guided tracking.'
                                      : 'You have $activeGoals active goals in progress.',
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 90,
              spreadRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({
    required this.isDark,
    required this.totalSteps,
    required this.avgSteps,
  });

  final bool isDark;
  final int totalSteps;
  final int avgSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F4CFF), Color(0xFF2563EB), Color(0xFF4F46E5)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${NumberFormat.compact().format(totalSteps)} steps',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              'Average ${NumberFormat.decimalPattern().format(avgSteps)} / day',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF263047) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.18)
                : const Color(0xFF334155).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTrendCard extends StatelessWidget {
  const _TimelineTrendCard({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.labels,
    required this.color,
    required this.isDark,
  });

  final String title;
  final String subtitle;
  final List<int> values;
  final List<String> labels;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = max == 0 ? 1 : max;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0B1220).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF253247) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : const Color(0xFF334155).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List<Widget>.generate(values.length, (index) {
                final value = values[index];
                final ratio = value / safeMax;
                final barHeight = 18 + (ratio * 86);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : 3,
                      right: index == values.length - 1 ? 0 : 3,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$value',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: barHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withValues(alpha: 0.95),
                                color.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightStrip extends StatelessWidget {
  const _InsightStrip({required this.isDark, required this.lines});

  final bool isDark;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF263047) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        height: 1.35,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
