// Authentication controller for managing auth state

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  String? get userName => _currentUser?['name'] ?? _currentUser?['user']?['name'];
  String? get userEmail => _currentUser?['email'] ?? _currentUser?['user']?['email'];
  String get userInitial {
    final name = userName;
    if (name != null && name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return 'U';
  }

  AuthController() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    final isAuth = await _authService.isAuthenticated();
    if (isAuth) {
      _currentUser = await _authService.getStoredUser();
      _isAuthenticated = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.signUp(
      name: name,
      email: email,
      password: password,
    );

    if (result['success'] == true) {
      _currentUser = result['user'];
      _isAuthenticated = true;
    }

    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.signIn(
      email: email,
      password: password,
    );

    if (result['success'] == true) {
      _currentUser = result['user'];
      _isAuthenticated = true;
    }

    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.signInWithGoogle();

    if (result['success'] == true) {
      _currentUser = result['user'];
      _isAuthenticated = true;
    }

    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _authService.signOut();
    _currentUser = null;
    _isAuthenticated = false;

    _isLoading = false;
    notifyListeners();
  }
}

