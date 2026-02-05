// Local storage service for workout logs

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'workout_log_service.dart';

class WorkoutStorageService {
  static final WorkoutStorageService _instance = WorkoutStorageService._internal();
  factory WorkoutStorageService() => _instance;
  WorkoutStorageService._internal();

  static const String _workoutLogsKey = 'workout_logs';

  /// Save workout log to local storage
  Future<ManualWorkoutLog> saveWorkoutLog({
    required String workoutType,
    required DateTime startTime,
    required int durationSeconds,
    required double calories,
    double? met,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load existing logs
      final existingLogs = await loadWorkoutLogs();
      
      // Create new log with unique ID
      final newLog = ManualWorkoutLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        workoutType: workoutType,
        startTime: startTime,
        durationSeconds: durationSeconds,
        calories: calories,
        met: met,
        createdAt: DateTime.now(),
      );
      
      // Add new log at the beginning (most recent first)
      final updatedLogs = [newLog, ...existingLogs];
      
      // Save to storage
      final logsJson = updatedLogs.map((log) => _logToJson(log)).toList();
      await prefs.setString(_workoutLogsKey, json.encode(logsJson));
      
      debugPrint('✅ Saved workout log: ${newLog.workoutType}');
      return newLog;
    } catch (e) {
      debugPrint('❌ Error saving workout log: $e');
      rethrow;
    }
  }

  /// Load workout logs from local storage
  Future<List<ManualWorkoutLog>> loadWorkoutLogs({int limit = 100}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString(_workoutLogsKey);
      
      if (logsJson == null || logsJson.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = json.decode(logsJson);
      final logs = decoded
          .map((json) => ManualWorkoutLog.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // Sort by start time (most recent first) and limit
      logs.sort((a, b) => b.startTime.compareTo(a.startTime));
      return logs.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error loading workout logs: $e');
      return [];
    }
  }

  /// Delete a workout log
  Future<void> deleteWorkoutLog(String logId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingLogs = await loadWorkoutLogs();
      
      final updatedLogs = existingLogs.where((log) => log.id != logId).toList();
      
      final logsJson = updatedLogs.map((log) => _logToJson(log)).toList();
      await prefs.setString(_workoutLogsKey, json.encode(logsJson));
      
      debugPrint('✅ Deleted workout log: $logId');
    } catch (e) {
      debugPrint('❌ Error deleting workout log: $e');
    }
  }

  /// Clear all workout logs
  Future<void> clearAllLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_workoutLogsKey);
      debugPrint('✅ Cleared all workout logs');
    } catch (e) {
      debugPrint('❌ Error clearing workout logs: $e');
    }
  }

  /// Convert ManualWorkoutLog to JSON
  Map<String, dynamic> _logToJson(ManualWorkoutLog log) {
    return {
      '_id': log.id,
      'workoutType': log.workoutType,
      'startTime': log.startTime.toIso8601String(),
      'durationSeconds': log.durationSeconds,
      'calories': log.calories,
      'met': log.met,
      'createdAt': log.createdAt?.toIso8601String(),
    };
  }
}

