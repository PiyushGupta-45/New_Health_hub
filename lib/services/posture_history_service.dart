import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_type.dart';

class PostureSessionRecord {
  const PostureSessionRecord({
    required this.id,
    required this.exerciseType,
    required this.score,
    required this.correctFrames,
    required this.incorrectFrames,
    required this.neutralFrames,
    required this.feedback,
    required this.recordedAt,
  });

  final String id;
  final ExerciseType exerciseType;
  final double score;
  final int correctFrames;
  final int incorrectFrames;
  final int neutralFrames;
  final String feedback;
  final DateTime recordedAt;

  factory PostureSessionRecord.fromJson(Map<String, dynamic> json) {
    return PostureSessionRecord(
      id: json['id']?.toString() ?? '',
      exerciseType: exerciseTypeFromName(json['exerciseType']?.toString()),
      score: json['score'] is num ? (json['score'] as num).toDouble() : 0,
      correctFrames: json['correctFrames'] is num
          ? (json['correctFrames'] as num).toInt()
          : 0,
      incorrectFrames: json['incorrectFrames'] is num
          ? (json['incorrectFrames'] as num).toInt()
          : 0,
      neutralFrames: json['neutralFrames'] is num
          ? (json['neutralFrames'] as num).toInt()
          : 0,
      feedback: json['feedback']?.toString() ?? 'Session recorded',
      recordedAt: DateTime.tryParse(json['recordedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseType': exerciseType.name,
      'score': score,
      'correctFrames': correctFrames,
      'incorrectFrames': incorrectFrames,
      'neutralFrames': neutralFrames,
      'feedback': feedback,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }
}

class PostureSummary {
  const PostureSummary({
    required this.totalSessions,
    required this.averageScore,
    required this.latestFeedback,
    required this.bestExercise,
  });

  final int totalSessions;
  final double averageScore;
  final String latestFeedback;
  final String bestExercise;
}

class PostureHistoryService {
  PostureHistoryService._internal();

  static final PostureHistoryService _instance =
      PostureHistoryService._internal();
  factory PostureHistoryService() => _instance;

  static const String _historyKey = 'posture_history_records_v1';

  Future<void> saveSession(PostureSessionRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSessions(limit: 200);
    final updated = <PostureSessionRecord>[record, ...existing]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    await prefs.setString(
      _historyKey,
      json.encode(updated.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<PostureSessionRecord>> loadSessions({int limit = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return <PostureSessionRecord>[];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return <PostureSessionRecord>[];
      final sessions = decoded
          .where((item) => item is Map)
          .map(
            (item) => PostureSessionRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return sessions.take(limit).toList();
    } catch (_) {
      return <PostureSessionRecord>[];
    }
  }

  Future<PostureSummary> loadSummary() async {
    final sessions = await loadSessions(limit: 50);
    if (sessions.isEmpty) {
      return const PostureSummary(
        totalSessions: 0,
        averageScore: 0,
        latestFeedback: 'No posture sessions yet.',
        bestExercise: 'None yet',
      );
    }

    final avg = sessions.fold<double>(0, (sum, item) => sum + item.score) /
        sessions.length;

    final byExercise = <ExerciseType, List<PostureSessionRecord>>{};
    for (final session in sessions) {
      byExercise.putIfAbsent(session.exerciseType, () => <PostureSessionRecord>[])
          .add(session);
    }

    ExerciseType best = sessions.first.exerciseType;
    double bestAvg = -1;
    for (final entry in byExercise.entries) {
      final exerciseAvg = entry.value.fold<double>(
            0,
            (sum, item) => sum + item.score,
          ) /
          entry.value.length;
      if (exerciseAvg > bestAvg) {
        bestAvg = exerciseAvg;
        best = entry.key;
      }
    }

    return PostureSummary(
      totalSessions: sessions.length,
      averageScore: avg,
      latestFeedback: sessions.first.feedback,
      bestExercise: best.name,
    );
  }
}

ExerciseType exerciseTypeFromName(String? raw) {
  final normalized = raw?.trim().toLowerCase() ?? '';
  for (final type in ExerciseType.values) {
    if (type.name.toLowerCase() == normalized) return type;
  }
  return ExerciseType.generalPosture;
}
