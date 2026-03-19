import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/ai_diet_plan_storage_service.dart';
import '../services/meal_tracker_service.dart';

class MealTrackerPage extends StatefulWidget {
  const MealTrackerPage({super.key});

  @override
  State<MealTrackerPage> createState() => _MealTrackerPageState();
}

class _MealTrackerPageState extends State<MealTrackerPage> {
  final MealTrackerService _mealTrackerService = MealTrackerService();
  final AiDietPlanStorageService _dietPlanStorageService =
      AiDietPlanStorageService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  List<MealLogEntry> _todayEntries = <MealLogEntry>[];
  AiDietPlan? _dietPlan;

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _mealTrackerService.loadEntriesForDate(_todayKey);
    final dietPlan = await _dietPlanStorageService.load();
    if (!mounted) return;
    setState(() {
      _todayEntries = entries;
      _dietPlan = dietPlan;
      _isLoading = false;
    });
  }

  Future<void> _showAddMealSheet() async {
    final mealTypeController = TextEditingController(text: 'Lunch');
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    final caloriesController = TextEditingController();
    String adherence = 'Matches AI plan';
    XFile? photo;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Log Meal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: mealTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Meal type',
                        hintText: 'Breakfast, lunch, snack',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Meal name',
                        hintText: 'Paneer wrap, oats bowl, chicken salad',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: caloriesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Estimated calories',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Portions, ingredients, hunger level',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: adherence,
                      decoration: const InputDecoration(
                        labelText: 'Plan match',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Matches AI plan',
                          child: Text('Matches AI plan'),
                        ),
                        DropdownMenuItem(
                          value: 'Close to plan',
                          child: Text('Close to plan'),
                        ),
                        DropdownMenuItem(
                          value: 'Off plan / treat meal',
                          child: Text('Off plan / treat meal'),
                        ),
                      ],
                      onChanged: (value) {
                        setSheetState(() {
                          adherence = value ?? adherence;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await _picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 70,
                        );
                        if (picked == null) return;
                        setSheetState(() {
                          photo = picked;
                        });
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        photo == null ? 'Add Meal Photo' : 'Retake Photo',
                      ),
                    ),
                    if (photo != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(photo!.path),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;
                          final calories =
                              int.tryParse(caloriesController.text.trim()) ?? 0;
                          final entry = MealLogEntry(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            loggedAt: DateTime.now(),
                            mealType: mealTypeController.text.trim().isEmpty
                                ? 'Meal'
                                : mealTypeController.text.trim(),
                            title: title,
                            notes: notesController.text.trim(),
                            calories: calories,
                            photoPath: photo?.path,
                            adherenceLabel: adherence,
                          );
                          await _mealTrackerService.saveEntry(entry);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await _load();
                        },
                        child: const Text('Save Meal'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEntry(MealLogEntry entry) async {
    await _mealTrackerService.deleteEntry(entry.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF111827);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final totalCalories = _todayEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.calories,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Meal Tracker'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: text,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMealSheet,
        icon: const Icon(Icons.add),
        label: const Text('Log Meal'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Nutrition',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_todayEntries.length} meal(s) logged • $totalCalories kcal',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        if (_dietPlan != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'AI plan: ${_dietPlan!.goal} • ${_dietPlan!.dietType} • ${_dietPlan!.mealsPerDay} meals/day',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_dietPlan != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Use the meal log to compare what you actually ate against your latest Diet AI plan. Mark each meal as on-plan, close, or off-plan.',
                        style: TextStyle(color: sub, height: 1.45),
                      ),
                    ),
                  if (_todayEntries.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'No meals logged yet today. Tap "Log Meal" to add your first meal and attach a photo.',
                        style: TextStyle(color: sub),
                      ),
                    ),
                  ..._todayEntries.map(
                    (entry) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
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
                                  '${entry.mealType} • ${entry.title}',
                                  style: TextStyle(
                                    color: text,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _deleteEntry(entry),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                          Text(
                            DateFormat('h:mm a').format(entry.loggedAt),
                            style: TextStyle(color: sub, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _InfoChip(label: '${entry.calories} kcal'),
                              _InfoChip(label: entry.adherenceLabel),
                            ],
                          ),
                          if (entry.notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              entry.notes,
                              style: TextStyle(color: sub, height: 1.4),
                            ),
                          ],
                          if (entry.photoPath != null &&
                              entry.photoPath!.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(entry.photoPath!),
                                height: 170,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return Container(
                                    height: 120,
                                    alignment: Alignment.center,
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    child: Text(
                                      'Photo unavailable',
                                      style: TextStyle(color: sub),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
