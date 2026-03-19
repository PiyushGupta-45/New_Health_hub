import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HabitEntry {
  const HabitEntry({
    required this.dateKey,
    required this.waterLiters,
    required this.sleepHours,
    required this.meditated,
    required this.tookSupplements,
    required this.mood,
    required this.notes,
  });

  final String dateKey;
  final double waterLiters;
  final double sleepHours;
  final bool meditated;
  final bool tookSupplements;
  final int mood;
  final String notes;

  HabitEntry copyWith({
    double? waterLiters,
    double? sleepHours,
    bool? meditated,
    bool? tookSupplements,
    int? mood,
    String? notes,
  }) {
    return HabitEntry(
      dateKey: dateKey,
      waterLiters: waterLiters ?? this.waterLiters,
      sleepHours: sleepHours ?? this.sleepHours,
      meditated: meditated ?? this.meditated,
      tookSupplements: tookSupplements ?? this.tookSupplements,
      mood: mood ?? this.mood,
      notes: notes ?? this.notes,
    );
  }

  factory HabitEntry.empty(String dateKey) {
    return HabitEntry(
      dateKey: dateKey,
      waterLiters: 0,
      sleepHours: 0,
      meditated: false,
      tookSupplements: false,
      mood: 0,
      notes: '',
    );
  }

  factory HabitEntry.fromJson(Map<String, dynamic> json) {
    return HabitEntry(
      dateKey: json['dateKey']?.toString() ?? '',
      waterLiters: json['waterLiters'] is num
          ? (json['waterLiters'] as num).toDouble()
          : 0,
      sleepHours: json['sleepHours'] is num
          ? (json['sleepHours'] as num).toDouble()
          : 0,
      meditated: json['meditated'] == true,
      tookSupplements: json['tookSupplements'] == true,
      mood: json['mood'] is num ? (json['mood'] as num).toInt() : 0,
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'waterLiters': waterLiters,
      'sleepHours': sleepHours,
      'meditated': meditated,
      'tookSupplements': tookSupplements,
      'mood': mood,
      'notes': notes,
    };
  }

  bool get isMeaningful =>
      waterLiters > 0 ||
      sleepHours > 0 ||
      meditated ||
      tookSupplements ||
      mood > 0 ||
      notes.trim().isNotEmpty;

  bool get completedCoreHabits =>
      waterLiters >= 2.0 && sleepHours >= 7.0 && meditated;
}

class HabitTrackerService {
  HabitTrackerService._internal();

  static final HabitTrackerService _instance = HabitTrackerService._internal();
  factory HabitTrackerService() => _instance;

  static const String _habitKey = 'habit_tracker_entries_v1';

  Future<HabitEntry> loadEntry(String dateKey) async {
    final entries = await loadEntries();
    return entries[dateKey] ?? HabitEntry.empty(dateKey);
  }

  Future<Map<String, HabitEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_habitKey);
    if (raw == null || raw.isEmpty) return <String, HabitEntry>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return <String, HabitEntry>{};
      return {
        for (final entry in decoded.entries)
          entry.key: HabitEntry.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      };
    } catch (_) {
      return <String, HabitEntry>{};
    }
  }

  Future<void> saveEntry(HabitEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadEntries();
    entries[entry.dateKey] = entry;
    await prefs.setString(
      _habitKey,
      json.encode({
        for (final item in entries.entries) item.key: item.value.toJson(),
      }),
    );
  }
}
