import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weekly_workout_plan_service.dart';

class WorkoutPlanTask {
  const WorkoutPlanTask({required this.title, required this.isDone});

  final String title;
  final bool isDone;

  WorkoutPlanTask copyWith({bool? isDone}) {
    return WorkoutPlanTask(title: title, isDone: isDone ?? this.isDone);
  }
}

class WorkoutPlanDay {
  const WorkoutPlanDay({
    required this.dayNumber,
    required this.label,
    required this.summary,
    required this.tasks,
    this.completedAt,
  });

  final int dayNumber;
  final String label;
  final String summary;
  final List<WorkoutPlanTask> tasks;
  final DateTime? completedAt;

  bool get isComplete => tasks.isNotEmpty && tasks.every((task) => task.isDone);
  bool get hasPendingTasks => tasks.any((task) => !task.isDone);

  WorkoutPlanDay copyWith({
    String? summary,
    List<WorkoutPlanTask>? tasks,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return WorkoutPlanDay(
      dayNumber: dayNumber,
      label: label,
      summary: summary ?? this.summary,
      tasks: tasks ?? this.tasks,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}

class WorkoutPlanSchedule {
  const WorkoutPlanSchedule({
    required this.plan,
    required this.days,
    required this.currentDayIndex,
    required this.backlogDays,
  });

  final WeeklyWorkoutPlan plan;
  final List<WorkoutPlanDay> days;
  final int currentDayIndex;
  final List<WorkoutPlanDay> backlogDays;

  WorkoutPlanDay? get todayDay {
    if (days.isEmpty) return null;
    final index = currentDayIndex.clamp(0, days.length - 1);
    return days[index];
  }

  List<WorkoutPlanDay> get upcomingDays {
    if (days.isEmpty) return const <WorkoutPlanDay>[];
    final start = (currentDayIndex + 1).clamp(0, days.length);
    return days.skip(start).toList();
  }
}

class WorkoutPlanScheduleService {
  WorkoutPlanScheduleService._internal();

  static final WorkoutPlanScheduleService _instance =
      WorkoutPlanScheduleService._internal();

  factory WorkoutPlanScheduleService() => _instance;

  static const String _scheduleStateKey = 'workout_ai_schedule_state_v1';

  Future<WorkoutPlanSchedule?> loadForPlan(WeeklyWorkoutPlan? plan) async {
    if (plan == null) return null;

    final parsedDays = parsePlanDays(plan.planText);
    if (parsedDays.isEmpty) return null;

    final persisted = await _loadPersistedState();
    final signature = _planSignature(plan);
    final statusMap = persisted['planSignature'] == signature
        ? _normalizeStatusMap(persisted['status'])
        : <String, Map<String, bool>>{};
    final completionMap = persisted['planSignature'] == signature
        ? _normalizeCompletionMap(persisted['completedAt'])
        : <String, DateTime>{};

    final mergedDays = parsedDays.map((day) {
      final persistedTasks = statusMap[day.label] ?? const <String, bool>{};
      final mergedTasks = day.tasks
          .map(
            (task) =>
                task.copyWith(isDone: persistedTasks[task.title] ?? false),
          )
          .toList();
      final isComplete =
          mergedTasks.isNotEmpty && mergedTasks.every((task) => task.isDone);
      return day.copyWith(
        tasks: mergedTasks,
        completedAt: isComplete ? completionMap[day.label] : null,
        clearCompletedAt: !isComplete,
      );
    }).toList();

    final currentDayIndex = _resolveCurrentDayIndex(plan, mergedDays.length);
    final backlogDays = mergedDays
        .where(
          (day) => day.dayNumber - 1 < currentDayIndex && day.hasPendingTasks,
        )
        .toList();

    await _persistSchedule(plan, mergedDays);

    return WorkoutPlanSchedule(
      plan: plan,
      days: mergedDays,
      currentDayIndex: currentDayIndex,
      backlogDays: backlogDays,
    );
  }

  Future<void> toggleTask({
    required WeeklyWorkoutPlan plan,
    required String dayLabel,
    required String taskTitle,
    required bool value,
  }) async {
    final schedule = await loadForPlan(plan);
    if (schedule == null) return;

    final updatedDays = schedule.days.map((day) {
      if (day.label != dayLabel) return day;
      final updatedTasks = day.tasks
          .map(
            (task) =>
                task.title == taskTitle ? task.copyWith(isDone: value) : task,
          )
          .toList();
      final isComplete =
          updatedTasks.isNotEmpty && updatedTasks.every((task) => task.isDone);
      return day.copyWith(
        tasks: updatedTasks,
        completedAt: isComplete ? (day.completedAt ?? DateTime.now()) : null,
        clearCompletedAt: !isComplete,
      );
    }).toList();

    await _persistSchedule(plan, updatedDays);
  }

  Future<void> toggleDay({
    required WeeklyWorkoutPlan plan,
    required String dayLabel,
    required bool value,
  }) async {
    final schedule = await loadForPlan(plan);
    if (schedule == null) return;

    final updatedDays = schedule.days.map((day) {
      if (day.label != dayLabel) return day;
      return day.copyWith(
        tasks: day.tasks.map((task) => task.copyWith(isDone: value)).toList(),
        completedAt: value ? (day.completedAt ?? DateTime.now()) : null,
        clearCompletedAt: !value,
      );
    }).toList();

    await _persistSchedule(plan, updatedDays);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scheduleStateKey);
  }

  List<WorkoutPlanDay> parsePlanDays(String planText) {
    final lines = planText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final dayHeaderPattern = RegExp(
      r'^-?\s*day\s+(\d+)\s*:?\s*(.*)$',
      caseSensitive: false,
    );

    final Map<int, List<String>> rawByDay = <int, List<String>>{};
    String? currentDayLabel;
    int? currentDayNumber;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('## notes')) {
        currentDayLabel = null;
        currentDayNumber = null;
        continue;
      }

      final normalized = line.replaceFirst(RegExp(r'^[-*]\s*'), '');
      final match = dayHeaderPattern.firstMatch(normalized);
      if (match != null) {
        currentDayNumber = int.tryParse(match.group(1) ?? '');
        currentDayLabel = currentDayNumber == null
            ? null
            : 'Day $currentDayNumber';
        if (currentDayNumber != null) {
          rawByDay.putIfAbsent(currentDayNumber, () => <String>[]);
          final remainder = (match.group(2) ?? '').trim();
          if (remainder.isNotEmpty) {
            rawByDay[currentDayNumber]!.add(remainder);
          }
        }
        continue;
      }

      if (currentDayLabel == null || currentDayNumber == null) continue;
      if (lower.startsWith('## ')) continue;
      if (lower.startsWith('inputs echo')) continue;
      if (lower == 'plan') continue;

      final bulletMatch = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);
      if (bulletMatch != null) {
        rawByDay[currentDayNumber]!.add(bulletMatch.group(1)!.trim());
        continue;
      }

      final numberedMatch = RegExp(r'^\d+\.\s+(.+)$').firstMatch(line);
      if (numberedMatch != null) {
        rawByDay[currentDayNumber]!.add(numberedMatch.group(1)!.trim());
      }
    }

    if (rawByDay.isEmpty) {
      return List<WorkoutPlanDay>.generate(
        7,
        (index) => WorkoutPlanDay(
          dayNumber: index + 1,
          label: 'Day ${index + 1}',
          summary: 'Workout',
          tasks: const <WorkoutPlanTask>[
            WorkoutPlanTask(title: 'Workout', isDone: false),
          ],
        ),
      );
    }

    final orderedKeys = rawByDay.keys.toList()..sort();
    return orderedKeys.map((dayNumber) {
      final rawItems = rawByDay[dayNumber] ?? const <String>[];
      final taskSource = rawItems.length > 1
          ? rawItems.skip(1).toList()
          : rawItems;
      final tasks = _splitWorkoutItems(taskSource);
      final summary = rawItems.isNotEmpty ? rawItems.first : 'Workout';
      return WorkoutPlanDay(
        dayNumber: dayNumber,
        label: 'Day $dayNumber',
        summary: summary,
        tasks: tasks
            .map((task) => WorkoutPlanTask(title: task, isDone: false))
            .toList(),
      );
    }).toList();
  }

  List<String> _splitWorkoutItems(List<String> rawItems) {
    if (rawItems.isEmpty) return const <String>['Workout'];

    final expanded = <String>[];
    for (final raw in rawItems) {
      var normalized = raw
          .replaceAll(';', ', ')
          .replaceAll('+', ', ')
          .replaceAll('|', ', ')
          .replaceAll(' / ', ', ')
          .replaceAll(RegExp(r'\s+and\s+', caseSensitive: false), ', ');

      normalized = normalized.replaceAll(RegExp(r',+'), ',');
      expanded.addAll(
        normalized
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      );
    }

    final seen = <String>{};
    final deduped = <String>[];
    for (final item in expanded) {
      if (seen.add(item.toLowerCase())) {
        deduped.add(item);
      }
    }

    return deduped.isEmpty ? const <String>['Workout'] : deduped;
  }

  int _resolveCurrentDayIndex(WeeklyWorkoutPlan plan, int dayCount) {
    if (dayCount <= 0) return 0;
    final anchor = plan.approvedAt ?? plan.createdAt ?? DateTime.now();
    final anchorDate = DateTime(anchor.year, anchor.month, anchor.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(anchorDate).inDays;
    if (diff <= 0) return 0;
    if (diff >= dayCount) return dayCount - 1;
    return diff;
  }

  Future<void> _persistSchedule(
    WeeklyWorkoutPlan plan,
    List<WorkoutPlanDay> days,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final status = <String, Map<String, bool>>{
      for (final day in days)
        day.label: {for (final task in day.tasks) task.title: task.isDone},
    };
    final completedAt = <String, String>{
      for (final day in days)
        if (day.completedAt != null)
          day.label: day.completedAt!.toIso8601String(),
    };

    await prefs.setString(
      _scheduleStateKey,
      json.encode({
        'planSignature': _planSignature(plan),
        'status': status,
        'completedAt': completedAt,
      }),
    );
  }

  Future<Map<String, dynamic>> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scheduleStateKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  Map<String, Map<String, bool>> _normalizeStatusMap(dynamic rawStatus) {
    if (rawStatus is! Map<String, dynamic>) {
      return <String, Map<String, bool>>{};
    }

    final normalized = <String, Map<String, bool>>{};
    for (final entry in rawStatus.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      normalized[entry.key] = {
        for (final taskEntry in value.entries)
          taskEntry.key: taskEntry.value == true || taskEntry.value == 'true',
      };
    }
    return normalized;
  }

  Map<String, DateTime> _normalizeCompletionMap(dynamic rawCompletedAt) {
    if (rawCompletedAt is! Map<String, dynamic>) {
      return <String, DateTime>{};
    }

    final normalized = <String, DateTime>{};
    for (final entry in rawCompletedAt.entries) {
      final parsed = DateTime.tryParse(entry.value?.toString() ?? '');
      if (parsed != null) {
        normalized[entry.key] = parsed;
      }
    }
    return normalized;
  }

  String _planSignature(WeeklyWorkoutPlan plan) {
    final anchor = plan.approvedAt ?? plan.createdAt;
    final payload =
        '${plan.id}|${anchor?.toIso8601String() ?? ''}|${plan.planText}';
    return sha1.convert(utf8.encode(payload)).toString();
  }
}
