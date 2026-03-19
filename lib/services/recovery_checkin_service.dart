import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecoveryCheckIn {
  const RecoveryCheckIn({
    required this.dateKey,
    required this.energy,
    required this.soreness,
    required this.sleepQuality,
    required this.stress,
    required this.recommendation,
  });

  final String dateKey;
  final int energy;
  final int soreness;
  final int sleepQuality;
  final int stress;
  final String recommendation;

  factory RecoveryCheckIn.empty(String dateKey) {
    return RecoveryCheckIn(
      dateKey: dateKey,
      energy: 3,
      soreness: 3,
      sleepQuality: 3,
      stress: 3,
      recommendation: 'Add your check-in to get a readiness recommendation.',
    );
  }

  factory RecoveryCheckIn.fromJson(Map<String, dynamic> json) {
    return RecoveryCheckIn(
      dateKey: json['dateKey']?.toString() ?? '',
      energy: json['energy'] is num ? (json['energy'] as num).toInt() : 3,
      soreness: json['soreness'] is num ? (json['soreness'] as num).toInt() : 3,
      sleepQuality: json['sleepQuality'] is num
          ? (json['sleepQuality'] as num).toInt()
          : 3,
      stress: json['stress'] is num ? (json['stress'] as num).toInt() : 3,
      recommendation: json['recommendation']?.toString() ??
          'Add your check-in to get a readiness recommendation.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'energy': energy,
      'soreness': soreness,
      'sleepQuality': sleepQuality,
      'stress': stress,
      'recommendation': recommendation,
    };
  }
}

class RecoveryInsight {
  const RecoveryInsight({
    required this.score,
    required this.title,
    required this.recommendation,
  });

  final int score;
  final String title;
  final String recommendation;
}

class RecoveryCheckInService {
  RecoveryCheckInService._internal();

  static final RecoveryCheckInService _instance =
      RecoveryCheckInService._internal();
  factory RecoveryCheckInService() => _instance;

  static const String _storageKey = 'recovery_checkins_v1';

  RecoveryInsight buildInsight({
    required int energy,
    required int soreness,
    required int sleepQuality,
    required int stress,
  }) {
    final score =
        ((energy * 25) + ((6 - soreness) * 20) + (sleepQuality * 25) + ((6 - stress) * 15))
            .clamp(0, 500) ~/
        5;

    if (score >= 80) {
      return const RecoveryInsight(
        score: 80,
        title: 'High readiness',
        recommendation:
            'You look ready for a hard session. Keep warm-up quality high and use your main workout as planned.',
      );
    }
    if (score >= 60) {
      return const RecoveryInsight(
        score: 65,
        title: 'Moderate readiness',
        recommendation:
            'Train, but stay controlled. A moderate session or technique-focused workout is the best fit today.',
      );
    }
    return const RecoveryInsight(
      score: 45,
      title: 'Recovery-focused day',
      recommendation:
          'Dial intensity down. Prioritize walking, mobility, posture work, hydration, and sleep recovery today.',
    );
  }

  Future<RecoveryCheckIn> loadEntry(String dateKey) async {
    final entries = await loadEntries();
    return entries[dateKey] ?? RecoveryCheckIn.empty(dateKey);
  }

  Future<Map<String, RecoveryCheckIn>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <String, RecoveryCheckIn>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return <String, RecoveryCheckIn>{};
      return {
        for (final entry in decoded.entries)
          entry.key: RecoveryCheckIn.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      };
    } catch (_) {
      return <String, RecoveryCheckIn>{};
    }
  }

  Future<void> saveEntry(RecoveryCheckIn entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadEntries();
    entries[entry.dateKey] = entry;
    await prefs.setString(
      _storageKey,
      json.encode({
        for (final item in entries.entries) item.key: item.value.toJson(),
      }),
    );
  }
}
