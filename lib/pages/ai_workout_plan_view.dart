import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/hugging_face_service.dart';
import '../services/weekly_workout_plan_service.dart';
import '../widgets/ai_result_renderer.dart';

class AiWorkoutPlanView extends StatefulWidget {
  const AiWorkoutPlanView({super.key});

  @override
  State<AiWorkoutPlanView> createState() => _AiWorkoutPlanViewState();
}

class _AiWorkoutPlanViewState extends State<AiWorkoutPlanView> {
  final _goalController = TextEditingController();
  final _durationController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _intensityController = TextEditingController();
  final _injuryController = TextEditingController();
  final _changeRequestController = TextEditingController();

  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isApproving = false;
  bool _isApplyingChanges = false;
  bool _showChangeBox = false;
  String? _error;
  String? _result;
  String _lastRefinementNote = '';
  WeeklyWorkoutPlan? _savedPlan;
  Map<String, Map<String, bool>> _checklistStatus = {};
  List<String> _dayOrder = [];
  int _selectedDayIndex = 0;

  late final HuggingFaceService _aiService;
  late final WeeklyWorkoutPlanService _planService;
  static const String _checklistKey = 'workout_ai_plan_checklist_v1';

  @override
  void initState() {
    super.initState();
    _aiService = HuggingFaceService();
    _planService = WeeklyWorkoutPlanService();
    _loadSavedPlan();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _durationController.dispose();
    _equipmentController.dispose();
    _intensityController.dispose();
    _injuryController.dispose();
    _changeRequestController.dispose();
    super.dispose();
  }

  Future<void> _generatePlan({String? refinement}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = refinement == null;
      _isApplyingChanges = refinement != null;
      _error = null;
      if (refinement == null) {
        _result = null;
        _showChangeBox = false;
      }
    });

    final goal = _goalController.text.trim();
    final duration = _durationController.text.trim();
    final equipment = _equipmentController.text.trim();
    final intensity = _intensityController.text.trim();
    final injury = _injuryController.text.trim();

    final selectedGoal = goal.isEmpty ? 'Not specified' : goal;
    final selectedDuration = duration.isEmpty ? '30 minutes' : duration;
    final selectedEquipment = equipment.isEmpty ? 'None' : equipment;
    final selectedIntensity = intensity.isEmpty ? 'Moderate' : intensity;
    final selectedInjury = injury.isEmpty ? 'No injury' : injury;

    const systemPrompt = '''
You are a strict workout planning assistant.
Follow user-selected inputs exactly.
Never change, replace, or reinterpret selected values.
Do not add conflicting assumptions.
Return concise markdown only.
''';

    final prompt = '''
Create a 7-DAY WEEKLY workout plan using these exact selected inputs:
- Goal: $selectedGoal
- Duration: $selectedDuration
- Equipment: $selectedEquipment
- Intensity: $selectedIntensity
- Injury: $selectedInjury

Rules:
1) Use these selected values exactly as written above.
2) Do not include exercises requiring equipment not listed.
3) Respect injury: if injury is present, avoid stressing that area and add safer alternatives.
4) Keep each day session duration aligned with selected duration.
4) Keep intensity aligned with selected intensity.
5) Keep output short, safe, and practical.
6) Include one rest/recovery day.
${refinement != null && refinement.trim().isNotEmpty ? '7) Also apply this user change request exactly where possible: ${refinement.trim()}' : ''}

Output format (follow exactly):
## Inputs Echo
- Goal: <exact value>
- Duration: <exact value>
- Equipment: <exact value>
- Intensity: <exact value>
- Injury: <exact value>

## Plan
- Day 1: ...
- Day 2: ...
- Day 3: ...
- Day 4: ...
- Day 5: ...
- Day 6: ...
- Day 7: ...

## Notes
- 2 to 4 short safety/progression notes.
''';

    try {
      final text = await _aiService.generateText(
        prompt,
        systemPrompt: systemPrompt,
        temperature: 0.1,
        maxTokens: 1000,
      );
      final localPlan = await _planService.saveLocalPlanOnly(
        goal: selectedGoal,
        duration: selectedDuration,
        equipment: selectedEquipment,
        intensity: selectedIntensity,
        injury: selectedInjury,
        notes: refinement?.trim() ?? _lastRefinementNote,
        planText: text,
      );
      if (!mounted) return;
      setState(() {
        _result = text;
        _savedPlan = localPlan;
        _showChangeBox = false;
        final parsedChecklist = _buildChecklistFromPlan(localPlan.planText);
        _checklistStatus = parsedChecklist;
        _dayOrder = parsedChecklist.keys.toList();
        _selectedDayIndex = _resolveTodayDayIndex(
          plan: localPlan,
          dayOrder: _dayOrder,
        );
        if (refinement != null && refinement.trim().isNotEmpty) {
          _lastRefinementNote = refinement.trim();
        }
      });
      await _saveChecklist();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isApplyingChanges = false;
      });
    }
  }

  Future<void> _loadSavedPlan() async {
    final plan = await _planService.loadLocalPlan();
    Map<String, Map<String, bool>> checklist = {};
    List<String> dayOrder = [];
    if (plan != null) {
      checklist = _buildChecklistFromPlan(plan.planText);
      dayOrder = checklist.keys.toList();
      final savedChecklist = await _loadChecklistState();
      if (savedChecklist.isNotEmpty && dayOrder.isNotEmpty) {
        final savedStatus = savedChecklist['status'];
        if (savedStatus is Map<String, dynamic>) {
          final merged = <String, Map<String, bool>>{};
          for (final day in dayOrder) {
            final currentDay = checklist[day] ?? <String, bool>{};
            final savedDayRaw = savedStatus[day];
            if (savedDayRaw is Map<String, dynamic>) {
              merged[day] = {
                for (final workout in currentDay.keys)
                  workout: savedDayRaw[workout] == true ||
                      savedDayRaw[workout] == 'true',
              };
            } else {
              merged[day] = currentDay;
            }
          }
          checklist = merged;
        }
      }
      _selectedDayIndex = _resolveTodayDayIndex(plan: plan, dayOrder: dayOrder);
      if (savedChecklist.isEmpty) {
        final legacy = await _loadChecklist();
        if (legacy.isNotEmpty) {
          final firstDay = dayOrder.isNotEmpty ? dayOrder.first : null;
          if (firstDay != null) {
            final firstWorkouts = checklist[firstDay] ?? <String, bool>{};
            checklist[firstDay] = {
              for (final workout in firstWorkouts.keys)
                workout: legacy[workout] ?? false,
            };
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _savedPlan = plan;
      _result = plan?.planText;
      _checklistStatus = checklist;
      _dayOrder = dayOrder;
      _isInitializing = false;
    });
  }

  Map<String, Map<String, bool>> _buildChecklistFromPlan(String planText) {
    final lines = planText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final dayHeaderPattern = RegExp(r'^-?\s*(day\s*\d+)\s*:?\s*(.*)$', caseSensitive: false);
    final dayToRawItems = <String, List<String>>{};
    String? currentDay;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('## notes')) {
        currentDay = null;
        continue;
      }

      final normalized = line.replaceFirst(RegExp(r'^-\s*'), '');
      final dayMatch = dayHeaderPattern.firstMatch(normalized);
      if (dayMatch != null) {
        final dayLabel = dayMatch.group(1)!.trim();
        final dayRemainder = (dayMatch.group(2) ?? '').trim();
        currentDay = dayLabel[0].toUpperCase() + dayLabel.substring(1).toLowerCase();
        dayToRawItems.putIfAbsent(currentDay, () => <String>[]);
        if (dayRemainder.isNotEmpty) {
          dayToRawItems[currentDay]!.add(dayRemainder);
        }
        continue;
      }

      if (currentDay == null) continue;
      if (lower.startsWith('## ')) continue;
      if (lower.startsWith('inputs echo')) continue;
      if (lower.startsWith('plan')) continue;

      final bulletMatch = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);
      if (bulletMatch != null) {
        dayToRawItems[currentDay]!.add(bulletMatch.group(1)!.trim());
        continue;
      }

      final numberedMatch = RegExp(r'^\d+\.\s+(.+)$').firstMatch(line);
      if (numberedMatch != null) {
        dayToRawItems[currentDay]!.add(numberedMatch.group(1)!.trim());
        continue;
      }
    }

    if (dayToRawItems.isEmpty) {
      return {for (int i = 1; i <= 7; i++) 'Day $i': {'Workout': false}};
    }

    final checklist = <String, Map<String, bool>>{};
    for (final entry in dayToRawItems.entries) {
      final items = _splitWorkoutItems(entry.value);
      checklist[entry.key] = {
        for (final item in items) item: false,
      };
    }
    return checklist;
  }

  List<String> _splitWorkoutItems(List<String> rawItems) {
    if (rawItems.isEmpty) return <String>['Workout'];

    final expanded = <String>[];
    for (final raw in rawItems) {
      var normalized = raw
          .replaceAll(';', ', ')
          .replaceAll('+', ', ')
          .replaceAll('|', ', ')
          .replaceAll(' / ', ', ')
          .replaceAll(RegExp(r'\s+and\s+', caseSensitive: false), ', ');

      normalized = normalized.replaceAll(RegExp(r',+'), ',');
      final parts = normalized
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty);
      expanded.addAll(parts);
    }

    final deduped = <String>[];
    final seen = <String>{};
    for (final item in expanded) {
      final normalizedKey = item.toLowerCase();
      if (seen.add(normalizedKey)) {
        deduped.add(item);
      }
    }

    if (deduped.isEmpty) return <String>['Workout'];
    return deduped;
  }

  Future<Map<String, bool>> _loadChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_checklistKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('status')) {
          return {};
        }
        return {
          for (final entry in decoded.entries)
            entry.key: entry.value == true || entry.value == 'true',
        };
      }
    } catch (_) {
      return {};
    }
    return {};
  }

  Future<void> _saveChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _checklistKey,
      json.encode({
        'status': _checklistStatus,
      }),
    );
  }

  Future<Map<String, dynamic>> _loadChecklistState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_checklistKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return {};
    }
    return {};
  }

  Future<void> _toggleChecklist(String dayKey, String workoutKey, bool value) async {
    setState(() {
      final dayMap = _checklistStatus[dayKey];
      if (dayMap == null) return;
      dayMap[workoutKey] = value;
    });
    await _saveChecklist();
  }

  bool _isDayComplete(String dayKey) {
    final workouts = _checklistStatus[dayKey];
    if (workouts == null || workouts.isEmpty) return false;
    return workouts.values.every((isDone) => isDone);
  }

  Future<void> _toggleDayChecklist(String dayKey, bool value) async {
    setState(() {
      final workouts = _checklistStatus[dayKey];
      if (workouts == null) return;
      for (final key in workouts.keys.toList()) {
        workouts[key] = value;
      }
    });
    await _saveChecklist();
  }

  int _resolveTodayDayIndex({
    required WeeklyWorkoutPlan? plan,
    required List<String> dayOrder,
  }) {
    if (dayOrder.isEmpty) return 0;
    final anchor = plan?.approvedAt ?? plan?.createdAt ?? DateTime.now();
    final anchorDate = DateTime(anchor.year, anchor.month, anchor.day);
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final dayDiff = todayDate.difference(anchorDate).inDays;
    if (dayDiff <= 0) return 0;
    if (dayDiff >= dayOrder.length) return dayOrder.length - 1;
    return dayDiff;
  }

  String _dayCheckboxLabel(String dayKey) {
    final text = _result;
    if (text == null || text.trim().isEmpty) return dayKey;
    final pattern = RegExp(
      '^${RegExp.escape(dayKey)}\\s*:\\s*(.+)\$',
      caseSensitive: false,
    );
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    for (final line in lines) {
      final normalized = line.replaceFirst(RegExp(r'^[-*]\s*'), '');
      final match = pattern.firstMatch(normalized);
      if (match == null) continue;
      final remainder = match.group(1)?.trim() ?? '';
      if (remainder.isEmpty) return dayKey;
      final focus = remainder
          .split(RegExp(r',|;|\.|\+|\||\sand\s', caseSensitive: false))
          .map((part) => part.trim())
          .firstWhere((part) => part.isNotEmpty, orElse: () => remainder);
      return '$dayKey: $focus';
    }
    return dayKey;
  }

  Future<void> _deleteSavedPlan() async {
    await _planService.clearLocalPlans();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_checklistKey);
    if (!mounted) return;
    setState(() {
      _savedPlan = null;
      _result = null;
      _error = null;
      _checklistStatus = {};
      _dayOrder = [];
      _selectedDayIndex = 0;
      _goalController.clear();
      _durationController.clear();
      _equipmentController.clear();
      _intensityController.clear();
      _injuryController.clear();
      _changeRequestController.clear();
      _showChangeBox = false;
    });
  }

  Future<void> _startNewPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_checklistKey);
    if (!mounted) return;
    setState(() {
      _savedPlan = null;
      _result = null;
      _error = null;
      _checklistStatus = {};
      _dayOrder = [];
      _selectedDayIndex = 0;
      _showChangeBox = false;
    });
  }

  Future<void> _approvePlan() async {
    final planText = _result?.trim();
    if (planText == null || planText.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isApproving = true;
      _error = null;
    });

    final result = await _planService.saveApprovedPlan(
      goal: _goalController.text.trim().isEmpty
          ? 'Not specified'
          : _goalController.text.trim(),
      duration: _durationController.text.trim().isEmpty
          ? '30 minutes'
          : _durationController.text.trim(),
      equipment: _equipmentController.text.trim().isEmpty
          ? 'None'
          : _equipmentController.text.trim(),
      intensity: _intensityController.text.trim().isEmpty
          ? 'Moderate'
          : _intensityController.text.trim(),
      injury: _injuryController.text.trim().isEmpty
          ? 'No injury'
          : _injuryController.text.trim(),
      notes: _lastRefinementNote,
      planText: planText,
    );

    if (!mounted) return;
    setState(() {
      _isApproving = false;
    });

    if (result['success'] == true) {
      final isLocalOnly = result['localOnly'] == true;
      final warning = result['warning']?.toString();
      if (isLocalOnly && warning != null && warning.isNotEmpty && kDebugMode) {
        debugPrint('Workout plan saved locally (backend unavailable): $warning');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLocalOnly
                ? 'Plan approved. Saved locally for now and visible in Track Workout.'
                : 'Weekly plan approved and saved. It is now visible in Track Workout.',
          ),
          backgroundColor: isLocalOnly ? Colors.orange : Colors.green,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['error']?.toString() ?? 'Failed to approve plan'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _applyChanges() async {
    final changeText = _changeRequestController.text.trim();
    if (changeText.isEmpty) return;
    await _generatePlan(refinement: changeText);
  }

  Widget _buildPostGenerationActions(BuildContext context) {
    final isBusy = _isLoading || _isApplyingChanges || _isApproving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () {
                        setState(() {
                          _showChangeBox = !_showChangeBox;
                        });
                      },
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(_showChangeBox ? 'Hide Changes' : 'Change Something'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : _approvePlan,
                icon: _isApproving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Approve Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        if (_showChangeBox) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _changeRequestController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Example: make Day 3 low impact and reduce jumping due to knee pain',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isApplyingChanges || _isLoading || _isApproving
                  ? null
                  : _applyChanges,
              icon: _isApplyingChanges
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isApplyingChanges ? 'Updating Plan...' : 'Send Change Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSavedPlanActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isLoading || _isApplyingChanges || _isApproving
                ? null
                : _startNewPlan,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create New'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading || _isApplyingChanges || _isApproving
                ? null
                : _deleteSavedPlan,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistSection() {
    if (_checklistStatus.isEmpty || _dayOrder.isEmpty) {
      return const SizedBox.shrink();
    }
    final dayKey = _dayOrder[_selectedDayIndex];
    final workouts = _checklistStatus[dayKey] ?? <String, bool>{};
    final dayComplete = _isDayComplete(dayKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text(
          'Workout Checklist',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: dayComplete,
          onChanged: (value) => _toggleDayChecklist(dayKey, value ?? false),
          title: Text(
            _dayCheckboxLabel(dayKey),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        ...workouts.entries.map(
          (entry) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: entry.value,
            onChanged: (value) =>
                _toggleChecklist(dayKey, entry.key, value ?? false),
            title: Text(entry.key),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF111827) : Colors.white;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Workout AI'),
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: text,
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Workout Plan',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick your goal and constraints. AI will build a 7-day plan you can revise and approve.',
              style: TextStyle(fontSize: 14, color: sub, height: 1.4),
            ),
            const SizedBox(height: 20),
            if (_savedPlan == null)
              Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(
                    label: 'Goal',
                    hint: 'Strength, endurance, fat loss',
                    controller: _goalController,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Duration',
                    hint: '20, 30, 45 minutes',
                    controller: _durationController,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Equipment',
                    hint: 'None, dumbbells, gym',
                    controller: _equipmentController,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Intensity',
                    hint: 'Easy, moderate, hard',
                    controller: _intensityController,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Injury (if any)',
                    hint: 'Knee pain, lower back strain, none',
                    controller: _injuryController,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _isApproving || _isApplyingChanges
                          ? null
                          : () => _generatePlan(),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(_isLoading ? 'Generating...' : 'Generate Weekly Plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_savedPlan != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: _buildSavedPlanActions(),
              ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: _error != null
                  ? Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    )
                  : (_result == null
                        ? Text(
                            'AI plan will appear here once Hugging Face is connected.',
                            style: TextStyle(color: sub, fontSize: 14),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AIResultRenderer(rawText: _result!),
                              const SizedBox(height: 12),
                              if (_savedPlan == null)
                                _buildPostGenerationActions(context),
                              if (_savedPlan != null) _buildChecklistSection(),
                            ],
                          )),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: sub),
            filled: true,
            fillColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
