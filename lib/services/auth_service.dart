// Authentication service for MongoDB Atlas backend

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  String? get baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      print('⚠️ API_BASE_URL is not set in .env file');
      return null;
    }
    
    // Remove trailing slash if present
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    
    // Validate that it's a proper HTTP/HTTPS URL, not a MongoDB connection string
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      throw Exception(
        'API_BASE_URL must be a valid HTTP/HTTPS URL (e.g., https://your-api.com). '
        'MongoDB connection strings should not be used here. '
        'Set up a backend API server that connects to MongoDB Atlas.'
      );
    }
    
    print('✅ Using API_BASE_URL: $cleanUrl');
    return cleanUrl;
  }
  
  String? get apiKey => dotenv.env['API_KEY'];

  // Get stored user data
  Future<Map<String, dynamic>?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      return json.decode(userJson);
    }
    return null;
  }

  // Store user data
  Future<void> storeUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Handle nested user object (from API response) or flat user object
    final user = userData['user'] ?? userData;
    final token = user['token'] ?? userData['token'] ?? '';
    
    // Store the user object (not the entire response)
    await prefs.setString('user_data', json.encode(user));
    await prefs.setString('auth_token', token);
    
    print('✅ Stored auth token: ${token.isNotEmpty ? "Token saved" : "No token found"}');
  }

  // Clear stored user data
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.remove('auth_token');
  }

  // Get auth token
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Sign up with email and password
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final url = baseUrl;
      if (url == null || url.isEmpty) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured. Please set it in your .env file.'
        };
      }

      final endpoint = '$url/api/auth/signup';
      print('🌐 Making request to: $endpoint');
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey ?? '',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');
      
      // Check if response is JSON before parsing
      if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Backend API not found (404).\n\n'
              'URL tried: $endpoint\n\n'
              'Please verify:\n'
              '1. Your backend is running at: $url\n'
              '2. Test in browser: $url/api/health\n'
              '3. Check your .env file has correct API_BASE_URL'
        };
      }

      if (response.statusCode >= 500) {
        return {
          'success': false,
          'error': 'Backend server error (${response.statusCode}). Please check if your backend is running.'
        };
      }

      // Try to parse JSON, handle non-JSON responses
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        return {
          'success': false,
          'error': 'Invalid response from server: ${response.body}'
        };
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        await storeUser(data);
        // Extract user object from response
        final user = data['user'] ?? data;
        return {'success': true, 'user': user};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Sign up failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Sign in with email and password
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final url = baseUrl;
      if (url == null || url.isEmpty) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured. Please set it in your .env file.'
        };
      }

      final endpoint = '$url/api/auth/signin';
      print('🌐 Making request to: $endpoint');
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey ?? '',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');
      
      // Check if response is JSON before parsing
      if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Backend API not found (404).\n\n'
              'URL tried: $endpoint\n\n'
              'Please verify:\n'
              '1. Your backend is running at: $url\n'
              '2. Test in browser: $url/api/health\n'
              '3. Check your .env file has correct API_BASE_URL'
        };
      }

      if (response.statusCode >= 500) {
        return {
          'success': false,
          'error': 'Backend server error (${response.statusCode}). Please check if your backend is running.'
        };
      }

      // Try to parse JSON, handle non-JSON responses
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        return {
          'success': false,
          'error': 'Invalid response from server: ${response.body}'
        };
      }

      if (response.statusCode == 200) {
        await storeUser(data);
        // Extract user object from response
        final user = data['user'] ?? data;
        return {'success': true, 'user': user};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Sign in failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  // Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Validate baseUrl before making request
      final url = baseUrl;
      if (url == null || url.isEmpty) {
        return {
          'success': false,
          'error': 'API_BASE_URL is not configured. Please set it in your .env file.'
        };
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'success': false, 'error': 'Google sign in cancelled'};
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final endpoint = '$url/api/auth/google';
      print('🌐 Making request to: $endpoint');
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey ?? '',
        },
        body: json.encode({
          'idToken': googleAuth.idToken,
          'accessToken': googleAuth.accessToken,
          'name': googleUser.displayName,
          'email': googleUser.email,
          'photoUrl': googleUser.photoUrl,
        }),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');
      
      // Check if response is JSON before parsing
      if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Backend API not found (404).\n\n'
              'URL tried: $endpoint\n\n'
              'Please verify:\n'
              '1. Your backend is running at: $url\n'
              '2. Test in browser: $url/api/health\n'
              '3. Check your .env file has correct API_BASE_URL'
        };
      }

      if (response.statusCode >= 500) {
        return {
          'success': false,
          'error': 'Backend server error (${response.statusCode}). Please check if your backend is running.'
        };
      }

      // Try to parse JSON, handle non-JSON responses
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        return {
          'success': false,
          'error': 'Invalid response from server: ${response.body}'
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        await storeUser(data);
        // Extract user object from response
        final user = data['user'] ?? data;
        return {'success': true, 'user': user};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Google sign in failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Google sign in error: ${e.toString()}'};
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await clearUser();
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final user = await getStoredUser();
    final token = await getAuthToken();
    return user != null && token != null && token.isNotEmpty;
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required String name,
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
          'error': 'Not authenticated'
        };
      }

      final endpoint = '$url/api/user/profile';
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-api-key': apiKey ?? '',
        },
        body: json.encode({
          'name': name,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await storeUser(data);
        return {'success': true, 'user': data['user']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to update profile'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Error updating profile: ${e.toString()}'};
    }
  }

  // Change password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
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
          'error': 'Not authenticated'
        };
      }

      final endpoint = '$url/api/user/change-password';
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-api-key': apiKey ?? '',
        },
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to change password'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Error changing password: ${e.toString()}'};
    }
  }

  // Deactivate account
  Future<Map<String, dynamic>> deactivateAccount() async {
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
          'error': 'Not authenticated'
        };
      }

      final endpoint = '$url/api/user/deactivate';
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-api-key': apiKey ?? '',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to deactivate account'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Error deactivating account: ${e.toString()}'};
    }
  }

  // Delete account
  Future<Map<String, dynamic>> deleteAccount() async {
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
          'error': 'Not authenticated'
        };
      }

      final endpoint = '$url/api/user/delete';
      final response = await http.delete(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-api-key': apiKey ?? '',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await clearUser();
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to delete account'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Error deleting account: ${e.toString()}'};
    }
  }
}

