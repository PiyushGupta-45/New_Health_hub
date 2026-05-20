import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/hugging_face_service.dart';
import '../services/ai_diet_plan_storage_service.dart';
import '../widgets/ai_result_renderer.dart';
import 'meal_tracker_page.dart';

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

  static const List<String> _goalOptions = [
    'Fat loss',
    'Muscle gain',
    'Maintenance',
    'High energy',
    'Healthy eating',
    'Other',
  ];
  static const List<String> _dietOptions = [
    'Balanced',
    'Vegetarian',
    'Vegan',
    'Keto',
    'High-protein',
    'Other',
  ];
  static const List<String> _allergyOptions = [
    'None',
    'Nuts',
    'Dairy',
    'Gluten',
    'Eggs',
    'Other',
  ];
  static const List<String> _mealOptions = [
    '3',
    '4',
    '5',
    '6',
    'Other',
  ];

  bool _isLoading = false;
  bool _isInitializing = true;
  String? _error;
  String? _result;
  AiDietPlan? _savedPlan;
  String? _selectedGoal;
  String? _selectedDiet;
  String? _selectedAllergy;
  String? _selectedMeals;

  late final HuggingFaceService _aiService;
  late final AiDietPlanStorageService _dietPlanStorage;

  @override
  void initState() {
    super.initState();
    _aiService = HuggingFaceService();
    _dietPlanStorage = AiDietPlanStorageService();
    _loadSavedPlan();
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
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    final selectedGoal = _resolvedGoal();
    final selectedDiet = _resolvedDiet();
    final selectedAllergy = _resolvedAllergy();
    final selectedMeals = _resolvedMeals();

    const systemPrompt = '''
You are a strict diet planning assistant.
Follow user-selected inputs exactly.
Never change, replace, or reinterpret selected values.
Do not add conflicting assumptions.
Return concise markdown only.
''';

    final prompt = '''
Create a ONE-DAY diet plan using these exact selected inputs:
- Goal: $selectedGoal
- Diet type: $selectedDiet
- Allergies: $selectedAllergy
- Meals per day: $selectedMeals

Rules:
1) Use these selected values exactly as written above.
2) Do not suggest foods that violate allergies.
3) Keep the plan realistic and safe for a general healthy adult.
4) Keep output short and practical.
5) If an input is "Not specified", keep recommendations generic and say "Not specified" in Inputs Echo.

Output format (follow exactly):
## Inputs Echo
- Goal: <exact value>
- Diet type: <exact value>
- Allergies: <exact value>
- Meals per day: <exact value>

## Plan
- Time - Meal name: foods + portion hint
- Time - Meal name: foods + portion hint
(repeat to match meals per day exactly)

## Notes
- 2 to 4 short safety or hydration notes.
''';

    try {
      final text = await _aiService.generateText(
        prompt,
        systemPrompt: systemPrompt,
        temperature: 0.1,
        maxTokens: 700,
      );
      if (!mounted) return;
      final plan = AiDietPlan(
        goal: selectedGoal,
        dietType: selectedDiet,
        allergies: selectedAllergy,
        mealsPerDay: selectedMeals,
        planText: text,
        createdAt: DateTime.now(),
      );
      await _dietPlanStorage.save(plan);
      if (!mounted) return;
      setState(() {
        _result = text;
        _savedPlan = plan;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSavedPlan() async {
    final plan = await _dietPlanStorage.load();
    if (!mounted) return;
    setState(() {
      _savedPlan = plan;
      _result = plan?.planText;
      _isInitializing = false;
    });
  }

  Future<void> _deleteSavedPlan() async {
    await _dietPlanStorage.clear();
    if (!mounted) return;
    setState(() {
      _savedPlan = null;
      _result = null;
      _error = null;
      _resetFormSelections();
    });
  }

  void _startNewPlan() {
    setState(() {
      _savedPlan = null;
      _result = null;
      _error = null;
    });
  }

  void _resetFormSelections() {
    _goalController.clear();
    _dietController.clear();
    _allergyController.clear();
    _mealsController.clear();
    _selectedGoal = null;
    _selectedDiet = null;
    _selectedAllergy = null;
    _selectedMeals = null;
  }

  void _handleDropdownSelection({
    required String? value,
    required TextEditingController controller,
    required void Function(String?) assign,
  }) {
    assign(value);
    if (value == null || value == 'Other') {
      controller.clear();
      return;
    }
    controller.text = value;
  }

  String _resolvedGoal() {
    final goal = _goalController.text.trim();
    return goal.isEmpty ? 'Not specified' : goal;
  }

  String _resolvedDiet() {
    final diet = _dietController.text.trim();
    return diet.isEmpty ? 'Not specified' : diet;
  }

  String _resolvedAllergy() {
    final allergy = _allergyController.text.trim();
    return allergy.isEmpty ? 'None' : allergy;
  }

  String _resolvedMeals() {
    final meals = _mealsController.text.trim();
    return meals.isEmpty ? '3' : meals;
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
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MealTrackerPage(),
                ),
              );
            },
            icon: const Icon(Icons.photo_camera_back_outlined),
            tooltip: 'Meal Tracker',
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meal Tracker + Photo Logging',
                          style: TextStyle(
                            color: text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Log what you actually ate, attach a meal photo, and compare it with your AI diet plan.',
                          style: TextStyle(color: sub, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MealTrackerPage(),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ],
              ),
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
                    hint: 'Choose your goal',
                    controller: _goalController,
                    value: _selectedGoal,
                    options: _goalOptions,
                    onChanged: (value) {
                      setState(() {
                        _handleDropdownSelection(
                          value: value,
                          controller: _goalController,
                          assign: (next) => _selectedGoal = next,
                        );
                      });
                    },
                    otherHint: 'Type your goal',
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Diet Type',
                    hint: 'Choose a diet type',
                    controller: _dietController,
                    value: _selectedDiet,
                    options: _dietOptions,
                    onChanged: (value) {
                      setState(() {
                        _handleDropdownSelection(
                          value: value,
                          controller: _dietController,
                          assign: (next) => _selectedDiet = next,
                        );
                      });
                    },
                    otherHint: 'Type your diet type',
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Allergies',
                    hint: 'Choose an allergy',
                    controller: _allergyController,
                    value: _selectedAllergy,
                    options: _allergyOptions,
                    onChanged: (value) {
                      setState(() {
                        _handleDropdownSelection(
                          value: value,
                          controller: _allergyController,
                          assign: (next) => _selectedAllergy = next,
                        );
                      });
                    },
                    otherHint: 'Type your allergy or restriction',
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: 'Meals per day',
                    hint: 'Choose meals per day',
                    controller: _mealsController,
                    value: _selectedMeals,
                    options: _mealOptions,
                    onChanged: (value) {
                      setState(() {
                        _handleDropdownSelection(
                          value: value,
                          controller: _mealsController,
                          assign: (next) => _selectedMeals = next,
                        );
                      });
                    },
                    otherHint: 'Enter number of meals',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _startNewPlan,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create New'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _deleteSavedPlan,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
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
                            'AI result will appear here once Hugging Face is connected.',
                            style: TextStyle(color: sub, fontSize: 14),
                          )
                        : AIResultRenderer(rawText: _result!)),
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
    required this.value,
    required this.options,
    required this.onChanged,
    this.otherHint,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String? otherHint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final text = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final showOtherField = value == 'Other';
    final decoration = InputDecoration(
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: decoration,
          hint: Text(hint, style: TextStyle(color: sub)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        if (showOtherField) ...[
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: decoration.copyWith(
              hintText: otherHint ?? 'Type here',
            ),
          ),
        ],
      ],
    );
  }
}
