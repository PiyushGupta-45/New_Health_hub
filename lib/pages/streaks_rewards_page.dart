import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/auth_controller.dart';
import '../controllers/health_sync_controller.dart';
import '../services/posture_history_service.dart';
import '../services/streaks_service.dart';
import '../services/steps_sync_service.dart';
import '../services/workout_log_service.dart';

class StreaksRewardsPage extends StatefulWidget {
  const StreaksRewardsPage({
    super.key,
    required this.controller,
    required this.authController,
  });

  final HealthSyncController controller;
  final AuthController authController;

  @override
  State<StreaksRewardsPage> createState() => _StreaksRewardsPageState();
}

class _StreaksRewardsPageState extends State<StreaksRewardsPage> {
  final WorkoutLogService _workoutLogService = WorkoutLogService();
  final PostureHistoryService _postureHistoryService = PostureHistoryService();
  final StepsSyncService _stepsSyncService = StepsSyncService();
  final StreaksService _streaksService = const StreaksService();

  bool _isLoading = true;
  String? _error;
  StreakSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final logsFuture = _workoutLogService.fetchLogs(limit: 120);
      final postureFuture = _postureHistoryService.loadSessions(limit: 120);
      final stepsFuture = widget.authController.isAuthenticated
          ? _stepsSyncService.getStepsHistory(limit: 30)
          : Future.value(<String, dynamic>{'data': const []});

      final results = await Future.wait([
        logsFuture,
        postureFuture,
        stepsFuture,
      ]);

      final logs = results[0] as List<ManualWorkoutLog>;
      final postureSessions = results[1] as List<PostureSessionRecord>;
      final stepsResult = results[2] as Map<String, dynamic>;
      final stepsHistory = stepsResult['data'] is List
          ? List<Map<String, dynamic>>.from(stepsResult['data'] as List)
          : <Map<String, dynamic>>[];

      final stepsByDate = <String, int>{};
      for (final item in stepsHistory) {
        final rawDate = item['date']?.toString();
        final parsed = rawDate == null ? null : DateTime.tryParse(rawDate);
        if (parsed == null) continue;
        final key = DateFormat('yyyy-MM-dd').format(parsed.toLocal());
        final value = item['steps'];
        stepsByDate[key] = value is num ? value.toInt() : 0;
      }

      final summary = _streaksService.buildSummary(
        todaySteps: widget.controller.todaySteps,
        stepsByDate: stepsByDate,
        logs: logs,
        postureSessions: postureSessions,
      );

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Streaks & Rewards'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: text,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  _Hero(summary: _summary!),
                  const SizedBox(height: 18),
                  Text(
                    'Current Streaks',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._summary!.stats.map((stat) => _StreakCard(stat: stat)),
                  const SizedBox(height: 18),
                  Text(
                    'Badges',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._summary!.badges.map((badge) => _BadgeCard(badge: badge)),
                ],
              ),
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.summary});

  final StreakSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'XP Earned',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.totalXp}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.badges.where((badge) => badge.unlocked).length} badge(s) unlocked',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.stat});

  final StreakStat stat;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF111827);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${stat.days}',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.title,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.detail,
                  style: TextStyle(color: sub, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final BadgeAward badge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF111827);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: badge.unlocked
              ? const Color(0xFFF59E0B)
              : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(
            badge.unlocked ? Icons.workspace_premium_rounded : Icons.lock_outline,
            color: badge.unlocked ? const Color(0xFFF59E0B) : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  badge.description,
                  style: TextStyle(color: sub, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
