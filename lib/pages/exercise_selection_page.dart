// Exercise Selection Page
// Allows users to select which exercise they want to analyze

import 'package:flutter/material.dart';
import '../models/exercise_type.dart';
import '../services/posture_history_service.dart';
import 'pose_camera_page.dart';

class ExerciseSelectionPage
    extends
        StatefulWidget {
  const ExerciseSelectionPage({
    super.key,
  });

  @override
  State<
    ExerciseSelectionPage
  >
  createState() => _ExerciseSelectionPageState();
}

class _ExerciseSelectionPageState
    extends
        State<
          ExerciseSelectionPage
        > {
  final PostureHistoryService _postureHistoryService = PostureHistoryService();
  List<PostureSessionRecord> _recentSessions = const [];
  PostureSummary? _summary;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final sessions = await _postureHistoryService.loadSessions(limit: 4);
    final summary = await _postureHistoryService.loadSummary();
    if (!mounted) return;
    setState(() {
      _recentSessions = sessions;
      _summary = summary;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final isDark =
        Theme.of(
          context,
        ).brightness ==
        Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(
        context,
      ).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Select Exercise',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(
          context,
        ).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark
              ? const Color(
                  0xFFF1F5F9,
                )
              : Colors.black87,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(
          20.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(
                20.0,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(
                      0xFF4C5BF1,
                    ),
                    Color(
                      0xFF3B82F6,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(
                  20,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(
                          0xFF4C5BF1,
                        ).withValues(
                          alpha: 0.3,
                        ),
                    blurRadius: 15,
                    offset: const Offset(
                      0,
                      5,
                    ),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.fitness_center,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  const Text(
                    'Choose Your Exercise',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Select an exercise to analyze your form and posture',
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.9,
                      ),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            if (_summary != null)
              _PostureHistoryOverview(
                summary: _summary!,
                sessions: _recentSessions,
              ),
            if (_summary != null)
              const SizedBox(
                height: 24,
              ),

            // Exercise Grid
            Text(
              'Available Exercises',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? const Color(
                        0xFFF1F5F9,
                      )
                    : Colors.black87,
              ),
            ),
            const SizedBox(
              height: 16,
            ),

            // Exercise Cards Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: ExerciseType.values.length,
              itemBuilder:
                  (
                    context,
                    index,
                  ) {
                    final exercise = ExerciseType.values[index];
                    return _ExerciseCard(
                      exercise: exercise,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (
                                  context,
                                ) => PoseCameraPage(
                                  exerciseType: exercise,
                                ),
                          ),
                        ).then((_) => _loadHistory());
                      },
                    );
                  },
            ),
          ],
        ),
      ),
    );
  }
}

class _PostureHistoryOverview extends StatelessWidget {
  const _PostureHistoryOverview({
    required this.summary,
    required this.sessions,
  });

  final PostureSummary summary;
  final List<PostureSessionRecord> sessions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Posture Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.totalSessions == 0
                ? 'Complete a posture session to start building your form history.'
                : 'Average score ${summary.averageScore.toStringAsFixed(0)}% • Best exercise: ${summary.bestExercise}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...sessions.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20B2AA).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        session.exerciseType.icon,
                        color: const Color(0xFF20B2AA),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${session.exerciseType.name} • ${session.score.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            session.feedback,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseCard
    extends
        StatelessWidget {
  final ExerciseType exercise;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final isDark =
        Theme.of(
          context,
        ).brightness ==
        Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(
                  0xFF1E293B,
                )
              : Colors.white,
          borderRadius: BorderRadius.circular(
            16,
          ),
          border: Border.all(
            color:
                const Color(
                  0xFF20B2AA,
                ).withValues(
                  alpha: 0.3,
                ),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.05,
              ),
              blurRadius: 10,
              offset: const Offset(
                0,
                4,
              ),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(
            16.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(
                  12,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(
                        0xFF20B2AA,
                      ).withValues(
                        alpha: 0.1,
                      ),
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  exercise.icon,
                  color: const Color(
                    0xFF20B2AA,
                  ),
                  size: 32,
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              Text(
                exercise.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(
                          0xFFF1F5F9,
                        )
                      : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                exercise.description,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
