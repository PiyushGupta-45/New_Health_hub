import 'package:flutter/foundation.dart';

import 'workout_storage_service.dart';

class ManualWorkoutLog {
  ManualWorkoutLog({
    required this.id,
    required this.workoutType,
    required this.startTime,
    required this.durationSeconds,
    required this.calories,
    this.met,
    this.createdAt,
  });

  final String id;
  final String workoutType;
  final DateTime startTime;
  final int durationSeconds;
  final double calories;
  final double? met;
  final DateTime? createdAt;

  factory ManualWorkoutLog.fromJson(Map<String, dynamic> json) {
    final start = json['startTime']?.toString();
    final created = json['createdAt']?.toString();
    return ManualWorkoutLog(
      id: json['_id']?.toString() ?? '',
      workoutType: json['workoutType']?.toString() ?? 'Workout',
      startTime: start != null ? DateTime.tryParse(start) ?? DateTime.now() : DateTime.now(),
      durationSeconds: json['durationSeconds'] is num
          ? (json['durationSeconds'] as num).round()
          : 0,
      calories: json['calories'] is num
          ? (json['calories'] as num).toDouble()
          : 0,
      met: json['met'] is num ? (json['met'] as num).toDouble() : null,
      createdAt: created != null ? DateTime.tryParse(created) : null,
    );
  }
}

class WorkoutLogService {
  WorkoutLogService() : _storageService = WorkoutStorageService();

  final WorkoutStorageService _storageService;

  Future<List<ManualWorkoutLog>> fetchLogs({int limit = 50}) async {
    // Use local storage instead of backend
    try {
      return await _storageService.loadWorkoutLogs(limit: limit);
    } catch (e) {
      debugPrint('Error loading workout logs from storage: $e');
      return [];
    }
  }

  Future<ManualWorkoutLog?> createLog({
    required String workoutType,
    required DateTime startTime,
    required int durationSeconds,
    required double calories,
    double? met,
  }) async {
    // Save to local storage instead of backend
    try {
      final log = await _storageService.saveWorkoutLog(
        workoutType: workoutType,
        startTime: startTime,
        durationSeconds: durationSeconds,
        calories: calories,
        met: met,
      );
      return log;
    } catch (e) {
      debugPrint('Error saving workout log: $e');
      throw Exception('Failed to save workout: ${e.toString()}');
    }
  }

  Future<void> deleteLog(String logId) async {
    await _storageService.deleteWorkoutLog(logId);
  }
}

