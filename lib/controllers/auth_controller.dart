// Authentication controller for managing auth state

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  static const String _firstLaunchHandledKey = 'auth_first_launch_handled';
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isGuest = false;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isGuest => _isGuest;

  String? get userName =>
      _currentUser?['name'] ?? _currentUser?['user']?['name'];
  String? get userEmail =>
      _currentUser?['email'] ?? _currentUser?['user']?['email'];
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

    final prefs = await SharedPreferences.getInstance();
    final firstLaunchHandled = prefs.getBool(_firstLaunchHandledKey) ?? false;

    if (!firstLaunchHandled) {
      // First launch after install/reinstall: force auth entry.
      await _authService.clearUser();
      await prefs.remove('step_baseline_count');
      await prefs.remove('step_baseline_date');
      await prefs.setBool(_firstLaunchHandledKey, true);
      _currentUser = null;
      _isAuthenticated = false;
      _isGuest = false;
    } else {
      // Normal launches: validate token with backend before trusting local state.
      final validation = await _authService.validateSession();
      if (validation['success'] == true) {
        _currentUser =
            (validation['user'] as Map<String, dynamic>?) ??
            await _authService.getStoredUser();
        _isAuthenticated = true;
        _isGuest = false;
      } else {
        _currentUser = null;
        _isAuthenticated = false;
        _isGuest = false;
      }
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
      _isGuest = false;
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

    final result = await _authService.signIn(email: email, password: password);

    if (result['success'] == true) {
      _currentUser = result['user'];
      _isAuthenticated = true;
      _isGuest = false;
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
      _isGuest = false;
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
    _isGuest = false;

    _isLoading = false;
    notifyListeners();
  }

  // Refresh user data from storage
  Future<void> refreshUser() async {
    if (_isGuest) {
      _currentUser = null;
      _isAuthenticated = false;
      notifyListeners();
      return;
    }
    final validation = await _authService.validateSession();
    if (validation['success'] == true) {
      _currentUser =
          (validation['user'] as Map<String, dynamic>?) ??
          await _authService.getStoredUser();
      _isAuthenticated = true;
      _isGuest = false;
    } else {
      _currentUser = null;
      _isAuthenticated = false;
      _isGuest = false;
    }
    notifyListeners();
  }

  Future<void> signInAsGuest() async {
    _isLoading = true;
    notifyListeners();

    await _authService.clearUser();
    _currentUser = null;
    _isAuthenticated = false;
    _isGuest = true;

    _isLoading = false;
    notifyListeners();
  }
}
