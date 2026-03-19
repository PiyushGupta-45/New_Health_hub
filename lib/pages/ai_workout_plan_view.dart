import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/adaptive_workout_service.dart';
import '../services/hugging_face_service.dart';
import '../services/workout_plan_schedule_service.dart';
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
  final _adaptiveReasonController = TextEditingController();

  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isApproving = false;
  bool _isApplyingChanges = false;
  bool _isAdapting = false;
  bool _showChangeBox = false;
  bool _showAdaptiveBox = false;
  String? _error;
  String? _result;
  String _lastRefinementNote = '';
  WeeklyWorkoutPlan? _savedPlan;
  WorkoutPlanSchedule? _schedule;
  int _selectedDayIndex = 0;

  late final HuggingFaceService _aiService;
  late final WeeklyWorkoutPlanService _planService;
  late final WorkoutPlanScheduleService _scheduleService;
  late final AdaptiveWorkoutService _adaptiveWorkoutService;

  @override
  void initState() {
    super.initState();
    _aiService = HuggingFaceService();
    _planService = WeeklyWorkoutPlanService();
    _scheduleService = WorkoutPlanScheduleService();
    _adaptiveWorkoutService = const AdaptiveWorkoutService();
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
    _adaptiveReasonController.dispose();
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
      final schedule = await _scheduleService.loadForPlan(localPlan);
      if (!mounted) return;
      setState(() {
        _result = text;
        _savedPlan = localPlan;
        _schedule = schedule;
        _showChangeBox = false;
        _selectedDayIndex = schedule?.currentDayIndex ?? 0;
        if (refinement != null && refinement.trim().isNotEmpty) {
          _lastRefinementNote = refinement.trim();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isApplyingChanges = false;
        });
      }
    }
  }

  Future<void> _loadSavedPlan() async {
    final planResult = await _planService.getLatestApprovedPlan();
    final plan = planResult['success'] == true
        ? planResult['data'] as WeeklyWorkoutPlan?
        : await _planService.loadLocalPlan();
    final schedule = await _scheduleService.loadForPlan(plan);

    if (!mounted) return;
    setState(() {
      _savedPlan = plan;
      _result = plan?.planText;
      _schedule = schedule;
      _selectedDayIndex = schedule?.currentDayIndex ?? 0;
      _isInitializing = false;
    });
  }

  Future<void> _toggleChecklist(String dayKey, String workoutKey, bool value) async {
    final plan = _savedPlan;
    if (plan == null) return;
    await _scheduleService.toggleTask(
      plan: plan,
      dayLabel: dayKey,
      taskTitle: workoutKey,
      value: value,
    );
    final updated = await _scheduleService.loadForPlan(plan);
    if (!mounted) return;
    setState(() {
      _schedule = updated;
    });
  }

  bool _isDayComplete(String dayKey) {
    final schedule = _schedule;
    if (schedule == null) return false;
    WorkoutPlanDay? day;
    for (final item in schedule.days) {
      if (item.label == dayKey) {
        day = item;
        break;
      }
    }
    return day?.isComplete ?? false;
  }

  Future<void> _toggleDayChecklist(String dayKey, bool value) async {
    final plan = _savedPlan;
    if (plan == null) return;
    await _scheduleService.toggleDay(
      plan: plan,
      dayLabel: dayKey,
      value: value,
    );
    final updated = await _scheduleService.loadForPlan(plan);
    if (!mounted) return;
    setState(() {
      _schedule = updated;
    });
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
    await _scheduleService.clear();
    if (!mounted) return;
    setState(() {
      _savedPlan = null;
      _result = null;
      _error = null;
      _schedule = null;
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
    await _scheduleService.clear();
    if (!mounted) return;
    setState(() {
      _savedPlan = null;
      _result = null;
      _error = null;
      _schedule = null;
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

  Future<void> _runAdaptiveRegeneration() async {
    final plan = _savedPlan;
    final schedule = _schedule;
    if (plan == null || schedule == null) return;

    setState(() {
      _isAdapting = true;
      _error = null;
    });

    final refinement = _adaptiveWorkoutService.buildAdaptiveRefinement(
      plan: plan,
      schedule: schedule,
      userReason: _adaptiveReasonController.text,
    );

    try {
      await _generatePlan(refinement: refinement);
      if (!mounted) return;
      setState(() {
        _showAdaptiveBox = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adaptive workout plan generated for the updated week.'),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAdapting = false;
        });
      }
    }
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

  Widget _buildAdaptivePlanSection() {
    final schedule = _schedule;
    if (schedule == null) return const SizedBox.shrink();

    final hasBacklog = schedule.backlogDays.isNotEmpty;
    final helper = hasBacklog
        ? 'Missed workouts were found. Regenerate the week so the remaining days are more realistic.'
        : 'Use this when your energy, soreness, or schedule changes and you want the plan to adapt.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adaptive Workout Plan',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                helper,
                style: const TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (hasBacklog) ...[
                const SizedBox(height: 10),
                Text(
                  'Backlog detected: ${schedule.backlogDays.map((day) => day.label).join(', ')}',
                  style: const TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isAdapting || _isLoading || _isApplyingChanges
                    ? null
                    : () {
                        setState(() {
                          _showAdaptiveBox = !_showAdaptiveBox;
                        });
                      },
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: Text(
                  _showAdaptiveBox ? 'Hide Adaptive Options' : 'Adapt This Week',
                ),
              ),
              if (_showAdaptiveBox) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _adaptiveReasonController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: hasBacklog
                        ? 'Example: I missed 2 strength days and want a lighter catch-up week.'
                        : 'Example: lower body is sore, shift intensity toward mobility and upper body.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isAdapting || _isLoading || _isApplyingChanges
                        ? null
                        : _runAdaptiveRegeneration,
                    icon: _isAdapting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _isAdapting ? 'Adapting Plan...' : 'Regenerate Smarter Week',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistSection() {
    final schedule = _schedule;
    if (schedule == null || schedule.days.isEmpty) {
      return const SizedBox.shrink();
    }
    final safeIndex = _selectedDayIndex.clamp(0, schedule.days.length - 1);
    final day = schedule.days[safeIndex];
    final dayKey = day.label;
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
          onChanged: (value) {
            _toggleDayChecklist(dayKey, value ?? false);
          },
          title: Text(
            _dayCheckboxLabel(dayKey),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (schedule.backlogDays.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '${schedule.backlogDays.length} earlier day(s) moved to backlog in Workout Tracker until completed.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 8),
        ...day.tasks.map(
          (task) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: task.isDone,
            onChanged: (value) {
              _toggleChecklist(dayKey, task.title, value ?? false);
            },
            title: Text(task.title),
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
                              if (_savedPlan != null) ...[
                                _buildChecklistSection(),
                                _buildAdaptivePlanSection(),
                              ],
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
