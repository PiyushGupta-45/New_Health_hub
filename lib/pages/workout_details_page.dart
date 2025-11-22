import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/health_sync_service.dart';
import '../services/workout_log_service.dart';

class WorkoutDetailsPage extends StatelessWidget {
  const WorkoutDetailsPage({
    super.key,
    required this.entry,
    this.manualLog,
    this.onDelete,
  });

  final WorkoutEntry entry;
  final ManualWorkoutLog? manualLog;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isManual = entry.sourceName == 'Manual Log';
    final duration = entry.duration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(entry.typeLabel),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? const Color(0xFFF1F5F9) : Colors.black87,
        elevation: 0,
        actions: [
          if (isManual && onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showDeleteDialog(context),
              tooltip: 'Delete workout',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getColorForWorkout(entry.typeLabel),
                    _getColorForWorkout(entry.typeLabel).withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _getColorForWorkout(entry.typeLabel).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    _getIconForWorkout(entry.typeLabel),
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    entry.typeLabel,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.sourceName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Duration Card
            _DetailCard(
              icon: Icons.timer_outlined,
              title: 'Duration',
              value: hours > 0
                  ? '${hours}h ${minutes}m ${seconds}s'
                  : minutes > 0
                      ? '${minutes}m ${seconds}s'
                      : '${seconds}s',
            ),

            // Calories Card
            if (entry.energyKcal != null && entry.energyKcal! > 0)
              _DetailCard(
                icon: Icons.local_fire_department_outlined,
                title: 'Calories Burned',
                value: '${entry.energyKcal!.toStringAsFixed(1)} kcal',
              ),

            // Distance Card
            if (entry.distanceKm != null && entry.distanceKm! > 0)
              _DetailCard(
                icon: Icons.straighten_outlined,
                title: 'Distance',
                value: '${entry.distanceKm!.toStringAsFixed(2)} km',
              ),

            // Steps Card
            if (entry.steps != null && entry.steps! > 0)
              _DetailCard(
                icon: Icons.directions_walk_outlined,
                title: 'Steps',
                value: '${entry.steps} steps',
              ),

            // Date & Time Card
            _DetailCard(
              icon: Icons.calendar_today_outlined,
              title: 'Date & Time',
              value: DateFormat('EEEE, MMMM d, y • h:mm a').format(entry.start),
            ),

            // MET value (if available from manual log)
            if (manualLog?.met != null)
              _DetailCard(
                icon: Icons.speed_outlined,
                title: 'Intensity (MET)',
                value: manualLog!.met!.toStringAsFixed(1),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout?'),
        content: const Text('This workout will be permanently deleted from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getColorForWorkout(String workoutType) {
    final normalized = workoutType.toLowerCase();
    if (normalized.contains('run')) return const Color(0xFFFF512F);
    if (normalized.contains('walk')) return const Color(0xFF56CCF2);
    if (normalized.contains('cycle') || normalized.contains('bike')) return const Color(0xFF0BAB64);
    if (normalized.contains('swim')) return const Color(0xFF00C9FF);
    if (normalized.contains('yoga')) return const Color(0xFF7F7FD5);
    if (normalized.contains('strength') || normalized.contains('weight')) return const Color(0xFFFFA751);
    if (normalized.contains('hiit')) return const Color(0xFFF7971E);
    if (normalized.contains('pilates')) return const Color(0xFF9B59B6);
    if (normalized.contains('boxing')) return const Color(0xFFE74C3C);
    if (normalized.contains('dance')) return const Color(0xFFE91E63);
    return const Color(0xFF4C5BF1);
  }

  IconData _getIconForWorkout(String workoutType) {
    final normalized = workoutType.toLowerCase();
    if (normalized.contains('run')) return Icons.directions_run_rounded;
    if (normalized.contains('walk')) return Icons.directions_walk_rounded;
    if (normalized.contains('cycle') || normalized.contains('bike')) return Icons.pedal_bike_rounded;
    if (normalized.contains('swim')) return Icons.pool_rounded;
    if (normalized.contains('yoga')) return Icons.self_improvement_rounded;
    if (normalized.contains('strength') || normalized.contains('weight')) return Icons.fitness_center_rounded;
    if (normalized.contains('hiit')) return Icons.bolt_rounded;
    if (normalized.contains('pilates')) return Icons.accessibility_new_rounded;
    if (normalized.contains('boxing')) return Icons.sports_mma_rounded;
    if (normalized.contains('dance')) return Icons.music_note_rounded;
    return Icons.fitness_center_rounded;
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF818CF8) : const Color(0xFF4C5BF1)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4C5BF1),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

