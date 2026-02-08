import 'package:flutter/material.dart';
import '../services/openai_service.dart';

class AiDietView extends StatefulWidget {
  const AiDietView({super.key});

  @override
  State<AiDietView> createState() => _AiDietViewState();
}

class _AiDietViewState extends State<AiDietView> {
  final _goalController = TextEditingController();
  final _dietController = TextEditingController();
  final _allergyController = TextEditingController();
  final _mealsController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  String? _result;

  late final OpenAIService _openai;

  @override
  void initState() {
    super.initState();
    _openai = OpenAIService();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _dietController.dispose();
    _allergyController.dispose();
    _mealsController.dispose();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    final goal = _goalController.text.trim();
    final diet = _dietController.text.trim();
    final allergy = _allergyController.text.trim();
    final meals = _mealsController.text.trim();

    final prompt = '''
Create a daily diet plan in simple bullet points.
Goal: ${goal.isEmpty ? 'Not specified' : goal}
Diet type: ${diet.isEmpty ? 'Not specified' : diet}
Allergies: ${allergy.isEmpty ? 'None' : allergy}
Meals per day: ${meals.isEmpty ? '3' : meals}

Include meal timing and short portion guidance. Keep it realistic and safe.
''';

    try {
      final text = await _openai.generateText(prompt);
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
        title: const Text('Diet AI'),
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
              'Create a Diet Plan',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us your goal, preferences, and schedule. We will use AI to build a realistic daily plan.',
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
                    hint: 'Fat loss, muscle gain, maintenance',
                    controller: _goalController,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Diet Type',
                    hint: 'Vegetarian, keto, high-protein',
                    controller: _dietController,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Allergies',
                    hint: 'Nuts, dairy, gluten',
                    controller: _allergyController,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Meals per day',
                    hint: '3, 4, or 5',
                    controller: _mealsController,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generatePlan,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(_isLoading ? 'Generating...' : 'Generate with AI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
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
                      _result ?? 'AI result will appear here once Gemini is connected.',
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
