import '../services/posture_history_service.dart';
import '../services/workout_log_service.dart';

class StreakStat {
  const StreakStat({
    required this.title,
    required this.days,
    required this.detail,
  });

  final String title;
  final int days;
  final String detail;
}

class BadgeAward {
  const BadgeAward({
    required this.title,
    required this.description,
    required this.unlocked,
  });

  final String title;
  final String description;
  final bool unlocked;
}

class StreakSummary {
  const StreakSummary({
    required this.stats,
    required this.badges,
    required this.totalXp,
  });

  final List<StreakStat> stats;
  final List<BadgeAward> badges;
  final int totalXp;
}

class StreaksService {
  const StreaksService();

  StreakSummary buildSummary({
    required int todaySteps,
    required Map<String, int> stepsByDate,
    required List<ManualWorkoutLog> logs,
    required List<PostureSessionRecord> postureSessions,
  }) {
    final stepStreak = _countBackwards((dateKey) {
      if (_isToday(dateKey)) {
        return todaySteps >= 8000 || (stepsByDate[dateKey] ?? 0) >= 8000;
      }
      return (stepsByDate[dateKey] ?? 0) >= 8000;
    });

    final workoutDays = <String>{
      for (final log in logs) _dateKey(log.startTime),
    };
    final workoutStreak = _countBackwards(workoutDays.contains);

    final postureDays = <String>{
      for (final session in postureSessions) _dateKey(session.recordedAt),
    };
    final postureStreak = _countBackwards(postureDays.contains);

    final stats = <StreakStat>[
      StreakStat(title: 'Step Streak', days: stepStreak, detail: 'Days hitting 8k steps'),
      StreakStat(title: 'Workout Streak', days: workoutStreak, detail: 'Days with at least one workout'),
      StreakStat(title: 'Posture Streak', days: postureStreak, detail: 'Days with posture analysis'),
    ];

    final badges = <BadgeAward>[
      BadgeAward(
        title: 'Momentum Builder',
        description: 'Hold a 3-day step streak',
        unlocked: stepStreak >= 3,
      ),
      BadgeAward(
        title: 'Training Locked In',
        description: 'Log workouts 3 days in a row',
        unlocked: workoutStreak >= 3,
      ),
      BadgeAward(
        title: 'Form First',
        description: 'Do posture analysis 3 days in a row',
        unlocked: postureStreak >= 3,
      ),
    ];

    final totalXp =
        (stepStreak * 20) + (workoutStreak * 25) + (postureStreak * 20);

    return StreakSummary(
      stats: stats,
      badges: badges,
      totalXp: totalXp,
    );
  }

  int _countBackwards(bool Function(String dateKey) tester) {
    var streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final key = _dateKey(date);
      if (!tester(key)) break;
      streak++;
    }
    return streak;
  }

  String _dateKey(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isToday(String key) => key == _dateKey(DateTime.now());
}
