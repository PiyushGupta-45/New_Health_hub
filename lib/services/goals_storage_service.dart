// goals_storage_service.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/personalized_goals_view.dart';

class GoalsStorageService {
  static final GoalsStorageService _instance = GoalsStorageService._internal();
  factory GoalsStorageService() => _instance;
  GoalsStorageService._internal();

  static const String _goalsKey = 'saved_goals';

  Future<void> saveGoals(List<Goal> goals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = goals.map(_goalToJson).toList();
      await prefs.setString(_goalsKey, json.encode(goalsJson));
      debugPrint('Saved ${goals.length} goals to local storage');
    } catch (e) {
      debugPrint('Error saving goals: $e');
    }
  }

  Future<List<Goal>> loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = prefs.getString(_goalsKey);

      if (goalsJson == null || goalsJson.isEmpty) {
        debugPrint('No saved goals found');
        return [];
      }

      final decoded = json.decode(goalsJson);
      if (decoded is! List) return [];

      final goals = decoded
          .where((item) => item is Map)
          .map((item) => _goalFromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      debugPrint('Loaded ${goals.length} goals from local storage');
      return goals;
    } catch (e) {
      debugPrint('Error loading goals: $e');
      return [];
    }
  }

  Map<String, dynamic> _goalToJson(Goal goal) {
    return {
      'goalId': goal.goalId,
      'name': goal.name,
      'activityType': goal.activityType,
      'target': goal.target,
      'unit': goal.unit,
      'deadline': goal.deadline.toIso8601String(),
      'reminderTime': goal.reminderTime.toIso8601String(),
      'connectToTracker': goal.connectToTracker,
    };
  }

  Goal _goalFromJson(Map<String, dynamic> json) {
    return Goal(
      goalId: json['goalId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Goal',
      activityType: _inferActivityType(json),
      target: json['target']?.toString() ?? '0',
      unit: json['unit']?.toString() ?? '',
      deadline: DateTime.tryParse(json['deadline']?.toString() ?? '') ??
          DateTime.now(),
      reminderTime:
          DateTime.tryParse(json['reminderTime']?.toString() ?? '') ??
              DateTime.now(),
      connectToTracker: json['connectToTracker'] == true,
    );
  }

  Future<void> clearGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_goalsKey);
      debugPrint('Cleared all saved goals');
    } catch (e) {
      debugPrint('Error clearing goals: $e');
    }
  }

  String _inferActivityType(Map<String, dynamic> json) {
    final explicit = json['activityType']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final unit = json['unit']?.toString().toLowerCase() ?? '';
    if (unit == 'steps') return 'Steps';
    if (unit == 'minutes') return 'Cardio Minutes';
    if (unit == 'calories') return 'Calorie Burn';
    if (unit == 'km') return 'Distance (km)';
    if (unit == 'ml') return 'Water Intake';

    final name = json['name']?.toString().toLowerCase() ?? '';
    if (name.contains('weight')) return 'Weight Loss';
    return 'Steps';
  }
}
