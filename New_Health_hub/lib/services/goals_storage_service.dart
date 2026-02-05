// goals_storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/personalized_goals_view.dart';

class GoalsStorageService {
  static final GoalsStorageService _instance = GoalsStorageService._internal();
  factory GoalsStorageService() => _instance;
  GoalsStorageService._internal();

  static const String _goalsKey = 'saved_goals';

  /// Save goals to local storage
  Future<void> saveGoals(List<Goal> goals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = goals.map((goal) => _goalToJson(goal)).toList();
      await prefs.setString(_goalsKey, json.encode(goalsJson));
      print('✅ Saved ${goals.length} goals to local storage');
    } catch (e) {
      print('❌ Error saving goals: $e');
    }
  }

  /// Load goals from local storage
  Future<List<Goal>> loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = prefs.getString(_goalsKey);
      
      if (goalsJson == null || goalsJson.isEmpty) {
        print('📋 No saved goals found');
        return [];
      }

      final List<dynamic> decoded = json.decode(goalsJson);
      final goals = decoded.map((json) => _goalFromJson(json)).toList();
      print('✅ Loaded ${goals.length} goals from local storage');
      return goals;
    } catch (e) {
      print('❌ Error loading goals: $e');
      return [];
    }
  }

  /// Convert Goal to JSON
  Map<String, dynamic> _goalToJson(Goal goal) {
    return {
      'goalId': goal.goalId,
      'name': goal.name,
      'target': goal.target,
      'unit': goal.unit,
      'deadline': goal.deadline.toIso8601String(),
      'reminderTime': goal.reminderTime.toIso8601String(),
      'connectToTracker': goal.connectToTracker,
    };
  }

  /// Convert JSON to Goal
  Goal _goalFromJson(Map<String, dynamic> json) {
    return Goal(
      goalId: json['goalId'] as String,
      name: json['name'] as String,
      target: json['target'] as String,
      unit: json['unit'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
      reminderTime: DateTime.parse(json['reminderTime'] as String),
      connectToTracker: json['connectToTracker'] as bool? ?? false,
    );
  }

  /// Clear all saved goals
  Future<void> clearGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_goalsKey);
      print('🗑️ Cleared all saved goals');
    } catch (e) {
      print('❌ Error clearing goals: $e');
    }
  }
}

