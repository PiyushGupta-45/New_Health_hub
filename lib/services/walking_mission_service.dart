import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WalkingMission {
  const WalkingMission({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.targetKm,
    required this.createdAt,
    required this.theme,
    this.completedAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final double targetKm;
  final DateTime createdAt;
  final String theme;
  final DateTime? completedAt;

  WalkingMission copyWith({
    DateTime? completedAt,
  }) {
    return WalkingMission(
      id: id,
      title: title,
      subtitle: subtitle,
      targetKm: targetKm,
      createdAt: createdAt,
      theme: theme,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory WalkingMission.fromJson(Map<String, dynamic> json) {
    return WalkingMission(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Walk Mission',
      subtitle: json['subtitle']?.toString() ?? '',
      targetKm: json['targetKm'] is num
          ? (json['targetKm'] as num).toDouble()
          : 1.5,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      theme: json['theme']?.toString() ?? 'daily',
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'targetKm': targetKm,
      'createdAt': createdAt.toIso8601String(),
      'theme': theme,
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}

class WalkingMissionService {
  WalkingMissionService._internal();

  static final WalkingMissionService _instance =
      WalkingMissionService._internal();
  factory WalkingMissionService() => _instance;

  static const String _historyKey = 'walking_mission_history_v1';

  List<WalkingMission> buildSuggestedMissions() {
    final now = DateTime.now();
    final hour = now.hour;

    final first = hour < 10
        ? WalkingMission(
            id: 'sunrise_${now.millisecondsSinceEpoch}',
            title: 'Sunrise Reset',
            subtitle: 'Start the day with a calm outdoor walk.',
            targetKm: 2.0,
            createdAt: now,
            theme: 'sunrise',
          )
        : WalkingMission(
            id: 'lunch_${now.millisecondsSinceEpoch}',
            title: 'Lunch Break Loop',
            subtitle: 'Take a brisk walk to reset your focus.',
            targetKm: 1.5,
            createdAt: now,
            theme: 'lunch',
          );

    return [
      first,
      WalkingMission(
        id: 'recovery_${now.millisecondsSinceEpoch}',
        title: 'Recovery Walk',
        subtitle: 'Low-pressure movement for recovery and posture.',
        targetKm: 2.5,
        createdAt: now,
        theme: 'recovery',
      ),
      WalkingMission(
        id: 'endurance_${now.millisecondsSinceEpoch}',
        title: 'Endurance Builder',
        subtitle: 'A longer route goal to build consistency.',
        targetKm: 4.0,
        createdAt: now,
        theme: 'endurance',
      ),
    ];
  }

  Future<List<WalkingMission>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return <WalkingMission>[];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return <WalkingMission>[];
      final items = decoded
          .whereType<Map>()
          .map((item) => WalkingMission.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return <WalkingMission>[];
    }
  }

  Future<void> saveCompletedMission(WalkingMission mission) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    final updated = [
      mission,
      ...history.where((item) => item.id != mission.id),
    ];
    await prefs.setString(
      _historyKey,
      json.encode(updated.map((item) => item.toJson()).toList()),
    );
  }
}
