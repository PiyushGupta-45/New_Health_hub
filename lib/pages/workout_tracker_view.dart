// workout_tracker_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/health_sync_controller.dart';
import '../models/manual_workout_template.dart';
import '../services/health_sync_service.dart';
import '../services/goal_progress_service.dart';
import '../services/goals_storage_service.dart';
import '../services/workout_plan_schedule_service.dart';
import '../services/workout_log_service.dart';
import '../services/weekly_workout_plan_service.dart';
import 'personalized_goals_view.dart'; // Import Goal model and activeGoals list
import 'workout_session_page.dart';
import 'workout_details_page.dart';

// Reuse constants
const Color kPrimaryColor = Color(0xFF4C5BF1);
const Color kBackgroundColor = Color(0xFFF7F8FC);
const Color kAccentColor = Color(0xFFFF4500); // Orange Red for Workout Logs

class WorkoutTrackerView extends StatefulWidget {
  const WorkoutTrackerView({
    super.key,
    required this.controller,
    this.initialTab = 0,
  });

  final HealthSyncController controller;
  final int initialTab;

  @override
  State<WorkoutTrackerView> createState() => _WorkoutTrackerViewState();
}

class _WorkoutTrackerViewState extends State<WorkoutTrackerView> {
  final WorkoutLogService _workoutLogService = WorkoutLogService();
  final WeeklyWorkoutPlanService _weeklyWorkoutPlanService =
      WeeklyWorkoutPlanService();
  final WorkoutPlanScheduleService _scheduleService =
      WorkoutPlanScheduleService();
  List<ManualWorkoutLog> _manualLogs = const [];
  WorkoutPlanSchedule? _schedule;
  List<Goal> _savedGoals = const [];
  bool _manualLogsLoading = false;
  bool _planLoading = false;
  bool _goalsLoading = false;
  String? _manualLogsError;
  String? _planError;
  String? _goalsError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    if (widget.controller.snapshot == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.sync();
      });
    }
    _fetchManualLogs();
    _loadWorkoutPlan();
    _loadGoals();
  }

  @override
  void didUpdateWidget(covariant WorkoutTrackerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
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

  Future<void> _fetchManualLogs() async {
    setState(() {
      _manualLogsLoading = true;
      _manualLogsError = null;
    });
    try {
      final logs = await _workoutLogService.fetchLogs(limit: 100);
      if (!mounted) return;
      setState(() {
        _manualLogs = logs;
        _manualLogsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _manualLogsLoading = false;
        // Don't show error for local storage, just log it
        _manualLogsError = null;
      });
    }
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      widget.controller.sync(force: true),
      _fetchManualLogs(),
      _loadWorkoutPlan(),
      _loadGoals(),
    ]);
  }

  Future<void> _loadGoals() async {
    setState(() {
      _goalsLoading = true;
      _goalsError = null;
    });
    try {
      final goals = await GoalsStorageService().loadGoals();
      if (!mounted) return;
      setState(() {
        _savedGoals = goals;
        activeGoals
          ..clear()
          ..addAll(goals);
        _goalsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _goalsLoading = false;
        _goalsError = error.toString();
      });
    }
  }

  Future<void> _loadWorkoutPlan() async {
    setState(() {
      _planLoading = true;
      _planError = null;
    });

    try {
      final planResult = await _weeklyWorkoutPlanService
          .getLatestApprovedPlan();
      final plan = planResult['success'] == true
          ? planResult['data'] as WeeklyWorkoutPlan?
          : await _weeklyWorkoutPlanService.loadLocalPlan();
      final schedule = await _scheduleService.loadForPlan(plan);
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _planLoading = false;
        _planError = planResult['success'] == true
            ? null
            : planResult['error']?.toString();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _planLoading = false;
        _planError = error.toString();
      });
    }
  }

  Future<void> _deleteWorkout(String logId) async {
    try {
      await _workoutLogService.deleteLog(logId);
      await _fetchManualLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting workout: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openWorkoutSession(ManualWorkoutTemplate template) async {
    final result = await Navigator.of(context).push<ManualWorkoutLog>(
      MaterialPageRoute(
        builder: (context) => WorkoutSessionPage(
          template: template,
          logService: _workoutLogService,
        ),
      ),
    );

    if (result != null && mounted) {
      // Refresh logs from local storage
      await _fetchManualLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.workoutType} saved to history'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _syncNow() async {
    await widget.controller.sync(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Workout Tracker',
            style: TextStyle(
              color: isDark ? const Color(0xFFF1F5F9) : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(
            color: isDark ? const Color(0xFFF1F5F9) : Colors.black87,
          ),
          actions: [
            IconButton(
              onPressed: widget.controller.isSyncing ? null : _syncNow,
              tooltip: 'Sync now',
              icon: widget.controller.isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(50),
            child: TabBar(
              indicatorColor: kAccentColor,
              labelColor: kAccentColor,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(icon: Icon(Icons.fitness_center_rounded), text: 'Workouts'),
                Tab(icon: Icon(Icons.flag_rounded), text: 'Goals'),
                Tab(icon: Icon(Icons.history), text: 'Log History'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _ManualWorkoutsTab(
              schedule: _schedule,
              isPlanLoading: _planLoading,
              planError: _planError,
              manualLogs: _manualLogs,
              todaySteps: widget.controller.todaySteps,
              onWorkoutSelected: _openWorkoutSession,
              onToggleTask: _toggleScheduleTask,
              onToggleDay: _toggleScheduleDay,
            ),
            _GoalsTab(
              goals: _savedGoals,
              logs: _manualLogs,
              todaySteps: widget.controller.todaySteps,
              isLoading: _goalsLoading,
              error: _goalsError,
              onRefresh: _loadGoals,
            ),
            _LogHistoryTab(
              controller: widget.controller,
              schedule: _schedule,
              manualLogs: _manualLogs,
              isManualLoading: _manualLogsLoading,
              manualError: _manualLogsError,
              onRefresh: _refreshAllData,
              onDeleteWorkout: _deleteWorkout,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleScheduleTask(
    String dayLabel,
    String taskTitle,
    bool value,
  ) async {
    final plan = _schedule?.plan;
    if (plan == null) return;
    await _scheduleService.toggleTask(
      plan: plan,
      dayLabel: dayLabel,
      taskTitle: taskTitle,
      value: value,
    );
    await _loadWorkoutPlan();
  }

  Future<void> _toggleScheduleDay(String dayLabel, bool value) async {
    final plan = _schedule?.plan;
    if (plan == null) return;
    await _scheduleService.toggleDay(
      plan: plan,
      dayLabel: dayLabel,
      value: value,
    );
    await _loadWorkoutPlan();
  }
}

// --- TAB 1: MANUAL WORKOUTS & CONNECTED GOALS ---
class _ManualWorkoutsTab extends StatelessWidget {
  const _ManualWorkoutsTab({
    required this.onWorkoutSelected,
    required this.onToggleTask,
    required this.onToggleDay,
    required this.manualLogs,
    required this.todaySteps,
    this.schedule,
    this.isPlanLoading = false,
    this.planError,
  });

  final void Function(ManualWorkoutTemplate template) onWorkoutSelected;
  final Future<void> Function(String dayLabel, String taskTitle, bool value)
  onToggleTask;
  final Future<void> Function(String dayLabel, bool value) onToggleDay;
  final WorkoutPlanSchedule? schedule;
  final bool isPlanLoading;
  final String? planError;
  final List<ManualWorkoutLog> manualLogs;
  final int todaySteps;

  @override
  Widget build(BuildContext context) {
    final connectedGoals = activeGoals
        .where((goal) => goal.connectToTracker)
        .toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AiWeeklyPlanCard(
          schedule: schedule,
          isLoading: isPlanLoading,
          error: planError,
          onToggleTask: onToggleTask,
          onToggleDay: onToggleDay,
        ),
        const SizedBox(height: 20),
        Text(
          'Choose a workout',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        ...defaultManualWorkouts.map(
          (template) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _WorkoutTypeCard(
              template: template,
              onTap: () => onWorkoutSelected(template),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Connected Goals',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade400 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        if (connectedGoals.isEmpty)
          const _EmptyGoalsCard()
        else
          ...connectedGoals.map(
            (goal) => _GoalProgressCard(
              goal: goal,
              logs: manualLogs,
              todaySteps: todaySteps,
            ),
          ),
      ],
    );
  }
}

class _AiWeeklyPlanCard extends StatelessWidget {
  const _AiWeeklyPlanCard({
    required this.schedule,
    required this.isLoading,
    required this.error,
    required this.onToggleTask,
    required this.onToggleDay,
  });

  final WorkoutPlanSchedule? schedule;
  final bool isLoading;
  final String? error;
  final Future<void> Function(String dayLabel, String taskTitle, bool value)
  onToggleTask;
  final Future<void> Function(String dayLabel, bool value) onToggleDay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const LinearProgressIndicator(minHeight: 3),
      );
    }

    if (schedule == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Weekly Plan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error?.isNotEmpty == true
                  ? error!
                  : 'Generate a workout in Workout AI and it will appear here with daily rollover and backlog tracking.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final today = schedule!.todayDay;
    final backlog = schedule!.backlogDays;
    final upcoming = schedule!.upcomingDays.take(2).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F4CFF), Color(0xFF2563EB), Color(0xFF4F46E5)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Weekly Plan',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Day changes are automatic. Unfinished older tasks move into backlog instead of disappearing.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (today != null) ...[
            const SizedBox(height: 16),
            _PlanSectionCard(
              title: 'Today • ${today.label}',
              subtitle: today.summary,
              accent: Colors.white,
              tasks: today.tasks,
              onToggleTask: (task, value) async {
                await onToggleTask(today.label, task.title, value);
              },
              onToggleAll: (value) async {
                await onToggleDay(today.label, value);
              },
            ),
          ],
          if (backlog.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...backlog.map(
              (day) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlanSectionCard(
                  title: 'Backlog • ${day.label}',
                  subtitle: day.summary,
                  accent: const Color(0xFFFDE68A),
                  tasks: day.tasks.where((task) => !task.isDone).toList(),
                  onToggleTask: (task, value) async {
                    await onToggleTask(day.label, task.title, value);
                  },
                  onToggleAll: (value) async {
                    await onToggleDay(day.label, value);
                  },
                ),
              ),
            ),
          ],
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Up Next',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ...upcoming.map(
              (day) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${day.label}: ${day.summary}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanSectionCard extends StatelessWidget {
  const _PlanSectionCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.tasks,
    required this.onToggleTask,
    required this.onToggleAll,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final List<WorkoutPlanTask> tasks;
  final Future<void> Function(WorkoutPlanTask task, bool value) onToggleTask;
  final Future<void> Function(bool value) onToggleAll;

  @override
  Widget build(BuildContext context) {
    final allDone = tasks.isNotEmpty && tasks.every((task) => task.isDone);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: allDone,
                onChanged: (value) {
                  onToggleAll(value ?? false);
                },
                activeColor: accent,
                checkColor: Colors.black87,
                side: const BorderSide(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tasks.map(
            (task) => CheckboxListTile(
              value: task.isDone,
              onChanged: (value) {
                onToggleTask(task, value ?? false);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: accent,
              checkColor: Colors.black87,
              title: Text(
                task.title,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: task.isDone ? 0.65 : 0.98,
                  ),
                  decoration: task.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutTypeCard extends StatelessWidget {
  const _WorkoutTypeCard({required this.template, required this.onTap});

  final ManualWorkoutTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: template.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: template.accentColor.withValues(alpha: 0.25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(template.icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    template.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _InfoChip(label: template.difficulty),
                      _InfoChip(
                        label: '${template.met.toStringAsFixed(1)} MET',
                      ),
                      if (template.tracksDistance)
                        const _InfoChip(label: 'GPS Distance'),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

class _EmptyGoalsCard extends StatelessWidget {
  const _EmptyGoalsCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No goals connected yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a personalized goal and connect it to your tracker to view progress here.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Open the Goals tab in Workout Tracker to add your first tracked goal.',
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.swipe_left_rounded, size: 18, color: kAccentColor),
              SizedBox(width: 6),
              Text('Swipe to the Goals tab'),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalsTab extends StatefulWidget {
  const _GoalsTab({
    required this.goals,
    required this.logs,
    required this.todaySteps,
    required this.onRefresh,
    this.isLoading = false,
    this.error,
  });

  final List<Goal> goals;
  final List<ManualWorkoutLog> logs;
  final int todaySteps;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  State<_GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<_GoalsTab> {
  Future<void> _openGoalForm({Goal? goal}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => GoalSetFormView(goalToEdit: goal),
      ),
    );
    if (!mounted) return;
    await widget.onRefresh();
    if (result == true) {
      final message = goal == null
          ? 'Goal saved successfully.'
          : 'Goal updated successfully.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    setState(() {});
  }

  Future<void> _deleteGoal(Goal goal) async {
    final updatedGoals = widget.goals
        .where((item) => item.goalId != goal.goalId)
        .toList();
    await GoalsStorageService().saveGoals(updatedGoals);
    activeGoals
      ..clear()
      ..addAll(updatedGoals);
    if (!mounted) return;
    await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    const progressService = GoalProgressService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.12),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Goals',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _openGoalForm(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Goal'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Goals now live inside Workout Tracker so you can manage plans and tracked progress together.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 16),
          if (widget.goals.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'No goals yet. Create one to track steps, cardio minutes, calories, or distance here.',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
            )
          else
            ...widget.goals.map((goal) {
              final snapshot = progressService.buildSnapshot(
                goal: goal,
                todaySteps: widget.todaySteps,
                logs: widget.logs,
              );
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF111827),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _openGoalForm(goal: goal),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _deleteGoal(goal),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${goal.activityType} • ${snapshot.displayValue} / ${goal.target} ${goal.unit}',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: snapshot.progress,
                      borderRadius: BorderRadius.circular(99),
                      minHeight: 10,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _GoalProgressCard extends StatelessWidget {
  final Goal goal;
  final List<ManualWorkoutLog> logs;
  final int todaySteps;

  const _GoalProgressCard({
    required this.goal,
    required this.logs,
    required this.todaySteps,
  });

  @override
  Widget build(BuildContext context) {
    const progressService = GoalProgressService();
    final snapshot = progressService.buildSnapshot(
      goal: goal,
      todaySteps: todaySteps,
      logs: logs,
    );
    final progress = snapshot.progress;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.15), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${goal.activityType} • Target: ${goal.target} ${goal.unit}',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.isTracked
                ? 'Tracked now: ${snapshot.displayValue} ${goal.unit}'
                : 'Tracked now: unavailable',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: snapshot.isTracked
                  ? kAccentColor
                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(kAccentColor),
            borderRadius: BorderRadius.circular(5),
            minHeight: 10,
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                snapshot.isTracked
                    ? '${(progress * 100).toInt()}% of target'
                    : 'Manual tracking needed',
                style: TextStyle(
                  fontSize: 12,
                  color: snapshot.isTracked
                      ? kAccentColor
                      : (isDark ? Colors.grey.shade400 : Colors.grey),
                ),
              ),
              Text(
                'Due: ${goal.deadline.day}/${goal.deadline.month}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.detail,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// --- TAB 2: LOG HISTORY DISPLAY ---
class _LogHistoryTab extends StatelessWidget {
  const _LogHistoryTab({
    required this.controller,
    required this.schedule,
    required this.manualLogs,
    required this.isManualLoading,
    required this.onRefresh,
    required this.onDeleteWorkout,
    this.manualError,
  });

  final HealthSyncController controller;
  final WorkoutPlanSchedule? schedule;
  final List<ManualWorkoutLog> manualLogs;
  final bool isManualLoading;
  final String? manualError;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String) onDeleteWorkout;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final status = controller.status;

    final manualEntries = manualLogs;
    final wearableEntries = snapshot?.workouts ?? const <WorkoutEntry>[];
    final aiEntries = _buildAiWorkoutEntries();
    final combinedEntries = <_WorkoutEntryWithLog>[
      ...manualEntries.map(
        (log) =>
            _WorkoutEntryWithLog(entry: log.toWorkoutEntry(), manualLog: log),
      ),
      ...aiEntries.map(
        (entry) => _WorkoutEntryWithLog(entry: entry, manualLog: null),
      ),
      ...wearableEntries.map(
        (entry) => _WorkoutEntryWithLog(entry: entry, manualLog: null),
      ),
    ]..sort((a, b) => b.entry.start.compareTo(a.entry.start));

    final hasManual = manualEntries.isNotEmpty;
    final hasWearable = wearableEntries.isNotEmpty;
    final hasAi = aiEntries.isNotEmpty;

    if (status == HealthSyncStatus.syncing &&
        snapshot == null &&
        !hasManual &&
        isManualLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot == null && !hasManual && !hasAi) {
      return _EmptyState(
        icon: Icons.watch,
        title: 'Connect to your watch',
        description:
            'Sync with your Galaxy Watch to see workouts captured in Samsung Health.',
        actionLabel: 'Sync Now',
        onActionPressed: controller.isSyncing
            ? null
            : () => controller.sync(force: true),
      );
    }

    if (!hasManual && !hasWearable && !hasAi) {
      return _EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No workouts yet',
        description:
            'Start a manual session, complete an AI workout day, or sync with your wearable to see workouts here.',
        actionLabel: 'Refresh',
        onActionPressed: controller.isSyncing ? null : () => onRefresh(),
      );
    }

    final children = <Widget>[];

    if (manualError != null) {
      children.add(_ManualLogsBanner(message: manualError!, isError: true));
    } else if (isManualLoading) {
      children.add(
        const _ManualLogsBanner(message: 'Refreshing manual workouts…'),
      );
    }

    for (final item in combinedEntries) {
      children.add(
        _WorkoutLogTile(
          entry: item.entry,
          manualLog: item.manualLog,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => WorkoutDetailsPage(
                  entry: item.entry,
                  manualLog: item.manualLog,
                  onDelete: item.manualLog != null
                      ? () async {
                          await onDeleteWorkout(item.manualLog!.id);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      : null,
                ),
              ),
            );
          },
          onDelete: item.manualLog != null
              ? () => onDeleteWorkout(item.manualLog!.id)
              : null,
        ),
      );
    }

    if (children.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(
            child: Text(
              'No workouts logged yet.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20.0),
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }

  List<WorkoutEntry> _buildAiWorkoutEntries() {
    final activeSchedule = schedule;
    if (activeSchedule == null) return const <WorkoutEntry>[];

    return activeSchedule.days
        .where((day) => day.isComplete && day.completedAt != null)
        .map((day) => day.toWorkoutEntry(activeSchedule.plan))
        .toList();
  }
}

class _WorkoutEntryWithLog {
  const _WorkoutEntryWithLog({required this.entry, this.manualLog});

  final WorkoutEntry entry;
  final ManualWorkoutLog? manualLog;
}

class _WorkoutLogTile extends StatelessWidget {
  const _WorkoutLogTile({
    required this.entry,
    this.manualLog,
    this.onTap,
    this.onDelete,
  });

  final WorkoutEntry entry;
  final ManualWorkoutLog? manualLog;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final durationLabel = _formatDuration(entry.duration);
    final distanceLabel = entry.distanceKm != null
        ? '${entry.distanceKm!.toStringAsFixed(entry.distanceKm! >= 10 ? 1 : 2)} km'
        : 'Distance not logged';
    final energyLabel = entry.energyKcal != null && entry.energyKcal! > 0
        ? '${entry.energyKcal!.toStringAsFixed(0)} kcal'
        : null;
    final stepsLabel = entry.steps != null && entry.steps! > 0
        ? '${entry.steps} steps'
        : null;
    final dateLabel = DateFormat('EEE, MMM d • h:mm a').format(entry.start);

    final details = <String>[
      distanceLabel,
      if (stepsLabel != null) stepsLabel,
      if (energyLabel != null) 'Energy: $energyLabel',
      'Source: ${entry.sourceName}',
      dateLabel,
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.12), blurRadius: 6),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _iconForWorkout(entry.typeLabel),
                color: kPrimaryColor,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.typeLabel} • $durationLabel',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark
                            ? const Color(0xFFF1F5F9)
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      details.join('\n'),
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _showDeleteDialog(context),
                  tooltip: 'Delete workout',
                ),
              const Icon(Icons.chevron_right, color: kPrimaryColor),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes min';
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout?'),
        content: const Text(
          'This workout will be permanently deleted from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  static IconData _iconForWorkout(String workoutType) {
    final normalized = workoutType.toLowerCase();
    if (normalized.contains('run') || normalized.contains('walk')) {
      return Icons.directions_run;
    }
    if (normalized.contains('cycle') || normalized.contains('bike')) {
      return Icons.pedal_bike;
    }
    if (normalized.contains('swim')) {
      return Icons.pool;
    }
    if (normalized.contains('yoga')) {
      return Icons.self_improvement;
    }
    if (normalized.contains('strength') || normalized.contains('weight')) {
      return Icons.fitness_center;
    }
    return Icons.monitor_heart;
  }
}

class _ManualLogsBanner extends StatelessWidget {
  const _ManualLogsBanner({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFEFEF) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? const Color(0xFFFF6B6B) : const Color(0xFFCBD5F5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.warning_amber_rounded : Icons.info_outline,
            color: isError ? const Color(0xFFDC2626) : const Color(0xFF475569),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: isError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension ManualWorkoutLogMapper on ManualWorkoutLog {
  WorkoutEntry toWorkoutEntry() {
    return WorkoutEntry(
      typeLabel: workoutType,
      start: startTime,
      end: startTime.add(Duration(seconds: durationSeconds)),
      sourceName: 'Manual Log',
      distanceKm: distanceKm,
      energyKcal: calories,
      steps: null,
    );
  }
}

extension WorkoutPlanDayHistoryMapper on WorkoutPlanDay {
  WorkoutEntry toWorkoutEntry(WeeklyWorkoutPlan plan) {
    final completed = completedAt ?? DateTime.now();
    final minutes = _estimatePlanDurationMinutes(plan.duration);
    final type = summary.trim().isEmpty ? 'AI Workout' : summary.trim();
    return WorkoutEntry(
      typeLabel: '$type (${label})',
      start: completed,
      end: completed.add(Duration(minutes: minutes)),
      sourceName: 'Workout AI Plan',
      distanceKm: null,
      energyKcal: null,
      steps: null,
    );
  }
}

int _estimatePlanDurationMinutes(String rawDuration) {
  final match = RegExp(r'(\d+)').firstMatch(rawDuration);
  final parsed = int.tryParse(match?.group(1) ?? '');
  if (parsed == null || parsed <= 0) return 30;
  return parsed.clamp(10, 180);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final Future<void> Function()? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onActionPressed == null
                    ? null
                    : () async => await onActionPressed!(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
