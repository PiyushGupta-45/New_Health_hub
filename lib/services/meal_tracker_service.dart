import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MealLogEntry {
  const MealLogEntry({
    required this.id,
    required this.loggedAt,
    required this.mealType,
    required this.title,
    required this.notes,
    required this.calories,
    required this.photoPath,
    required this.adherenceLabel,
  });

  final String id;
  final DateTime loggedAt;
  final String mealType;
  final String title;
  final String notes;
  final int calories;
  final String? photoPath;
  final String adherenceLabel;

  String get dateKey {
    final date = DateTime(loggedAt.year, loggedAt.month, loggedAt.day);
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  factory MealLogEntry.fromJson(Map<String, dynamic> json) {
    return MealLogEntry(
      id: json['id']?.toString() ?? '',
      loggedAt: DateTime.tryParse(json['loggedAt']?.toString() ?? '') ??
          DateTime.now(),
      mealType: json['mealType']?.toString() ?? 'Meal',
      title: json['title']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      calories: json['calories'] is num ? (json['calories'] as num).toInt() : 0,
      photoPath: json['photoPath']?.toString(),
      adherenceLabel: json['adherenceLabel']?.toString() ?? 'Uncategorized',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loggedAt': loggedAt.toIso8601String(),
      'mealType': mealType,
      'title': title,
      'notes': notes,
      'calories': calories,
      'photoPath': photoPath,
      'adherenceLabel': adherenceLabel,
    };
  }
}

class MealTrackerService {
  MealTrackerService._internal();

  static final MealTrackerService _instance = MealTrackerService._internal();
  factory MealTrackerService() => _instance;

  static const String _storageKey = 'meal_tracker_entries_v1';

  Future<List<MealLogEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <MealLogEntry>[];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return <MealLogEntry>[];
      final entries = decoded
          .whereType<Map>()
          .map((item) => MealLogEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      entries.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      return entries;
    } catch (_) {
      return <MealLogEntry>[];
    }
  }

  Future<List<MealLogEntry>> loadEntriesForDate(String dateKey) async {
    final entries = await loadEntries();
    return entries.where((entry) => entry.dateKey == dateKey).toList();
  }

  Future<void> saveEntry(MealLogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadEntries();
    final updated = [
      entry,
      ...entries.where((item) => item.id != entry.id),
    ]..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    await prefs.setString(
      _storageKey,
      json.encode(updated.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadEntries();
    final updated = entries.where((item) => item.id != id).toList();
    await prefs.setString(
      _storageKey,
      json.encode(updated.map((item) => item.toJson()).toList()),
    );
  }
}
