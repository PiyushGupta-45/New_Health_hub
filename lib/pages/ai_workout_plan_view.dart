import 'package:flutter/material.dart';
import '../services/hugging_face_service.dart';

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

  bool _isLoading = false;
  String? _error;
  String? _result;

  late final HuggingFaceService _aiService;

  @override
  void initState() {
    super.initState();
    _aiService = HuggingFaceService();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _durationController.dispose();
    _equipmentController.dispose();
    _intensityController.dispose();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    final goal = _goalController.text.trim();
    final duration = _durationController.text.trim();
    final equipment = _equipmentController.text.trim();
    final intensity = _intensityController.text.trim();

    final prompt = '''
Create a daily workout plan in simple bullet points.
Goal: ${goal.isEmpty ? 'Not specified' : goal}
Duration: ${duration.isEmpty ? '30 minutes' : duration}
Equipment: ${equipment.isEmpty ? 'None' : equipment}
Intensity: ${intensity.isEmpty ? 'Moderate' : intensity}

Include warm-up, main sets, and cool-down. Keep it safe and realistic.
''';

    try {
      final text = await _aiService.generateText(prompt);
      if (!mounted) return;
      setState(() => _result = text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
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
              'Daily Workout Plan',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick your goal and time. AI will build a simple daily plan you can follow.',
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
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generatePlan,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(_isLoading ? 'Generating...' : 'Generate with AI'),
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
                  : Text(
                      _result ?? 'AI plan will appear here once Hugging Face is connected.',
                      style: TextStyle(color: sub, fontSize: 14),
                    ),
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
