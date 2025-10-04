// workout_tracker_view.dart

import 'package:flutter/material.dart';
import 'personalized_goals_view.dart'; // Import Goal model and activeGoals list

// Reuse constants
const Color kPrimaryColor = Color(0xFF4C5BF1);
const Color kBackgroundColor = Color(0xFFF7F8FC);
const Color kAccentColor = Color(0xFFFF4500); // Orange Red for Workout Logs

// Simulated Log Data (as if imported from a smartwatch)
List<Map<String, String>> simulatedWatchLogs = [
  {
    'type': 'Running',
    'duration': '35 min',
    'distance': '5.2 km',
    'date': '2025-10-04',
  },
  {
    'type': 'Weightlifting',
    'duration': '60 min',
    'distance': 'N/A',
    'date': '2025-10-03',
  },
  {
    'type': 'Cycling',
    'duration': '45 min',
    'distance': '18.1 km',
    'date': '2025-10-02',
  },
];

class WorkoutTrackerView extends StatelessWidget {
  const WorkoutTrackerView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Goals and History
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
        body: const TabBarView(
          children: [
            _GoalsDisplayTab(), // Shows connected goals
            _LogHistoryTab(), // Shows simulated watch logs
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
    // Filter goals that are connected to the tracker and are not yet met (simulation)
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
                // Navigate back to the goals page
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
    // Simple simulation: 70% progress, always
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
  const _LogHistoryTab();

  @override
  Widget build(BuildContext context) {
    if (simulatedWatchLogs.isEmpty) {
      return const Center(child: Text('No workout data imported yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: simulatedWatchLogs.length,
      itemBuilder: (context, index) {
        final log = simulatedWatchLogs[index];
        return _WorkoutLogTile(log: log);
      },
    );
  }
}

class _WorkoutLogTile extends StatelessWidget {
  final Map<String, String> log;

  const _WorkoutLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          log['type'] == 'Running' || log['type'] == 'Walking'
              ? Icons.directions_run
              : Icons.fitness_center,
          color: kPrimaryColor,
          size: 30,
        ),
        title: Text(
          '${log['type']} - ${log['duration']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Distance: ${log['distance']}\nDate: ${log['date']}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}
