// Challenge service for creating and participating in challenges

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ChallengeService {
  static final ChallengeService _instance = ChallengeService._internal();
  factory ChallengeService() => _instance;
  ChallengeService._internal();

  final AuthService _authService = AuthService();

  String? get baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      return null;
    }
    String clean = url.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'x-api-key': dotenv.env['API_KEY'] ?? '',
    };
  }

  // Create challenge
  Future<Map<String, dynamic>> createChallenge({
    required String title,
    String? description,
    required int targetSteps,
    required DateTime startDate,
    required DateTime endDate,
    bool isPublic = true,
  }) async {
    try {
      final url = baseUrl;
      if (url == null) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured',
        };
      }

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$url/api/challenges/create'),
        headers: headers,
        body: json.encode({
          'title': title,
          'description': description,
          'targetSteps': targetSteps,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'isPublic': isPublic,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }

      final error = json.decode(response.body);
      return {
        'success': false,
        'error': error['message'] ?? 'Failed to create challenge',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get public challenges
  Future<Map<String, dynamic>> getPublicChallenges() async {
    try {
      final url = baseUrl;
      if (url == null) {
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };
      }

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$url/api/challenges/list'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      final error = json.decode(response.body);
      return {
        'success': false,
        'error': error['message'] ?? 'Failed to load challenges',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get my challenges
  Future<Map<String, dynamic>> getMyChallenges() async {
    try {
      final url = baseUrl;
      if (url == null) {
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };
      }

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$url/api/challenges/my-challenges'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      final error = json.decode(response.body);
      return {
        'success': false,
        'error': error['message'] ?? 'Failed to load challenges',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Join challenge
  Future<Map<String, dynamic>> joinChallenge(String challengeId) async {
    try {
      final url = baseUrl;
      if (url == null) {
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };
      }

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$url/api/challenges/$challengeId/join'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }

      final error = json.decode(response.body);
      return {
        'success': false,
        'error': error['message'] ?? 'Failed to join challenge',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get challenge details
  Future<Map<String, dynamic>> getChallengeDetails(String challengeId) async {
    try {
      final url = baseUrl;
      if (url == null) {
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };
      }

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$url/api/challenges/$challengeId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      final error = json.decode(response.body);
      return {
        'success': false,
        'error': error['message'] ?? 'Failed to load challenge',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Update steps in challenge
  Future<Map<String, dynamic>> updateChallengeSteps(
    String challengeId,
    int steps,
  ) async {
    try {
      final url = baseUrl;
      if (url == null) {
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };
      }

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$url/api/challenges/$challengeId/update-steps'),
        headers: headers,
        body: json.encode({
          'steps': steps,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      final error = json.decode(response.body);
      return {
        'success': false,
        'error': error['message'] ?? 'Failed to update steps',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}

