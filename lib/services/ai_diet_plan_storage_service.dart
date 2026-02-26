import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AiDietPlan {
  AiDietPlan({
    required this.goal,
    required this.dietType,
    required this.allergies,
    required this.mealsPerDay,
    required this.planText,
    required this.createdAt,
  });

  final String goal;
  final String dietType;
  final String allergies;
  final String mealsPerDay;
  final String planText;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'goal': goal,
      'dietType': dietType,
      'allergies': allergies,
      'mealsPerDay': mealsPerDay,
      'planText': planText,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AiDietPlan.fromJson(Map<String, dynamic> json) {
    return AiDietPlan(
      goal: json['goal']?.toString() ?? 'Not specified',
      dietType: json['dietType']?.toString() ?? 'Not specified',
      allergies: json['allergies']?.toString() ?? 'None',
      mealsPerDay: json['mealsPerDay']?.toString() ?? '3',
      planText: json['planText']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class AiDietPlanStorageService {
  static const String _key = 'ai_diet_plan_saved';

  Future<void> save(AiDietPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(plan.toJson()));
  }

  Future<AiDietPlan?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return AiDietPlan.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
