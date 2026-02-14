import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  bool _isApproving = false;
  bool _isApplyingChanges = false;
  bool _showChangeBox = false;
  String? _error;
  String? _result;
  String _lastRefinementNote = '';

  late final HuggingFaceService _aiService;
  late final WeeklyWorkoutPlanService _planService;

  @override
  void initState() {
    super.initState();
    _aiService = HuggingFaceService();
    _planService = WeeklyWorkoutPlanService();
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
      if (!mounted) return;
      setState(() {
        _result = text;
        if (refinement != null && refinement.trim().isNotEmpty) {
          _lastRefinementNote = refinement.trim();
        }
      });
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
      body: SingleChildScrollView(
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
                              _buildPostGenerationActions(context),
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
