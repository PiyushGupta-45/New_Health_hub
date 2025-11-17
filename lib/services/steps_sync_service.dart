// Service to sync daily steps to backend

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StepsSyncService {
  static final StepsSyncService _instance = StepsSyncService._internal();
  factory StepsSyncService() => _instance;
  StepsSyncService._internal();

  String? get baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      return null;
    }
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    return cleanUrl;
  }

  // Get auth token from storage
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Store daily steps to backend
  Future<Map<String, dynamic>> storeSteps({
    required int steps,
    DateTime? date,
    String? source,
  }) async {
    try {
      final url = baseUrl;
      if (url == null || url.isEmpty) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured'
        };
      }

      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'error': 'User not authenticated. Please sign in.'
        };
      }

      final response = await http.post(
        Uri.parse('$url/api/steps'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-auth-token': token,
        },
        body: json.encode({
          'steps': steps,
          if (date != null) 'date': date.toIso8601String(),
          if (source != null) 'source': source,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data']};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Authentication failed. Please sign in again.'
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to store steps'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}'
      };
    }
  }

  // Get steps history from backend
  Future<Map<String, dynamic>> getStepsHistory({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
  }) async {
    try {
      final url = baseUrl;
      if (url == null || url.isEmpty) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured'
        };
      }

      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'error': 'User not authenticated. Please sign in.'
        };
      }

      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('$url/api/steps/history').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? [],
          'count': data['count'] ?? 0,
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Authentication failed. Please sign in again.'
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to fetch steps history'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}'
      };
    }
  }

  // Get today's steps from backend
  Future<Map<String, dynamic>> getTodaySteps() async {
    try {
      final url = baseUrl;
      if (url == null || url.isEmpty) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured'
        };
      }

      final token = await getAuthToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'error': 'User not authenticated. Please sign in.'
        };
      }

      final response = await http.get(
        Uri.parse('$url/api/steps/today'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data']};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Authentication failed. Please sign in again.'
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to fetch today\'s steps'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}'
      };
    }
  }
}

