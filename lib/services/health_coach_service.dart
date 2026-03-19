import '../pages/personalized_goals_view.dart';
import 'posture_history_service.dart';
import 'workout_log_service.dart';

class HealthCoachBrief {
  const HealthCoachBrief({
    required this.headline,
    required this.message,
    required this.actions,
  });

  final String headline;
  final String message;
  final List<String> actions;
}

class HealthCoachService {
  const HealthCoachService();

  HealthCoachBrief buildBrief({
    required int todaySteps,
    required int weeklyWorkoutCount,
    required List<Goal> goals,
    required PostureSummary postureSummary,
    required List<ManualWorkoutLog> recentLogs,
  }) {
    final activeGoals = goals.where((goal) => goal.deadline.isAfter(DateTime.now())).length;
    final hasWorkoutToday = recentLogs.any((log) {
      final now = DateTime.now();
      return log.startTime.year == now.year &&
          log.startTime.month == now.month &&
          log.startTime.day == now.day;
    });

    final actions = <String>[];
    String headline;
    String message;

    if (todaySteps < 4000 && !hasWorkoutToday) {
      headline = 'Low movement day so far';
      message =
          'Your activity is still light today. A short walk or one quick workout would meaningfully improve momentum.';
      actions.add('Aim for 2,000 more steps before evening.');
      actions.add('Complete your AI workout plan task for today.');
    } else if (weeklyWorkoutCount >= 4 && postureSummary.averageScore >= 70) {
      headline = 'Strong consistency';
      message =
          'You\'re combining regular training with good form. This is the kind of pattern that compounds well over time.';
      actions.add('Keep recovery balanced and avoid skipping rest work.');
      actions.add('Use backlog cleanup only if earlier plan items still matter.');
    } else {
      headline = 'Solid base, room to sharpen';
      message =
          'You have movement data coming in, but the biggest gains now are consistency, tracked goals, and better form repetition.';
      actions.add('Use connected goals to turn daily effort into measurable progress.');
      actions.add('Log one posture session to improve your coaching insights.');
    }

    if (activeGoals == 0) {
      actions.add('Create at least one active goal for more targeted coaching.');
    }
    if (postureSummary.totalSessions == 0) {
      actions.add('Start a posture analysis session so form history can build.');
    } else if (postureSummary.averageScore < 65) {
      actions.add('Repeat ${postureSummary.bestExercise} form work with slower reps.');
    }

    return HealthCoachBrief(
      headline: headline,
      message: message,
      actions: actions.take(3).toList(),
    );
  }
}
