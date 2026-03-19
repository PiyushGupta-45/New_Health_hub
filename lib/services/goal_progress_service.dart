import '../pages/personalized_goals_view.dart';
import 'workout_log_service.dart';

class GoalProgressSnapshot {
  const GoalProgressSnapshot({
    required this.currentValue,
    required this.targetValue,
    required this.progress,
    required this.displayValue,
    required this.detail,
    required this.isTracked,
  });

  final double currentValue;
  final double targetValue;
  final double progress;
  final String displayValue;
  final String detail;
  final bool isTracked;
}

class GoalProgressService {
  const GoalProgressService();

  GoalProgressSnapshot buildSnapshot({
    required Goal goal,
    required int todaySteps,
    required List<ManualWorkoutLog> logs,
  }) {
    final target = double.tryParse(goal.target.trim()) ?? 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todaysLogs = logs.where((log) {
      final day = DateTime(
        log.startTime.year,
        log.startTime.month,
        log.startTime.day,
      );
      return day == todayDate;
    }).toList();

    double currentValue = 0;
    String detail = 'No live tracker source mapped yet.';
    var isTracked = true;

    switch (goal.activityType) {
      case 'Steps':
        currentValue = todaySteps.toDouble();
        detail = 'Today\'s synced steps';
        break;
      case 'Cardio Minutes':
        currentValue = todaysLogs.fold<double>(
          0,
          (sum, log) => sum + (log.durationSeconds / 60.0),
        );
        detail = 'Minutes from today\'s logged workouts';
        break;
      case 'Calorie Burn':
        final workoutCalories = todaysLogs.fold<double>(
          0,
          (sum, log) => sum + log.calories,
        );
        final stepCalories = todaySteps * 0.04;
        currentValue = workoutCalories + stepCalories;
        detail = 'Workout calories plus step burn estimate';
        break;
      case 'Distance (km)':
        currentValue = todaysLogs.fold<double>(
          0,
          (sum, log) => sum + (log.distanceKm ?? 0),
        );
        detail = 'Distance from today\'s tracked workouts';
        break;
      case 'Water Intake':
      case 'Weight Loss':
        isTracked = false;
        detail = 'This goal still needs manual logging support.';
        break;
      default:
        isTracked = false;
        detail = 'Tracker source unavailable.';
    }

    final safeTarget = target <= 0 ? 1 : target;
    final progress = (currentValue / safeTarget).clamp(0.0, 1.0);

    return GoalProgressSnapshot(
      currentValue: currentValue,
      targetValue: target,
      progress: progress,
      displayValue: _formatValue(currentValue, goal.unit),
      detail: detail,
      isTracked: isTracked,
    );
  }

  String _formatValue(double value, String unit) {
    if (unit == 'steps' || unit == 'minutes' || unit == 'calories') {
      return value.round().toString();
    }
    if (unit == 'km') {
      return value.toStringAsFixed(value >= 10 ? 1 : 2);
    }
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }
}
