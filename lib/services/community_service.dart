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
    String clean = url.trim();
    if (clean.endsWith(
      '/',
    ))
      clean = clean.substring(
        0,
        clean.length -
            1,
      );
    return clean;
  }

  // ------------------------------
  // Get Auth Headers
  // ------------------------------
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

  // ------------------------------
  // Create Community
  // ------------------------------
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
      }

      final error = json.decode(
        response.body,
      );
      return {
        'success': false,
        'error':
            error['message'] ??
            'Failed to create',
      };
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ------------------------------
  // Get Public Communities
  // ------------------------------
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
          'error': 'API_BASE_URL missing',
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
      }

      final error = json.decode(
        response.body,
      );
      return {
        'success': false,
        'error':
            error['message'] ??
            'Failed to load public communities',
      };
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ------------------------------
  // Join Public Community
  // ------------------------------
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
          null)
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };

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
      }

      final error = json.decode(
        response.body,
      );
      return {
        'success': false,
        'error':
            error['message'] ??
            'Failed to join',
      };
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ------------------------------
  // Join Private Community
  // ------------------------------
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
          null)
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(
          '$url/api/community/join-with-code',
        ),
        headers: headers,
        body: json.encode(
          {
            'joinCode': joinCode.trim().toUpperCase(),
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
      }

      final error = json.decode(
        response.body,
      );
      return {
        'success': false,
        'error':
            error['message'] ??
            'Invalid join code',
      };
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ------------------------------
  // Get My Communities
  // ------------------------------
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
          null)
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '$url/api/community/my-communities',
        ),
        headers: headers,
      );

      if (response.statusCode ==
          200)
        return json.decode(
          response.body,
        );

      final error = json.decode(
        response.body,
      );
      return {
        'success': false,
        'error': error['message'],
      };
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ------------------------------
  // Send Message
  // ------------------------------
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
          null)
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };

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
      }

      return {
        'success': false,
        'error': 'Failed to send message',
      };
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ------------------------------
  // Get Messages
  // ------------------------------
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
          null)
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };

      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse(
          '$url/api/community/messages?communityId=$communityId&limit=$limit',
        ),
        headers: headers,
      );

      if (response.statusCode ==
          200)
        return json.decode(
          response.body,
        );

      final error = json.decode(
        response.body,
      );
      return {
        'success': false,
        'error': error['message'],
      };
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ------------------------------
  // NEW: Leave Community
  // ------------------------------
  Future<
    Map<
      String,
      dynamic
    >
  >
  leaveCommunity(
    String communityId,
  ) async {
    try {
      final url = baseUrl;
      if (url ==
          null)
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };

      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse(
          '$url/api/community/leave',
        ),
        headers: headers,
        body: json.encode(
          {
            'communityId': communityId,
          },
        ),
      );

      return json.decode(
        response.body,
      );
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ------------------------------
  // NEW: Delete Community (Owner Only)
  // ------------------------------
  Future<
    Map<
      String,
      dynamic
    >
  >
  deleteCommunity(
    String communityId,
  ) async {
    try {
      final url = baseUrl;
      if (url ==
          null)
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };

      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse(
          '$url/api/community/delete/$communityId',
        ),
        headers: headers,
      );

      return json.decode(
        response.body,
      );
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ------------------------------
  // NEW: Transfer Ownership
  // ------------------------------
  Future<
    Map<
      String,
      dynamic
    >
  >
  transferOwnership(
    String communityId,
    String newOwnerId,
  ) async {
    try {
      final url = baseUrl;
      if (url ==
          null)
        return {
          'success': false,
          'error': 'API_BASE_URL missing',
        };

      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse(
          '$url/api/community/transfer-owner',
        ),
        headers: headers,
        body: json.encode(
          {
            'communityId': communityId,
            'newOwnerId': newOwnerId,
          },
        ),
      );

      return json.decode(
        response.body,
      );
    } catch (
      e
    ) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}
