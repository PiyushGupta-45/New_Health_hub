// personalized_goals_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/notification_service.dart';
import '../services/goals_storage_service.dart';

// --- Global Constants ---
const Color
kPrimaryColor = Color(
  0xFF4C5BF1,
);
const Color
kBackgroundColor = Color(
  0xFFF7F8FC,
);
const Color
kAccentColor = Color(
  0xFFFFA500,
); // Orange for Goals

// --- GLOBAL Goal Model and Storage (Simplified) ---
class Goal {
  final String goalId;
  final String name;
  final String target;
  final String unit;
  final DateTime deadline;
  final DateTime reminderTime;
  final bool connectToTracker;

  Goal({
    required this.goalId,
    required this.name,
    required this.target,
    required this.unit,
    required this.deadline,
    required this.reminderTime,
    required this.connectToTracker,
  });
}

// Global storage list. Data will NOT be saved between sessions.
List<
  Goal
>
activeGoals = [];
// --- END GLOBAL ---

const List<
  String
>
_activityCategories = [
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

class PersonalizedGoalsView
    extends
        StatefulWidget {
  const PersonalizedGoalsView({
    super.key,
  });

  @override
  State<
    PersonalizedGoalsView
  >
  createState() => _PersonalizedGoalsViewState();
}

class _PersonalizedGoalsViewState
    extends
        State<
          PersonalizedGoalsView
        > {
  // Flag removed, as we no longer wait for loading

  Timer? _notificationCheckTimer;
  final Map<
    String,
    DateTime
  >
  _fallbackReminderShownAt = {};
  final Set<
    String
  >
  _goalsWithScheduledNotifications = {};

  @override
  void initState() {
    super.initState();
    _loadGoals();
    // Start periodic check for notifications when app is open
    _startNotificationChecker();
  }

  @override
  void dispose() {
    _notificationCheckTimer?.cancel();
    super.dispose();
  }

  /// Periodically check if any goal notifications should be shown
  /// This is a fallback in case Android blocks scheduled notifications
  void _startNotificationChecker() {
    _notificationCheckTimer = Timer.periodic(
      const Duration(
        seconds: 30,
      ),
      (
        timer,
      ) {
        _checkAndShowPendingNotifications();
      },
    );
  }

  void _updateGoalScheduleStatus(
    String goalId,
    bool scheduled,
  ) {
    if (scheduled) {
      _goalsWithScheduledNotifications.add(
        goalId,
      );
    } else {
      _goalsWithScheduledNotifications.remove(
        goalId,
      );
    }
  }

  /// Check if any goal reminders are due and show them
  /// This is a fallback in case Android blocks scheduled notifications
  Future<
    void
  >
  _checkAndShowPendingNotifications() async {
    final now = DateTime.now();
    final notificationService = NotificationService();
    await notificationService.initialize();
    final pendingIds = (await notificationService.getPendingNotifications())
        .map(
          (
            n,
          ) => n.id,
        )
        .toSet();

    for (var goal in activeGoals) {
      if (_goalsWithScheduledNotifications.contains(
        goal.goalId,
      )) {
        continue;
      }

      final reminderId = NotificationService.stableIdFromKey(
        goal.goalId,
        scope: 'goal',
      );
      // Skip fallback if the platform still has a pending scheduled notification
      if (pendingIds.contains(
        reminderId,
      )) {
        continue;
      }

      // Check if reminder time has passed (within last 5 minutes to avoid duplicates)
      final timeDiff = now.difference(
        goal.reminderTime,
      );
      final alreadyShownTime = _fallbackReminderShownAt[goal.goalId];
      final reminderAlreadyShown =
          alreadyShownTime !=
              null &&
          alreadyShownTime.isAtSameMomentAs(
            goal.reminderTime,
          );

      if (!timeDiff.isNegative &&
          timeDiff <=
              const Duration(
                minutes: 5,
              ) &&
          !reminderAlreadyShown) {
        // Show the actual goal reminder notification
        final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'goal_reminders',
          'Goal Reminders',
          channelDescription: 'Notifications for goal reminders',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

        final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        final NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );
        final fallbackId = NotificationService.stableIdFromKey(
          goal.goalId,
          scope: 'goal_fallback',
        );

        await notificationService.notifications.show(
          fallbackId,
          'Goal Reminder: ${goal.name}',
          'You have 1 hour left to complete your goal: ${goal.target} ${goal.unit}',
          notificationDetails,
        );
        _fallbackReminderShownAt[goal.goalId] = goal.reminderTime;

        print(
          '🔔 Showing reminder for goal: ${goal.name} (fallback method)',
        );
      }
    }
  }

  /// Load goals from local storage
  Future<
    void
  >
  _loadGoals() async {
    final storage = GoalsStorageService();
    final savedGoals = await storage.loadGoals();

    setState(
      () {
        activeGoals.clear();
        activeGoals.addAll(
          savedGoals,
        );
        _goalsWithScheduledNotifications.clear();
      },
    );

    // Reschedule notifications for all loaded goals
    await _rescheduleAllNotifications();
  }

  /// Save goals to local storage
  Future<
    void
  >
  _saveGoals() async {
    final storage = GoalsStorageService();
    await storage.saveGoals(
      activeGoals,
    );
  }

  /// Reschedule notifications for all active goals
  Future<
    void
  >
  _rescheduleAllNotifications() async {
    final notificationService = NotificationService();
    // Ensure notification service is initialized
    await notificationService.initialize();

    final now = DateTime.now();

    for (var goal in activeGoals) {
      // Only reschedule if reminder time is in the future
      if (goal.reminderTime.isAfter(
        now,
      )) {
        print(
          '🔄 Rescheduling notification for goal: ${goal.name}',
        );
        print(
          '   Reminder time: ${goal.reminderTime}',
        );
        print(
          '   Current time: $now',
        );
        print(
          '   Time until: ${goal.reminderTime.difference(now).inMinutes} minutes',
        );
        final notificationId = NotificationService.stableIdFromKey(
          goal.goalId,
          scope: 'goal',
        );

        final scheduled = await notificationService.scheduleNotification(
          id: notificationId,
          title: 'Goal Reminder: ${goal.name}',
          body: 'You have 1 hour left to complete your goal: ${goal.target} ${goal.unit}',
          scheduledDate: goal.reminderTime,
          payload: goal.goalId,
        );

        if (scheduled) {
          print(
            '✅ Rescheduled notification for goal: ${goal.name}',
          );
          _updateGoalScheduleStatus(
            goal.goalId,
            true,
          );
        } else {
          print(
            '⚠️ Failed to reschedule notification for goal: ${goal.name}',
          );
          _updateGoalScheduleStatus(
            goal.goalId,
            false,
          );
        }
      } else {
        print(
          '⏭️ Skipped past reminder for goal: ${goal.name} (${goal.reminderTime})',
        );
        _updateGoalScheduleStatus(
          goal.goalId,
          false,
        );
      }
    }
  }

  // NOTE: Persistence methods (_loadGoals, _saveGoals, _deleteGoal)
  // have been simplified below to only manage the in-memory list.

  // --- DELETE Goal Logic (simplified) ---
  Future<
    void
  >
  _deleteGoal(
    String goalId,
  ) async {
    // Cancel notification before deleting
    final notificationId = NotificationService.stableIdFromKey(
      goalId,
      scope: 'goal',
    );
    await NotificationService().cancelNotification(
      notificationId,
    );
    _updateGoalScheduleStatus(
      goalId,
      false,
    );

    setState(
      () {
        activeGoals.removeWhere(
          (
            goal,
          ) =>
              goal.goalId ==
              goalId,
        );
      },
    );

    // Save to local storage
    await _saveGoals();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content: Text(
          'Goal deleted successfully.',
        ),
      ),
    );
  }

  // Method to navigate to the form and refresh the list upon return
  void _navigateToAddOrEditGoal(
    BuildContext context, {
    Goal? goalToEdit,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (
              context,
            ) => GoalSetFormView(
              goalToEdit: goalToEdit,
            ),
      ),
    );
    // Reload goals from storage and refresh the list
    await _loadGoals();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Active Goals',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
      ),
      body: activeGoals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  const Text(
                    'Tap + to set your first goal!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(
                20.0,
              ),
              itemCount: activeGoals.length,
              itemBuilder:
                  (
                    context,
                    index,
                  ) {
                    final goal = activeGoals[index];
                    return _GoalCard(
                      goal: goal,
                      onEdit: () => _navigateToAddOrEditGoal(
                        context,
                        goalToEdit: goal,
                      ),
                      onDelete: () => _deleteGoal(
                        goal.goalId,
                      ),
                    );
                  },
            ),

      // --- Floating Action Button (FAB) ---
      floatingActionButton: FloatingActionButton(
        heroTag: "add_goal",
        onPressed: () => _navigateToAddOrEditGoal(
          context,
        ), // Create new goal
        backgroundColor: kAccentColor,
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

// Helper Widget to display individual goals in the list
class _GoalCard
    extends
        StatelessWidget {
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.onEdit,
    required this.onDelete,
  });

  // Modal to show Edit/Delete options
  void _showActionModal(
    BuildContext context,
  ) {
    showModalBottomSheet(
      context: context,
      builder:
          (
            BuildContext bc,
          ) {
            return SafeArea(
              child: Wrap(
                children:
                    <
                      Widget
                    >[
                      ListTile(
                        leading: const Icon(
                          Icons.edit,
                          color: kPrimaryColor,
                        ),
                        title: const Text(
                          'Edit Goal',
                        ),
                        onTap: () {
                          Navigator.pop(
                            bc,
                          );
                          onEdit();
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                        title: const Text(
                          'Delete Goal',
                        ),
                        onTap: () {
                          Navigator.pop(
                            bc,
                          );
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
  Widget build(
    BuildContext context,
  ) {
    // Date format: dd/mm/yyyy
    String formattedDeadline = '${goal.deadline.day.toString().padLeft(2, '0')}/${goal.deadline.month.toString().padLeft(2, '0')}/${goal.deadline.year} at ${TimeOfDay.fromDateTime(goal.deadline).format(context)}';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          15,
        ),
      ),
      elevation: 3,
      child: ListTile(
        contentPadding: const EdgeInsets.all(
          15,
        ),
        leading: Icon(
          Icons.flag,
          color: goal.connectToTracker
              ? kPrimaryColor
              : kAccentColor,
          size: 40,
        ),
        title: Text(
          '${goal.name} (${goal.target} ${goal.unit})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 5,
            ),
            Text(
              'Due: $formattedDeadline',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
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
        onTap: () => _showActionModal(
          context,
        ), // Open action modal on tap
      ),
    );
  }
}

// ****************************************************
// --- 2. GoalSetFormView (The Form Screen, now handles Edit) ---
// ****************************************************

class GoalSetFormView
    extends
        StatefulWidget {
  final Goal? goalToEdit; // Optional: if provided, this is an edit operation

  const GoalSetFormView({
    super.key,
    this.goalToEdit,
  });

  @override
  State<
    GoalSetFormView
  >
  createState() => _GoalSetFormViewState();
}

class _GoalSetFormViewState
    extends
        State<
          GoalSetFormView
        > {
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
  _PersonalizedGoalsViewState? get _parentState => context
      .findAncestorStateOfType<
        _PersonalizedGoalsViewState
      >();

  @override
  void initState() {
    super.initState();

    final isEditing =
        widget.goalToEdit !=
        null;
    final goal = widget.goalToEdit;

    // --- Core Initialization ---
    final now = DateTime.now();

    _currentGoalId = isEditing
        ? goal!.goalId
        : UniqueKey().toString();
    _goalNameController = TextEditingController(
      text: isEditing
          ? goal!.name
          : 'Daily Goal',
    );
    _targetValueController = TextEditingController(
      text: isEditing
          ? goal!.target
          : '10',
    );
    _selectedActivity = isEditing
        ? _getUnitFromValue(
            goal!.unit,
          )
        : _activityCategories.last;

    // Safely set Date and Time
    _selectedDate =
        isEditing &&
            goal!.deadline.isAfter(
              now.subtract(
                const Duration(
                  days: 365,
                ),
              ),
            ) // Check if date is reasonable
        ? goal.deadline
        : now.add(
            const Duration(
              days: 1,
            ),
          );

    _selectedTime =
        isEditing &&
            goal!.deadline.isAfter(
              now.subtract(
                const Duration(
                  hours: 1,
                ),
              ),
            ) // Check if time is reasonable
        ? TimeOfDay.fromDateTime(
            goal.deadline,
          )
        : const TimeOfDay(
            hour: 20,
            minute: 0,
          );

    _connectToTracker = isEditing
        ? goal!.connectToTracker
        : true;

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
  String? _getUnitFromValue(
    String unit,
  ) {
    for (String activity in _activityCategories) {
      if (_getUnit(
            activity,
          ) ==
          unit) {
        return activity;
      }
    }
    return null;
  }

  // --- Date/Time Pickers (omitted for brevity, remains the same) ---
  Future<
    void
  >
  _selectDate(
    BuildContext context,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate.isBefore(
            DateTime.now(),
          )
          ? DateTime.now().add(
              const Duration(
                days: 1,
              ),
            )
          : _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(
        2030,
      ),
      builder:
          (
            context,
            child,
          ) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: kPrimaryColor,
                ),
                buttonTheme: const ButtonThemeData(
                  textTheme: ButtonTextTheme.primary,
                ),
              ),
              child: child!,
            );
          },
    );
    if (picked !=
            null &&
        picked !=
            _selectedDate) {
      setState(
        () {
          _selectedDate = picked;
          _updateDeadline();
        },
      );
    }
  }

  Future<
    void
  >
  _selectTime(
    BuildContext context,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder:
          (
            context,
            child,
          ) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: kPrimaryColor,
                ),
                buttonTheme: const ButtonThemeData(
                  textTheme: ButtonTextTheme.primary,
                ),
              ),
              child: child!,
            );
          },
    );
    if (picked !=
            null &&
        picked !=
            _selectedTime) {
      setState(
        () {
          _selectedTime = picked;
          _updateDeadline();
        },
      );
    }
  }

  String _getUnit(
    String? activity,
  ) {
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
  Future<
    void
  >
  _setGoal() async {
    if (_goalNameController.text.isEmpty ||
        _targetValueController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in the Goal Name and Target Value.',
          ),
        ),
      );
      return;
    }

    _updateDeadline();
    final DateTime notificationTime = _goalDeadline.subtract(
      const Duration(
        hours: 1,
      ),
    );
    final String unit = _getUnit(
      _selectedActivity,
    );

    final newOrUpdatedGoal = Goal(
      goalId: _currentGoalId,
      name: _goalNameController.text,
      target: _targetValueController.text,
      unit: unit,
      deadline: _goalDeadline,
      reminderTime: notificationTime,
      connectToTracker: _connectToTracker,
    );

    // Check if editing or creating
    final existingIndex = activeGoals.indexWhere(
      (
        g,
      ) =>
          g.goalId ==
          _currentGoalId,
    );

    // Cancel old notification if editing
    if (existingIndex >=
        0) {
      final oldGoal = activeGoals[existingIndex];
      final oldNotificationId = NotificationService.stableIdFromKey(
        oldGoal.goalId,
        scope: 'goal',
      );
      await NotificationService().cancelNotification(
        oldNotificationId,
      );
    }

    if (existingIndex >=
        0) {
      activeGoals[existingIndex] = newOrUpdatedGoal;
    } else {
      activeGoals.add(
        newOrUpdatedGoal,
      );
    }

    // Save goals to local storage first
    final storage = GoalsStorageService();
    await storage.saveGoals(
      activeGoals,
    );
    print(
      '💾 Goals saved to local storage',
    );

    // Schedule notification 1 hour before deadline
    final notificationService = NotificationService();
    // Ensure notification service is initialized (initialize() checks internally if already initialized)
    await notificationService.initialize();

    // Debug: Print notification time details
    print(
      '🔔 Scheduling notification:',
    );
    print(
      '   Goal Deadline: ${newOrUpdatedGoal.deadline}',
    );
    print(
      '   Notification Time (1 hour before): $notificationTime',
    );
    print(
      '   Current Time: ${DateTime.now()}',
    );
    print(
      '   Time until notification: ${notificationTime.difference(DateTime.now()).inMinutes} minutes',
    );

    // Only schedule if notification time is in the future
    bool notificationScheduled = false;
    if (notificationTime.isAfter(
      DateTime.now(),
    )) {
      final notificationId = NotificationService.stableIdFromKey(
        newOrUpdatedGoal.goalId,
        scope: 'goal',
      );
      
      // Cancel any existing notification with the same ID first
      await notificationService.cancelNotification(notificationId);
      
      notificationScheduled = await notificationService.scheduleNotification(
        id: notificationId,
        title: 'Goal Reminder: ${newOrUpdatedGoal.name}',
        body: 'You have 1 hour left to complete your goal: ${newOrUpdatedGoal.target} ${unit}',
        scheduledDate: notificationTime,
        payload: newOrUpdatedGoal.goalId,
      );

      if (notificationScheduled) {
        print(
          '✅ Notification scheduled successfully for ${notificationTime}',
        );
      } else {
        print(
          '⚠️ Failed to schedule notification',
        );
      }

      // Debug: Print all pending notifications
      await notificationService.debugPrintPendingNotifications();
    } else {
      print(
        '⚠️ Notification time is in the past, skipping schedule',
      );
      print(
        '   Notification time: $notificationTime',
      );
      print(
        '   Current time: ${DateTime.now()}',
      );
    }

    // Update the parent state's goal schedule status
    _parentState?._updateGoalScheduleStatus(
      newOrUpdatedGoal.goalId,
      notificationScheduled,
    );

    // Show confirmation dialog
    showDialog(
      context: context,
      builder:
          (
            context,
          ) => AlertDialog(
            title: Text(
              widget.goalToEdit !=
                      null
                  ? 'Goal Updated!'
                  : 'Goal Set Successfully!',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Goal: ${newOrUpdatedGoal.name}\nTarget: ${newOrUpdatedGoal.target} ${unit}',
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  'Goal saved to local storage ✅',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                if (notificationScheduled)
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        'Reminder scheduled',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_off,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        'Reminder not scheduled',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            actions:
                <
                  Widget
                >[
                  TextButton(
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: kPrimaryColor,
                      ),
                    ),
                    onPressed: () {
                      // 1. Dismiss the confirmation dialog
                      Navigator.of(
                        context,
                      ).pop();

                      // 2. Pop the current form view to return to the Goals list
                      Navigator.of(
                        context,
                      ).pop();
                    },
                  ),
                ],
          ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final String actionText =
        widget.goalToEdit !=
            null
        ? 'UPDATE'
        : 'SET';
    // Date format: dd/mm/yyyy
    String formattedDate = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

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
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(
          20.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:
              <
                Widget
              >[
                _buildGoalInputCard(
                  title: 'Goal Name',
                  child: TextField(
                    controller: _goalNameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Daily Step Goal',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                _buildGoalInputCard(
                  title: 'Activity Type',
                  child: DropdownButtonHideUnderline(
                    child:
                        DropdownButton<
                          String
                        >(
                          value: _selectedActivity,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: kPrimaryColor,
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                          items:
                              _activityCategories.map<
                                DropdownMenuItem<
                                  String
                                >
                              >(
                                (
                                  String value,
                                ) {
                                  return DropdownMenuItem<
                                    String
                                  >(
                                    value: value,
                                    child: Text(
                                      value,
                                    ),
                                  );
                                },
                              ).toList(),
                          onChanged:
                              (
                                String? newValue,
                              ) {
                                setState(
                                  () {
                                    _selectedActivity = newValue;
                                  },
                                );
                              },
                        ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                _buildGoalInputCard(
                  title: 'Target Value (${_getUnit(_selectedActivity)})',
                  child: TextField(
                    controller: _targetValueController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter target value',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      suffixText: _getUnit(
                        _selectedActivity,
                      ),
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
                const SizedBox(
                  height: 30,
                ),

                // --- Deadline Selector (Date & Time) ---
                const Text(
                  'Goal Deadline & Reminder',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Row(
                  children: [
                    _buildDateSelector(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: formattedDate,
                      onTap: () => _selectDate(
                        context,
                      ),
                    ),
                    const SizedBox(
                      width: 15,
                    ),
                    _buildDateSelector(
                      icon: Icons.access_time,
                      label: 'Time',
                      value: _selectedTime.format(
                        context,
                      ),
                      onTap: () => _selectTime(
                        context,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                _buildReminderInfo(),
                const SizedBox(
                  height: 30,
                ),

                // --- Connect to Tracker Option ---
                _buildConnectTrackerOption(),
                const SizedBox(
                  height: 40,
                ),

                // --- Set Goal Button ---
                ElevatedButton.icon(
                  onPressed: _setGoal,
                  icon: Icon(
                    widget.goalToEdit !=
                            null
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        15,
                      ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          15,
        ),
        border: Border.all(
          color: _connectToTracker
              ? kAccentColor
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(
              0.1,
            ),
            blurRadius: 5,
            offset: const Offset(
              0,
              3,
            ),
          ),
        ],
      ),
      child: SwitchListTile(
        title: const Text(
          'Connect to Workout Tracker',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text(
          'Display this goal directly in your workout tracking screen.',
        ),
        value: _connectToTracker,
        activeColor: kAccentColor,
        onChanged:
            (
              bool value,
            ) {
              setState(
                () {
                  _connectToTracker = value;
                },
              );
            },
      ),
    );
  }

  Widget _buildGoalInputCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          15,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(
              0.1,
            ),
            blurRadius: 5,
            offset: const Offset(
              0,
              3,
            ),
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
          const SizedBox(
            height: 5,
          ),
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
          padding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              10,
            ),
            border: Border.all(
              color: Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: kPrimaryColor,
              ),
              const SizedBox(
                width: 8,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
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
      padding: const EdgeInsets.only(
        top: 8.0,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active,
            color: kAccentColor,
            size: 20,
          ),
          const SizedBox(
            width: 8,
          ),
          Text(
            'You will be notified 1 hour before the deadline.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
