// personalized_goals_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../services/goals_storage_service.dart';
import '../services/weekly_workout_plan_service.dart';
import '../services/workout_log_service.dart';

// --- Global Constants ---
const Color kPrimaryColor = Color(0xFF4C5BF1);
const Color kBackgroundColor = Color(0xFFF7F8FC);
const Color kAccentColor = Color(0xFFFFA500); // Orange for Goals

// --- GLOBAL Goal Model and Storage (Simplified) ---
class Goal {
  final String goalId;
  final String name;
  final String activityType;
  final String target;
  final String unit;
  final DateTime deadline;
  final DateTime reminderTime;
  final bool connectToTracker;

  Goal({
    required this.goalId,
    required this.name,
    required this.activityType,
    required this.target,
    required this.unit,
    required this.deadline,
    required this.reminderTime,
    required this.connectToTracker,
  });
}

// Global storage list. Data will NOT be saved between sessions.
List<Goal> activeGoals = [];
// --- END GLOBAL ---

const List<String> _activityCategories = [
  'Steps',
  'Water Intake',
  'Cardio Minutes',
  'Calorie Burn',
  'Weight Loss',
  'Distance (km)',
];

// ******************************************************
// --- 1. PersonalizedGoalsView (The Home/List Screen) ---
// ******************************************************

class PersonalizedGoalsView extends StatefulWidget {
  const PersonalizedGoalsView({super.key});

  @override
  State<PersonalizedGoalsView> createState() => _PersonalizedGoalsViewState();
}

class _PersonalizedGoalsViewState extends State<PersonalizedGoalsView> {
  late final _GoalNotificationController _goalNotificationController;
  final WeeklyWorkoutPlanService _weeklyWorkoutPlanService =
      WeeklyWorkoutPlanService();
  final WorkoutLogService _workoutLogService = WorkoutLogService();
  WeeklyWorkoutPlan? _approvedWeeklyPlan;
  List<ManualWorkoutLog> _completedLogs = const [];
  bool _workoutDataLoading = false;
  String? _workoutDataError;

  @override
  void initState() {
    super.initState();
    _goalNotificationController = _GoalNotificationController();
    _loadGoals();
    _loadWorkoutData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> refreshGoalNotifications() async {
    await _goalNotificationController.syncGoals(activeGoals);
  }

  Future<void> cancelGoalNotification(String goalId) async {
    await _goalNotificationController.cancelGoal(goalId);
  }

  Future<bool> scheduleGoalReminder(Goal goal) {
    return _goalNotificationController.scheduleGoal(goal);
  }

  Future<void> _loadWorkoutData() async {
    setState(() {
      _workoutDataLoading = true;
      _workoutDataError = null;
    });
    try {
      final planResult = await _weeklyWorkoutPlanService
          .getLatestApprovedPlan();
      final logs = await _workoutLogService.fetchLogs(limit: 100);
      if (!mounted) return;
      setState(() {
        _approvedWeeklyPlan = planResult['success'] == true
            ? planResult['data'] as WeeklyWorkoutPlan?
            : null;
        _completedLogs = logs;
        _workoutDataLoading = false;
        final planError = planResult['error']?.toString();
        _workoutDataError = (planError != null && planError.isNotEmpty)
            ? planError
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workoutDataLoading = false;
        _workoutDataError = e.toString();
      });
    }
  }

  List<_ScheduledWorkoutDay> _extractWeeklySchedule(WeeklyWorkoutPlan plan) {
    final lines = plan.planText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final List<_ScheduledWorkoutDay> days = [];
    _ScheduledWorkoutDay? current;
    final dayRegex = RegExp(
      r'^-?\s*Day\s+(\d+)\s*:\s*(.+)$',
      caseSensitive: false,
    );

    for (final rawLine in lines) {
      final line = rawLine.startsWith('- ')
          ? rawLine.substring(2).trim()
          : rawLine;
      final match = dayRegex.firstMatch(line);
      if (match != null) {
        if (current != null) {
          days.add(current);
        }
        current = _ScheduledWorkoutDay(
          dayNumber: int.tryParse(match.group(1) ?? '') ?? 0,
          title: (match.group(2) ?? '').trim(),
          details: <String>[],
        );
        continue;
      }
      if (current != null) {
        current.details.add(line);
      }
    }
    if (current != null) {
      days.add(current);
    }
    days.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    return days;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Load goals from local storage
  Future<void> _loadGoals() async {
    final storage = GoalsStorageService();
    final savedGoals = await storage.loadGoals();

    setState(() {
      activeGoals.clear();
      activeGoals.addAll(savedGoals);
    });

    await refreshGoalNotifications();
  }

  /// Save goals to local storage
  Future<void> _saveGoals() async {
    final storage = GoalsStorageService();
    await storage.saveGoals(activeGoals);
  }

  // NOTE: Persistence methods (_loadGoals, _saveGoals, _deleteGoal)
  // have been simplified below to only manage the in-memory list.

  // --- DELETE Goal Logic (simplified) ---
  Future<void> _deleteGoal(String goalId) async {
    await cancelGoalNotification(goalId);

    setState(() {
      activeGoals.removeWhere((goal) => goal.goalId == goalId);
    });

    // Save to local storage
    await _saveGoals();
    await refreshGoalNotifications();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Goal deleted successfully.')));
  }

  // Method to navigate to the form and refresh the list upon return
  void _navigateToAddOrEditGoal(
    BuildContext context, {
    Goal? goalToEdit,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoalSetFormView(goalToEdit: goalToEdit),
      ),
    );
    // Reload goals from storage and refresh the list
    // Only reschedule if goals actually changed (avoid unnecessary rescheduling)
    final storage = GoalsStorageService();
    final savedGoals = await storage.loadGoals();

    setState(() {
      activeGoals.clear();
      activeGoals.addAll(savedGoals);
    });

    await refreshGoalNotifications();
    await _loadWorkoutData();
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _approvedWeeklyPlan == null
        ? <_ScheduledWorkoutDay>[]
        : _extractWeeklySchedule(_approvedWeeklyPlan!);
    final now = _dateOnly(DateTime.now());
    final planAnchor =
        _approvedWeeklyPlan?.approvedAt ??
        _approvedWeeklyPlan?.createdAt ??
        DateTime.now();
    final anchorDate = _dateOnly(planAnchor);
    final dayOffset = now.difference(anchorDate).inDays;
    final todayDayNumber = dayOffset + 1;

    _ScheduledWorkoutDay? todayWorkout;
    final upcoming = <_ScheduledWorkoutDay>[];
    for (final day in schedule) {
      if (day.dayNumber == todayDayNumber) {
        todayWorkout = day;
      } else if (day.dayNumber > todayDayNumber) {
        upcoming.add(day);
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'My Active Goals',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFF1F5F9)
                : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFF1F5F9)
              : Colors.black87,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadGoals();
          await _loadWorkoutData();
        },
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            if (_workoutDataLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            _WorkoutScheduleSection(
              todayWorkout: todayWorkout,
              upcomingWorkouts: upcoming,
              anchorDate: anchorDate,
              workoutDataError: _workoutDataError,
            ),
            const SizedBox(height: 18),
            _CompletedWorkoutHistorySection(logs: _completedLogs),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.flag_rounded, color: Colors.orange.shade500),
                const SizedBox(width: 8),
                Text(
                  'My Active Goals',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (activeGoals.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Tap + to set your first goal!'),
              )
            else
              ...activeGoals.map(
                (goal) => _GoalCard(
                  goal: goal,
                  onEdit: () =>
                      _navigateToAddOrEditGoal(context, goalToEdit: goal),
                  onDelete: () => _deleteGoal(goal.goalId),
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 90),
          ],
        ),
      ),

      // --- Floating Action Button (FAB) ---
      floatingActionButton: FloatingActionButton(
        heroTag: "add_goal",
        onPressed: () => _navigateToAddOrEditGoal(context), // Create new goal
        backgroundColor: kAccentColor,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}

class _ScheduledWorkoutDay {
  _ScheduledWorkoutDay({
    required this.dayNumber,
    required this.title,
    required this.details,
  });

  final int dayNumber;
  final String title;
  final List<String> details;
}

class _WorkoutScheduleSection extends StatelessWidget {
  const _WorkoutScheduleSection({
    required this.todayWorkout,
    required this.upcomingWorkouts,
    required this.anchorDate,
    this.workoutDataError,
  });

  final _ScheduledWorkoutDay? todayWorkout;
  final List<_ScheduledWorkoutDay> upcomingWorkouts;
  final DateTime anchorDate;
  final String? workoutDataError;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Workout Schedule',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Plan start: ${DateFormat('EEE, MMM d').format(anchorDate)}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          if (todayWorkout == null)
            _emptyInfo(
              context,
              'No workout assigned for today. Generate/approve a fresh weekly plan.',
            )
          else
            _dayCard(
              context: context,
              title: 'Today',
              day: todayWorkout!,
              isToday: true,
            ),
          const SizedBox(height: 12),
          Text(
            'Upcoming Workouts',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          if (upcomingWorkouts.isEmpty)
            _emptyInfo(context, 'No upcoming items in the current weekly plan.')
          else
            ...upcomingWorkouts
                .take(6)
                .map(
                  (day) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _dayCard(
                      context: context,
                      title: 'Day ${day.dayNumber}',
                      day: day,
                    ),
                  ),
                ),
          if (workoutDataError != null && workoutDataError!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              workoutDataError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyInfo(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _dayCard({
    required BuildContext context,
    required String title,
    required _ScheduledWorkoutDay day,
    bool isToday = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday
            ? (isDark ? const Color(0xFF1D4ED8) : const Color(0xFFDBEAFE))
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF93C5FD))
              : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ${day.title}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isToday
                  ? (isDark ? Colors.white : const Color(0xFF1E3A8A))
                  : (isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF1F2937)),
            ),
          ),
          if (day.details.isNotEmpty) const SizedBox(height: 6),
          ...day.details
              .take(3)
              .map(
                (detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $detail',
                    style: TextStyle(
                      fontSize: 12,
                      color: isToday
                          ? (isDark
                                ? Colors.white.withValues(alpha: 0.95)
                                : const Color(0xFF1E40AF))
                          : (isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _CompletedWorkoutHistorySection extends StatelessWidget {
  const _CompletedWorkoutHistorySection({required this.logs});

  final List<ManualWorkoutLog> logs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recent = logs.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completed Workout History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            Text(
              'No completed workouts yet.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            )
          else
            ...recent
                .take(10)
                .map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Colors.green.shade500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${DateFormat('EEE, MMM d').format(log.startTime)}: ${log.workoutType} (${(log.durationSeconds / 60).round()} min)',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF1F2937),
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

// Helper Widget to display individual goals in the list
class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.onEdit,
    required this.onDelete,
  });

  // Modal to show Edit/Delete options
  void _showActionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit, color: kPrimaryColor),
                title: const Text('Edit Goal'),
                onTap: () {
                  Navigator.pop(bc);
                  onEdit();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Goal'),
                onTap: () {
                  Navigator.pop(bc);
                  onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Date format: dd/mm/yyyy
    String formattedDeadline =
        '${goal.deadline.day.toString().padLeft(2, '0')}/${goal.deadline.month.toString().padLeft(2, '0')}/${goal.deadline.year} at ${TimeOfDay.fromDateTime(goal.deadline).format(context)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Icon(
          Icons.flag,
          color: goal.connectToTracker ? kPrimaryColor : kAccentColor,
          size: 40,
        ),
        title: Text(
          '${goal.name} (${goal.target} ${goal.unit})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              'Due: $formattedDeadline',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            Text(
              goal.connectToTracker
                  ? 'Status: Connected to Tracker'
                  : 'Status: Standalone Goal',
              style: TextStyle(
                color: goal.connectToTracker
                    ? Colors.green.shade600
                    : Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.more_vert,
          size: 24,
        ), // Three dots for options
        onTap: () => _showActionModal(context), // Open action modal on tap
      ),
    );
  }
}

// ****************************************************
// --- 2. GoalSetFormView (The Form Screen, now handles Edit) ---
// ****************************************************

class GoalSetFormView extends StatefulWidget {
  final Goal? goalToEdit; // Optional: if provided, this is an edit operation

  const GoalSetFormView({super.key, this.goalToEdit});

  @override
  State<GoalSetFormView> createState() => _GoalSetFormViewState();
}

class _GoalSetFormViewState extends State<GoalSetFormView> {
  // State variables declared late, initialized in initState
  late String? _selectedActivity;
  late TextEditingController _targetValueController;
  late TextEditingController _goalNameController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late bool _connectToTracker;
  late String _currentGoalId;

  late DateTime _goalDeadline;

  // Reference to the persistence methods on the parent state
  _PersonalizedGoalsViewState? get _parentState =>
      context.findAncestorStateOfType<_PersonalizedGoalsViewState>();

  @override
  void initState() {
    super.initState();

    final isEditing = widget.goalToEdit != null;
    final goal = widget.goalToEdit;

    // --- Core Initialization ---
    final now = DateTime.now();

    _currentGoalId = isEditing ? goal!.goalId : UniqueKey().toString();
    _goalNameController = TextEditingController(
      text: isEditing ? goal!.name : 'Daily Goal',
    );
    _targetValueController = TextEditingController(
      text: isEditing ? goal!.target : '10',
    );
    _selectedActivity = isEditing
        ? goal!.activityType
        : _activityCategories.last;

    // Safely set Date and Time
    _selectedDate =
        isEditing &&
            goal!.deadline.isAfter(
              now.subtract(const Duration(days: 365)),
            ) // Check if date is reasonable
        ? goal.deadline
        : now.add(const Duration(days: 1));

    _selectedTime =
        isEditing &&
            goal!.deadline.isAfter(
              now.subtract(const Duration(hours: 1)),
            ) // Check if time is reasonable
        ? TimeOfDay.fromDateTime(goal.deadline)
        : const TimeOfDay(hour: 20, minute: 0);

    _connectToTracker = isEditing ? goal!.connectToTracker : true;

    _updateDeadline();
  }

  @override
  void dispose() {
    _targetValueController.dispose();
    _goalNameController.dispose();
    super.dispose();
  }

  void _updateDeadline() {
    _goalDeadline = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  // --- Helper to match unit back to activity name for dropdown ---
  String? _getUnitFromValue(String unit) {
    for (String activity in _activityCategories) {
      if (_getUnit(activity) == unit) {
        return activity;
      }
    }
    return null;
  }

  // --- Date/Time Pickers (omitted for brevity, remains the same) ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(DateTime.now())
          ? DateTime.now().add(const Duration(days: 1))
          : _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimaryColor),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateDeadline();
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimaryColor),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _updateDeadline();
      });
    }
  }

  String _getUnit(String? activity) {
    switch (activity) {
      case 'Steps':
        return 'steps';
      case 'Water Intake':
        return 'ml';
      case 'Cardio Minutes':
        return 'minutes';
      case 'Calorie Burn':
        return 'calories';
      case 'Weight Loss':
        return 'kg/lbs';
      case 'Distance (km)':
        return 'km';
      default:
        return '';
    }
  }

  // --- Goal Setting/Updating Logic ---
  Future<void> _setGoal() async {
    if (_goalNameController.text.isEmpty ||
        _targetValueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in the Goal Name and Target Value.'),
        ),
      );
      return;
    }

    _updateDeadline();
    final DateTime notificationTime = _goalDeadline.subtract(
      const Duration(hours: 1),
    );
    final String unit = _getUnit(_selectedActivity);

    final newOrUpdatedGoal = Goal(
      goalId: _currentGoalId,
      name: _goalNameController.text,
      activityType: _selectedActivity ?? 'Steps',
      target: _targetValueController.text,
      unit: unit,
      deadline: _goalDeadline,
      reminderTime: notificationTime,
      connectToTracker: _connectToTracker,
    );

    // Check if editing or creating
    final existingIndex = activeGoals.indexWhere(
      (g) => g.goalId == _currentGoalId,
    );

    if (existingIndex >= 0) {
      activeGoals[existingIndex] = newOrUpdatedGoal;
    } else {
      activeGoals.add(newOrUpdatedGoal);
    }

    // Save goals to local storage first
    final storage = GoalsStorageService();
    await storage.saveGoals(activeGoals);
    print('💾 Goals saved to local storage');

    await _parentState?.scheduleGoalReminder(newOrUpdatedGoal);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final String actionText = widget.goalToEdit != null ? 'UPDATE' : 'SET';
    // Date format: dd/mm/yyyy
    String formattedDate =
        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          '${actionText} Goal',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildGoalInputCard(
              title: 'Goal Name',
              child: TextField(
                controller: _goalNameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Daily Step Goal',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            _buildGoalInputCard(
              title: 'Activity Type',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedActivity,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: kPrimaryColor),
                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                  items: _activityCategories.map<DropdownMenuItem<String>>((
                    String value,
                  ) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedActivity = newValue;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildGoalInputCard(
              title: 'Target Value (${_getUnit(_selectedActivity)})',
              child: TextField(
                controller: _targetValueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter target value',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  suffixText: _getUnit(_selectedActivity),
                  suffixStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 18,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- Deadline Selector (Date & Time) ---
            const Text(
              'Goal Deadline & Reminder',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildDateSelector(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: formattedDate,
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(width: 15),
                _buildDateSelector(
                  icon: Icons.access_time,
                  label: 'Time',
                  value: _selectedTime.format(context),
                  onTap: () => _selectTime(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildReminderInfo(),
            const SizedBox(height: 30),

            // --- Connect to Tracker Option ---
            _buildConnectTrackerOption(),
            const SizedBox(height: 40),

            // --- Set Goal Button ---
            ElevatedButton.icon(
              onPressed: _setGoal,
              icon: Icon(
                widget.goalToEdit != null
                    ? Icons.save
                    : Icons.check_circle_outline,
                color: Colors.white,
              ),
              label: Text(
                '${actionText} GOAL & NOTIFICATION',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildConnectTrackerOption() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _connectToTracker ? kAccentColor : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SwitchListTile(
        title: const Text(
          'Connect to Workout Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Display this goal directly in your workout tracking screen.',
        ),
        value: _connectToTracker,
        activeColor: kAccentColor,
        onChanged: (bool value) {
          setState(() {
            _connectToTracker = value;
          });
        },
      ),
    );
  }

  Widget _buildGoalInputCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, color: kPrimaryColor),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: kAccentColor, size: 20),
          const SizedBox(width: 8),
          Text(
            'You will be notified 1 hour before the deadline.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _GoalNotificationController {
  final NotificationService _notificationService = NotificationService();
  bool _initialized = false;
  bool _syncInProgress = false;
  final Map<String, DateTime> _lastScheduledAt = {};

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _notificationService.initialize();
    _initialized = true;
  }

  Future<void> syncGoals(List<Goal> goals) async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      await _ensureInitialized();
      final activeIds = <String>{};
      for (final goal in goals) {
        activeIds.add(goal.goalId);
        await scheduleGoal(goal);
      }

      final staleIds = _lastScheduledAt.keys.where(
        (id) => !activeIds.contains(id),
      );

      for (final goalId in staleIds.toList()) {
        await cancelGoal(goalId);
      }
    } finally {
      _syncInProgress = false;
    }
  }

  Future<bool> scheduleGoal(Goal goal) async {
    await _ensureInitialized();
    final now = DateTime.now();

    if (!goal.deadline.isAfter(now)) {
      await cancelGoal(goal.goalId);
      return false;
    }

    DateTime reminderTime = goal.reminderTime;
    if (reminderTime.isBefore(now)) {
      reminderTime = now.add(const Duration(minutes: 1));
    }

    final notificationId = NotificationService.stableIdFromKey(
      goal.goalId,
      scope: 'goal',
    );

    final scheduled = await _notificationService.scheduleNotification(
      id: notificationId,
      title: 'Goal Reminder: ${goal.name}',
      body:
          'You have 1 hour left to complete your goal: ${goal.target} ${goal.unit}',
      scheduledDate: reminderTime,
      payload: goal.goalId,
    );

    if (scheduled) {
      _lastScheduledAt[goal.goalId] = reminderTime;
    } else {
      _lastScheduledAt.remove(goal.goalId);
    }
    return scheduled;
  }

  Future<void> cancelGoal(String goalId) async {
    await _ensureInitialized();
    final notificationId = NotificationService.stableIdFromKey(
      goalId,
      scope: 'goal',
    );
    await _notificationService.cancelNotification(notificationId);
    _lastScheduledAt.remove(goalId);
  }
}
