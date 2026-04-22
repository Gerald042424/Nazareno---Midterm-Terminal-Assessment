import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/auth_service.dart';
import '../../core/utils/app_result.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService) {
    _authSub = _authService.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  final AuthService _authService;
  StreamSubscription<User?>? _authSub;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user ?? _authService.currentUser;
  bool get isAuthenticated => user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final AppResult<void> result = await _authService.login(
      email: email,
      password: password,
    );

    _isLoading = false;
    _errorMessage = result.error?.message;
    notifyListeners();
    return result.isSuccess;
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final AppResult<void> result = await _authService.register(
      username: username,
      email: email,
      password: password,
    );

    if (result.isSuccess) {
      _user = _authService.currentUser;
    }

    _isLoading = false;
    _errorMessage = result.error?.message;
    notifyListeners();
    return result.isSuccess;
  }

  Future<void> logout() async {
    _errorMessage = null;
    notifyListeners();
    await _authService.logout();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
