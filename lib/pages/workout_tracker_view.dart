// workout_tracker_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/health_sync_controller.dart';
import '../services/health_sync_service.dart';
import 'personalized_goals_view.dart'; // Import Goal model and activeGoals list

// Reuse constants
const Color kPrimaryColor = Color(0xFF4C5BF1);
const Color kBackgroundColor = Color(0xFFF7F8FC);
const Color kAccentColor = Color(0xFFFF4500); // Orange Red for Workout Logs

class WorkoutTrackerView extends StatefulWidget {
  const WorkoutTrackerView({super.key, required this.controller});

  final HealthSyncController controller;

  @override
  State<WorkoutTrackerView> createState() => _WorkoutTrackerViewState();
}

class _WorkoutTrackerViewState extends State<WorkoutTrackerView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    if (widget.controller.snapshot == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.sync();
      });
    }
  }

  @override
  void didUpdateWidget(covariant WorkoutTrackerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _syncNow() async {
    await widget.controller.sync(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Workout Tracker',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: kBackgroundColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          actions: [
            IconButton(
              onPressed: widget.controller.isSyncing ? null : _syncNow,
              tooltip: 'Sync now',
              icon: widget.controller.isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(50),
            child: TabBar(
              indicatorColor: kAccentColor,
              labelColor: kAccentColor,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(icon: Icon(Icons.flag_outlined), text: 'Active Goals'),
                Tab(icon: Icon(Icons.history), text: 'Log History'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            const _GoalsDisplayTab(),
            _LogHistoryTab(controller: widget.controller),
          ],
        ),
      ),
    );
  }
}

// --- TAB 1: ACTIVE GOALS DISPLAY ---
class _GoalsDisplayTab extends StatelessWidget {
  const _GoalsDisplayTab();

  @override
  Widget build(BuildContext context) {
    final connectedGoals = activeGoals
        .where((g) => g.connectToTracker)
        .toList();

    if (connectedGoals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text(
              'No goals connected to the tracker.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PersonalizedGoalsView(),
                  ),
                );
              },
              child: const Text(
                'Set a New Goal',
                style: TextStyle(color: kPrimaryColor),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: connectedGoals.length,
      itemBuilder: (context, index) {
        final goal = connectedGoals[index];
        return _GoalProgressCard(goal: goal);
      },
    );
  }
}

class _GoalProgressCard extends StatelessWidget {
  final Goal goal;

  const _GoalProgressCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    const double progress = 0.7;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Target: ${goal.target} ${goal.unit}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(kAccentColor),
            borderRadius: BorderRadius.circular(5),
            minHeight: 10,
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% Progress (Simulated)',
                style: TextStyle(fontSize: 12, color: kAccentColor),
              ),
              Text(
                'Due: ${goal.deadline.day}/${goal.deadline.month}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- TAB 2: LOG HISTORY DISPLAY ---
class _LogHistoryTab extends StatelessWidget {
  const _LogHistoryTab({required this.controller});

  final HealthSyncController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final status = controller.status;

    if (status == HealthSyncStatus.syncing && snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot == null) {
      return _EmptyState(
        icon: Icons.watch,
        title: 'Connect to your watch',
        description:
            'Sync with your Galaxy Watch to see workouts captured in Samsung Health.',
        actionLabel: 'Sync Now',
        onActionPressed: controller.isSyncing
            ? null
            : () => controller.sync(force: true),
      );
    }

    if (snapshot.workouts.isEmpty) {
      return _EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No workouts yet',
        description:
            'We could not find workouts in the last 7 days. Start a session on your watch and sync again.',
        actionLabel: 'Refresh',
        onActionPressed: controller.isSyncing
            ? null
            : () => controller.sync(force: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => controller.sync(force: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(20.0),
        itemCount: snapshot.workouts.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StepSourceSummary(
              stepsBySource: snapshot.stepsBySource,
              primarySource: controller.primaryStepsSource,
              lastSyncedAt: controller.lastSyncedAt,
            );
          }
          final entry = snapshot.workouts[index - 1];
          return _WorkoutLogTile(entry: entry);
        },
      ),
    );
  }
}

class _WorkoutLogTile extends StatelessWidget {
  const _WorkoutLogTile({required this.entry});

  final WorkoutEntry entry;

  @override
  Widget build(BuildContext context) {
    final durationLabel = _formatDuration(entry.duration);
    final distanceLabel = entry.distanceKm != null
        ? '${entry.distanceKm!.toStringAsFixed(entry.distanceKm! >= 10 ? 1 : 2)} km'
        : 'Distance not logged';
    final energyLabel = entry.energyKcal != null && entry.energyKcal! > 0
        ? '${entry.energyKcal!.toStringAsFixed(0)} kcal'
        : null;
    final stepsLabel = entry.steps != null && entry.steps! > 0
        ? '${entry.steps} steps'
        : null;
    final dateLabel = DateFormat('EEE, MMM d • h:mm a').format(entry.start);

    final details = <String>[
      distanceLabel,
      if (stepsLabel != null) stepsLabel,
      if (energyLabel != null) 'Energy: $energyLabel',
      'Source: ${entry.sourceName}',
      dateLabel,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.12), blurRadius: 6),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          _iconForWorkout(entry.typeLabel),
          color: kPrimaryColor,
          size: 32,
        ),
        title: Text(
          '${entry.typeLabel} • $durationLabel',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Text(
            details.join('\n'),
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: kPrimaryColor),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes} min';
  }

  static IconData _iconForWorkout(String workoutType) {
    final normalized = workoutType.toLowerCase();
    if (normalized.contains('run') || normalized.contains('walk')) {
      return Icons.directions_run;
    }
    if (normalized.contains('cycle') || normalized.contains('bike')) {
      return Icons.pedal_bike;
    }
    if (normalized.contains('swim')) {
      return Icons.pool;
    }
    if (normalized.contains('yoga')) {
      return Icons.self_improvement;
    }
    if (normalized.contains('strength') || normalized.contains('weight')) {
      return Icons.fitness_center;
    }
    return Icons.monitor_heart;
  }
}

class _StepSourceSummary extends StatelessWidget {
  const _StepSourceSummary({
    required this.stepsBySource,
    required this.primarySource,
    required this.lastSyncedAt,
  });

  final Map<String, int> stepsBySource;
  final String? primarySource;
  final DateTime? lastSyncedAt;

  @override
  Widget build(BuildContext context) {
    if (stepsBySource.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = stepsBySource.entries.toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stacked_line_chart, color: kPrimaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Step sources${primarySource != null ? ' • using $primarySource' : ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 14,
                        color: entry.key == primarySource
                            ? kPrimaryColor
                            : Colors.grey.shade700,
                        fontWeight: entry.key == primarySource
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    entry.value.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: entry.key == primarySource
                          ? kPrimaryColor
                          : Colors.grey.shade700,
                      fontWeight: entry.key == primarySource
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (lastSyncedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Last synced ${DateFormat('MMM d, h:mm a').format(lastSyncedAt!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final Future<void> Function()? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onActionPressed == null
                    ? null
                    : () async => await onActionPressed!(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
