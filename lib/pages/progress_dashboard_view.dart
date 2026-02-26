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
      final key = DateFormat('yyyy-MM-dd').format(parsed);
      mapByDate[key] = (entry['steps'] as int?) ?? 0;
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
      final day = DateTime(log.startTime.year, log.startTime.month, log.startTime.day);
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
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF111827) : Colors.white;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final weeklyLogs = _logs.where((log) => log.startTime.isAfter(startOfWeek)).toList();
    final weeklyWorkoutCount = weeklyLogs.length;
    final weeklyMinutes =
        weeklyLogs.fold<int>(0, (sum, log) => sum + (log.durationSeconds / 60).round());
    final weeklyCalories =
        weeklyLogs.fold<double>(0, (sum, log) => sum + log.calories);
    final activeGoals = _goals.where((goal) => goal.deadline.isAfter(now)).length;
    final overdueGoals = _goals.where((goal) => !goal.deadline.isAfter(now)).length;

    final weeklyStepData = _stepsByDay();
    final weeklyWorkoutData = _workoutsByDay();
    final weeklyStepTotal = weeklyStepData.fold<int>(0, (a, b) => a + b);
    final weeklyStepAvg = (weeklyStepTotal / 7).round();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Progress Dashboard'),
        backgroundColor: bg,
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: isDark ? Colors.red.shade200 : Colors.red.shade700),
                      ),
                    ),
                  Text(
                    'Your last 7 days',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Summary of workouts, steps, calories, and goals.',
                    style: TextStyle(color: sub),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _metricCard(
                        context,
                        title: 'Workouts',
                        value: '$weeklyWorkoutCount',
                        subtitle: 'sessions this week',
                        icon: Icons.fitness_center_rounded,
                      ),
                      _metricCard(
                        context,
                        title: 'Active Minutes',
                        value: '$weeklyMinutes',
                        subtitle: 'minutes this week',
                        icon: Icons.timer_rounded,
                      ),
                      _metricCard(
                        context,
                        title: 'Calories',
                        value: weeklyCalories.toStringAsFixed(0),
                        subtitle: 'kcal this week',
                        icon: Icons.local_fire_department_rounded,
                      ),
                      _metricCard(
                        context,
                        title: 'Steps Avg',
                        value: '$weeklyStepAvg',
                        subtitle: 'avg daily steps',
                        icon: Icons.directions_walk_rounded,
                      ),
                      _metricCard(
                        context,
                        title: 'Goals',
                        value: '$activeGoals',
                        subtitle: 'active, $overdueGoals overdue',
                        icon: Icons.flag_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _chartCard(
                    title: 'Workouts Trend (7 days)',
                    values: weeklyWorkoutData,
                    labels: _last7Dates().map((d) => DateFormat('E').format(d)).toList(),
                    color: const Color(0xFF7C3AED),
                    cardColor: card,
                    textColor: text,
                    subColor: sub,
                  ),
                  const SizedBox(height: 14),
                  _chartCard(
                    title: 'Steps Trend (7 days)',
                    values: weeklyStepData,
                    labels: _last7Dates().map((d) => DateFormat('E').format(d)).toList(),
                    color: const Color(0xFF0EA5E9),
                    cardColor: card,
                    textColor: text,
                    subColor: sub,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = (MediaQuery.of(context).size.width - 52) / 2;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2563EB)),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _chartCard({
    required String title,
    required List<int> values,
    required List<String> labels,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required Color subColor,
  }) {
    final max = values.fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = max <= 0 ? 1 : max;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardColor == Colors.white ? Colors.grey.shade200 : Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List<Widget>.generate(values.length, (index) {
                final value = values[index];
                final ratio = value / safeMax;
                final barHeight = 20 + (ratio * 110);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$value',
                          style: TextStyle(
                            fontSize: 11,
                            color: subColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[index],
                          style: TextStyle(fontSize: 11, color: subColor),
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
