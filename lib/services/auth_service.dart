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
      return null;
    }
    // Validate that it's a proper HTTP/HTTPS URL, not a MongoDB connection string
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      throw Exception(
        'API_BASE_URL must be a valid HTTP/HTTPS URL (e.g., https://your-api.com). '
        'MongoDB connection strings should not be used here. '
        'Set up a backend API server that connects to MongoDB Atlas.'
      );
    }
    return url;
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
    await prefs.setString('user_data', json.encode(userData));
    await prefs.setString('auth_token', userData['token'] ?? '');
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

      final response = await http.post(
        Uri.parse('$url/api/auth/signup'),
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

      final data = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        await storeUser(data);
        return {'success': true, 'user': data};
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

      final response = await http.post(
        Uri.parse('$url/api/auth/signin'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey ?? '',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await storeUser(data);
        return {'success': true, 'user': data};
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

      final response = await http.post(
        Uri.parse('$url/api/auth/google'),
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

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await storeUser(data);
        return {'success': true, 'user': data};
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
}

