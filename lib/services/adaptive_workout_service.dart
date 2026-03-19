import 'workout_plan_schedule_service.dart';
import 'weekly_workout_plan_service.dart';

class AdaptiveWorkoutService {
  const AdaptiveWorkoutService();

  String buildAdaptiveRefinement({
    required WeeklyWorkoutPlan plan,
    required WorkoutPlanSchedule schedule,
    required String userReason,
  }) {
    final backlog = schedule.backlogDays.map((day) {
      final pendingTasks = day.tasks
          .where((task) => !task.isDone)
          .map((task) => task.title)
          .join(', ');
      return '${day.label}: ${day.summary}${pendingTasks.isNotEmpty ? ' | pending: $pendingTasks' : ''}';
    }).join(' || ');

    final today = schedule.todayDay;
    final todaySummary = today == null
        ? 'No active day found.'
        : '${today.label}: ${today.summary}';

    final reason = userReason.trim().isEmpty
        ? 'User missed previous days and wants a smoother catch-up plan.'
        : userReason.trim();

    return '''
Adapt the upcoming workout days based on this situation:
- Goal: ${plan.goal}
- Duration: ${plan.duration}
- Equipment: ${plan.equipment}
- Intensity: ${plan.intensity}
- Injury: ${plan.injury}
- Current focus day: $todaySummary
- Missed backlog days: ${backlog.isEmpty ? 'None listed, but reduce overload and smooth progression anyway.' : backlog}
- User context: $reason

Keep it as a full 7-day weekly plan, but make the next days more realistic, avoid overload from missed backlog, preserve one recovery day, and prioritize sustainability.
''';
  }
}
