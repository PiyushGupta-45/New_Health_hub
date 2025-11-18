// Community service for chat and community functionality

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  final AuthService _authService = AuthService();

  String? get baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url ==
            null ||
        url.isEmpty) {
      return null;
    }
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith(
      '/',
    )) {
      cleanUrl = cleanUrl.substring(
        0,
        cleanUrl.length -
            1,
      );
    }
    return cleanUrl;
  }

  // Get auth headers
  Future<
    Map<
      String,
      String
    >
  >
  _getHeaders() async {
    final token = await _authService.getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'x-api-key':
          dotenv.env['API_KEY'] ??
          '',
    };
  }

  // Create a community
  Future<
    Map<
      String,
      dynamic
    >
  >
  createCommunity({
    required String name,
    required bool isPublic,
  }) async {
    try {
      final url = baseUrl;
      if (url ==
          null) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured',
        };
      }

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(
          '$url/api/community/create',
        ),
        headers: headers,
        body: json.encode(
          {
            'name': name,
            'isPublic': isPublic,
          },
        ),
      );

      if (response.statusCode ==
              200 ||
          response.statusCode ==
              201) {
        return json.decode(
          response.body,
        );
      } else {
        final error = json.decode(
          response.body,
        );
        return {
          'success': false,
          'error':
              error['message'] ??
              'Failed to create community',
        };
      }
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get all public communities
  Future<
    Map<
      String,
      dynamic
    >
  >
  getPublicCommunities() async {
    try {
      final url = baseUrl;
      if (url ==
          null) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured',
        };
      }

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '$url/api/community/list',
        ),
        headers: headers,
      );

      if (response.statusCode ==
          200) {
        return json.decode(
          response.body,
        );
      } else {
        final error = json.decode(
          response.body,
        );
        return {
          'success': false,
          'error':
              error['message'] ??
              'Failed to fetch communities',
        };
      }
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Join a public community
  Future<
    Map<
      String,
      dynamic
    >
  >
  joinCommunity(
    String communityId,
  ) async {
    try {
      final url = baseUrl;
      if (url ==
          null) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured',
        };
      }

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(
          '$url/api/community/$communityId/join',
        ),
        headers: headers,
      );

      if (response.statusCode ==
              200 ||
          response.statusCode ==
              201) {
        return json.decode(
          response.body,
        );
      } else {
        final error = json.decode(
          response.body,
        );
        return {
          'success': false,
          'error':
              error['message'] ??
              'Failed to join community',
        };
      }
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Join a private community with code
  Future<
    Map<
      String,
      dynamic
    >
  >
  joinWithCode(
    String joinCode,
  ) async {
    try {
      final url = baseUrl;
      if (url ==
          null) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured',
        };
      }

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(
          '$url/api/community/join-with-code',
        ),
        headers: headers,
        body: json.encode(
          {
            'joinCode': joinCode.toUpperCase(),
          },
        ),
      );

      if (response.statusCode ==
              200 ||
          response.statusCode ==
              201) {
        return json.decode(
          response.body,
        );
      } else {
        final error = json.decode(
          response.body,
        );
        return {
          'success': false,
          'error':
              error['message'] ??
              'Failed to join community',
        };
      }
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get user's communities
  Future<
    Map<
      String,
      dynamic
    >
  >
  getMyCommunities() async {
    try {
      final url = baseUrl;
      if (url ==
          null) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured',
        };
      }

      final headers = await _getHeaders();
      final fullUrl = '$url/api/community/my-communities';

      print(
        '🔍 Full URL: $fullUrl',
      );
      print(
        '🔍 Headers: $headers',
      );

      final response = await http.get(
        Uri.parse(
          fullUrl,
        ),
        headers: headers,
      );

      print(
        '🔍 getMyCommunities Status: ${response.statusCode}',
      );
      print(
        '🔍 getMyCommunities Headers: ${response.request?.headers}',
      );
      print(
        '🔍 getMyCommunities Body: ${response.body}',
      );

      if (response.statusCode ==
          200) {
        return json.decode(
          response.body,
        );
      } else {
        Map<
          String,
          dynamic
        >
        errorData;
        try {
          errorData = json.decode(
            response.body,
          );
        } catch (
          e
        ) {
          errorData = {
            'message': response.body,
          };
        }
        return {
          'success': false,
          'error':
              errorData['message'] ??
              'Failed to fetch communities',
          'status': response.statusCode,
        };
      }
    } catch (
      e
    ) {
      print(
        '🔍 getMyCommunities Exception: $e',
      );
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Send a chat message
  Future<
    Map<
      String,
      dynamic
    >
  >
  sendMessage(
    String message,
    String communityId,
  ) async {
    try {
      final url = baseUrl;
      if (url ==
          null) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured',
        };
      }

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(
          '$url/api/community/messages',
        ),
        headers: headers,
        body: json.encode(
          {
            'message': message,
            'communityId': communityId,
          },
        ),
      );

      if (response.statusCode ==
              200 ||
          response.statusCode ==
              201) {
        return json.decode(
          response.body,
        );
      } else {
        final error = json.decode(
          response.body,
        );
        return {
          'success': false,
          'error':
              error['message'] ??
              'Failed to send message',
        };
      }
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get chat messages
  Future<
    Map<
      String,
      dynamic
    >
  >
  getMessages(
    String communityId, {
    int limit = 50,
  }) async {
    try {
      final url = baseUrl;
      if (url ==
          null) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured',
        };
      }

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '$url/api/community/messages?communityId=$communityId&limit=$limit',
        ),
        headers: headers,
      );

      if (response.statusCode ==
          200) {
        return json.decode(
          response.body,
        );
      } else {
        final error = json.decode(
          response.body,
        );
        return {
          'success': false,
          'error':
              error['message'] ??
              'Failed to fetch messages',
        };
      }
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }
}
