import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeeklyWorkoutPlan {
  WeeklyWorkoutPlan({
    required this.id,
    required this.goal,
    required this.duration,
    required this.equipment,
    required this.intensity,
    required this.injury,
    required this.notes,
    required this.planText,
    this.approvedAt,
    this.createdAt,
  });

  final String id;
  final String goal;
  final String duration;
  final String equipment;
  final String intensity;
  final String injury;
  final String notes;
  final String planText;
  final DateTime? approvedAt;
  final DateTime? createdAt;

  factory WeeklyWorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WeeklyWorkoutPlan(
      id: json['_id']?.toString() ?? '',
      goal: json['goal']?.toString() ?? 'Not specified',
      duration: json['duration']?.toString() ?? '30 minutes',
      equipment: json['equipment']?.toString() ?? 'None',
      intensity: json['intensity']?.toString() ?? 'Moderate',
      injury: json['injury']?.toString() ?? 'No injury',
      notes: json['notes']?.toString() ?? '',
      planText: json['planText']?.toString() ?? '',
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

class WeeklyWorkoutPlanService {
  static final WeeklyWorkoutPlanService _instance =
      WeeklyWorkoutPlanService._internal();
  factory WeeklyWorkoutPlanService() => _instance;
  WeeklyWorkoutPlanService._internal();
  static const String _latestPlanLocalKey = 'latest_weekly_workout_plan_local';
  static const String _pendingPlanLocalKey = 'pending_weekly_workout_plan_local';

  String? get _baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.trim().isEmpty) return null;
    return url.trim().replaceAll(RegExp(r'/$'), '');
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>> saveApprovedPlan({
    required String goal,
    required String duration,
    required String equipment,
    required String intensity,
    required String injury,
    required String notes,
    required String planText,
  }) async {
    try {
      final url = _baseUrl;
      if (url == null) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured',
        };
      }

      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'error': 'User not authenticated. Please sign in.',
        };
      }

      final endpoint = '$url/api/workout-plans';
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-auth-token': token,
        },
        body: json.encode({
          'goal': goal,
          'duration': duration,
          'equipment': equipment,
          'intensity': intensity,
          'injury': injury,
          'notes': notes,
          'planText': planText,
        }),
      );

      final data = _tryParseJson(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data is! Map<String, dynamic>) {
          return {
            'success': false,
            'error': 'Invalid server response while saving workout plan.',
          };
        }
        final plan = WeeklyWorkoutPlan.fromJson(
          data['data'] as Map<String, dynamic>,
        );
        await _saveLocalPlan(plan);
        await _clearPendingLocalPlan();
        return {
          'success': true,
          'data': plan,
          'localOnly': false,
        };
      }

      final errorMessage = _extractError(
        data: data,
        statusCode: response.statusCode,
        rawBody: response.body,
        endpoint: endpoint,
        fallback: 'Failed to save workout plan',
      );

      final localPlan = WeeklyWorkoutPlan(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        goal: goal,
        duration: duration,
        equipment: equipment,
        intensity: intensity,
        injury: injury,
        notes: notes,
        planText: planText,
        approvedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _saveLocalPlan(localPlan);
      await _savePendingLocalPlan(localPlan);

      return {
        'success': true,
        'data': localPlan,
        'localOnly': true,
        'warning': errorMessage,
      };
    } catch (e) {
      final localPlan = WeeklyWorkoutPlan(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        goal: goal,
        duration: duration,
        equipment: equipment,
        intensity: intensity,
        injury: injury,
        notes: notes,
        planText: planText,
        approvedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _saveLocalPlan(localPlan);
      await _savePendingLocalPlan(localPlan);
      return {
        'success': true,
        'data': localPlan,
        'localOnly': true,
        'warning': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<WeeklyWorkoutPlan> saveLocalPlanOnly({
    required String goal,
    required String duration,
    required String equipment,
    required String intensity,
    required String injury,
    required String notes,
    required String planText,
  }) async {
    final localPlan = WeeklyWorkoutPlan(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      goal: goal,
      duration: duration,
      equipment: equipment,
      intensity: intensity,
      injury: injury,
      notes: notes,
      planText: planText,
      approvedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    await _saveLocalPlan(localPlan);
    return localPlan;
  }

  Future<Map<String, dynamic>> getLatestApprovedPlan() async {
    final localPlan = await _loadLocalPlan();
    final pendingPlan = await _loadPendingLocalPlan();
    final freshestLocalPlan = _pickNewerPlan(localPlan, pendingPlan);
    try {
      final url = _baseUrl;
      if (url == null) {
        if (freshestLocalPlan != null) {
          return {
            'success': true,
            'data': freshestLocalPlan,
            'localOnly': true,
          };
        }
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured',
        };
      }

      final token = await _getAuthToken();
      if (token == null || token.isEmpty) {
        if (freshestLocalPlan != null) {
          return {
            'success': true,
            'data': freshestLocalPlan,
            'localOnly': true,
          };
        }
        return {
          'success': false,
          'error': 'User not authenticated. Please sign in.',
        };
      }

      // If there is a locally approved plan pending sync, try uploading it first.
      await _syncPendingPlanToBackend(url: url, token: token);

      final endpoint = '$url/api/workout-plans/latest';
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-auth-token': token,
        },
      );

      final data = _tryParseJson(response.body);
      if (response.statusCode == 200) {
        if (data is! Map<String, dynamic>) {
          return {
            'success': false,
            'error': 'Invalid server response while loading workout plan.',
          };
        }
        final raw = data['data'];
        final backendPlan =
            raw is Map<String, dynamic> ? WeeklyWorkoutPlan.fromJson(raw) : null;
        final chosenPlan = _pickNewestPlan([
          backendPlan,
          freshestLocalPlan,
        ]);
        return {
          'success': true,
          'data': chosenPlan,
          'localOnly': chosenPlan != null && chosenPlan != backendPlan,
        };
      }

      if (freshestLocalPlan != null) {
        return {
          'success': true,
          'data': freshestLocalPlan,
          'localOnly': true,
        };
      }

      return {
        'success': false,
        'error': _extractError(
          data: data,
          statusCode: response.statusCode,
          rawBody: response.body,
          endpoint: endpoint,
          fallback: 'Failed to fetch latest workout plan',
        ),
      };
    } catch (e) {
      if (freshestLocalPlan != null) {
        return {
          'success': true,
          'data': freshestLocalPlan,
          'localOnly': true,
        };
      }
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<void> _saveLocalPlan(WeeklyWorkoutPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _latestPlanLocalKey,
      json.encode({
        '_id': plan.id,
        'goal': plan.goal,
        'duration': plan.duration,
        'equipment': plan.equipment,
        'intensity': plan.intensity,
        'injury': plan.injury,
        'notes': plan.notes,
        'planText': plan.planText,
        'approvedAt': plan.approvedAt?.toIso8601String(),
        'createdAt': plan.createdAt?.toIso8601String(),
      }),
    );
  }

  Future<void> _savePendingLocalPlan(WeeklyWorkoutPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingPlanLocalKey,
      json.encode({
        '_id': plan.id,
        'goal': plan.goal,
        'duration': plan.duration,
        'equipment': plan.equipment,
        'intensity': plan.intensity,
        'injury': plan.injury,
        'notes': plan.notes,
        'planText': plan.planText,
        'approvedAt': plan.approvedAt?.toIso8601String(),
        'createdAt': plan.createdAt?.toIso8601String(),
      }),
    );
  }

  Future<WeeklyWorkoutPlan?> _loadPendingLocalPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingPlanLocalKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return WeeklyWorkoutPlan.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPendingLocalPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingPlanLocalKey);
  }

  Future<void> _syncPendingPlanToBackend({
    required String url,
    required String token,
  }) async {
    final pending = await _loadPendingLocalPlan();
    if (pending == null) return;

    final endpoint = '$url/api/workout-plans';
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-auth-token': token,
        },
        body: json.encode({
          'goal': pending.goal,
          'duration': pending.duration,
          'equipment': pending.equipment,
          'intensity': pending.intensity,
          'injury': pending.injury,
          'notes': pending.notes,
          'planText': pending.planText,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _clearPendingLocalPlan();
      }
    } catch (_) {
      // Keep pending plan for future retries.
    }
  }

  Future<WeeklyWorkoutPlan?> _loadLocalPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_latestPlanLocalKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return WeeklyWorkoutPlan.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<WeeklyWorkoutPlan?> loadLocalPlan() async {
    return _loadLocalPlan();
  }

  Future<void> clearLocalPlans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latestPlanLocalKey);
    await prefs.remove(_pendingPlanLocalKey);
  }

  dynamic _tryParseJson(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  String _extractError({
    required dynamic data,
    required int statusCode,
    required String rawBody,
    required String endpoint,
    required String fallback,
  }) {
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }

    final trimmed = rawBody.trim();
    if (trimmed.toLowerCase().startsWith('<!doctype html') ||
        trimmed.toLowerCase().startsWith('<html')) {
      return 'Backend returned HTML (status $statusCode). Check API_BASE_URL and ensure endpoint exists: $endpoint';
    }
    if (trimmed.isNotEmpty) {
      return 'Request failed ($statusCode): $trimmed';
    }

    return '$fallback (status $statusCode)';
  }

  WeeklyWorkoutPlan? _pickNewerPlan(
    WeeklyWorkoutPlan? first,
    WeeklyWorkoutPlan? second,
  ) {
    return _pickNewestPlan([first, second]);
  }

  WeeklyWorkoutPlan? _pickNewestPlan(List<WeeklyWorkoutPlan?> candidates) {
    WeeklyWorkoutPlan? newest;
    DateTime? newestAt;

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final candidateAt = candidate.approvedAt ?? candidate.createdAt;
      if (newest == null) {
        newest = candidate;
        newestAt = candidateAt;
        continue;
      }
      if (candidateAt != null &&
          (newestAt == null || candidateAt.isAfter(newestAt))) {
        newest = candidate;
        newestAt = candidateAt;
      }
    }

    return newest;
  }
}
