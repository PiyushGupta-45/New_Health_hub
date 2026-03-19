import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/habit_tracker_service.dart';

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  final HabitTrackerService _habitTrackerService = HabitTrackerService();
  final TextEditingController _notesController = TextEditingController();

  HabitEntry? _entry;
  bool _isLoading = true;
  bool _isSaving = false;

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    final entry = await _habitTrackerService.loadEntry(_todayKey);
    if (!mounted) return;
    _notesController.text = entry.notes;
    setState(() {
      _entry = entry;
      _isLoading = false;
    });
  }

  Future<void> _saveEntry(HabitEntry entry) async {
    setState(() {
      _isSaving = true;
      _entry = entry;
    });
    await _habitTrackerService.saveEntry(entry);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF111827);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    if (_isLoading || _entry == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entry = _entry!;
    final score = [
      if (entry.waterLiters >= 2.0) 1,
      if (entry.sleepHours >= 7.0) 1,
      if (entry.meditated) 1,
      if (entry.tookSupplements) 1,
      if (entry.mood >= 4) 1,
    ].length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Habit Tracker'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: text,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F4CFF), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Wellness Loop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$score / 5 daily wellness targets completed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
                if (_isSaving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _MetricCard(
            title: 'Water Intake',
            subtitle: 'Target 2.0 liters',
            valueLabel: '${entry.waterLiters.toStringAsFixed(1)} L',
            child: Slider(
              min: 0,
              max: 5,
              value: entry.waterLiters.clamp(0, 5),
              onChanged: (value) {
                _saveEntry(entry.copyWith(waterLiters: value));
              },
            ),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'Sleep',
            subtitle: 'Target 7+ hours',
            valueLabel: '${entry.sleepHours.toStringAsFixed(1)} hrs',
            child: Slider(
              min: 0,
              max: 12,
              value: entry.sleepHours.clamp(0, 12),
              onChanged: (value) {
                _saveEntry(entry.copyWith(sleepHours: value));
              },
            ),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'Recovery Habits',
            subtitle: 'Check off the supporting habits you completed',
            valueLabel: '',
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Meditation or breathwork', style: TextStyle(color: text)),
                  value: entry.meditated,
                  onChanged: (value) => _saveEntry(entry.copyWith(meditated: value)),
                ),
                SwitchListTile(
                  title: Text('Supplements taken', style: TextStyle(color: text)),
                  value: entry.tookSupplements,
                  onChanged: (value) =>
                      _saveEntry(entry.copyWith(tookSupplements: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'Mood',
            subtitle: 'How are you feeling today?',
            valueLabel: entry.mood == 0 ? 'Not rated yet' : '${entry.mood}/5',
            child: Wrap(
              spacing: 10,
              children: List.generate(
                5,
                (index) {
                  final value = index + 1;
                  final selected = entry.mood == value;
                  return ChoiceChip(
                    label: Text('$value'),
                    selected: selected,
                    onSelected: (_) => _saveEntry(entry.copyWith(mood: value)),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notes',
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'How did your day feel? Anything affecting recovery?',
                  ),
                  onChanged: (value) => _saveEntry(entry.copyWith(notes: value)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Habit tracking helps the new streak and readiness features work better.',
                  style: TextStyle(fontSize: 12, color: sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.subtitle,
    required this.valueLabel,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String valueLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF111827);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (valueLabel.isNotEmpty)
                Text(
                  valueLabel,
                  style: TextStyle(
                    color: const Color(0xFF2563EB),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: sub, fontSize: 12),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
