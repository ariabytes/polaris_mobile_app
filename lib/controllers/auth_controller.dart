import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '/models/user_model.dart';
import '/services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService;

  late final StreamSubscription<User?> _authSub;

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _authSub =
        _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  UserModel? _currentUserProfile;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  UserModel? get currentUserProfile => _currentUserProfile;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  String? get infoMessage => _infoMessage;

  bool get isLoggedIn => _authService.currentUser != null;

  bool get isAdmin => _currentUserProfile?.isAdmin ?? false;

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUserProfile = null;
    } else {
      _currentUserProfile =
          await _authService.getUserData(firebaseUser.uid);
    }

    notifyListeners();
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _startLoading();

    final error = await _authService.signIn(
      email: email,
      password: password,
    );

    final success = _finishAttempt(error);

    if (success) {
      final firebaseUser = _authService.currentUser;

      if (firebaseUser != null) {
        _currentUserProfile =
            await _authService.getUserData(firebaseUser.uid);

        notifyListeners();
      }
    }

    return success;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _startLoading();

    final error = await _authService.register(
      name: name,
      email: email,
      password: password,
    );

    final success = _finishAttempt(error);

    if (success) {
      await _authService.signOut();
      _currentUserProfile = null;
    }

    return success;
  }

  Future<bool> signInWithGoogle() async {
    _startLoading();

    final error = await _authService.signInWithGoogle();

    return _finishAttempt(error);
  }

  Future<bool> resetPassword(String email) async {
    _startLoading();

    final error =
        await _authService.sendPasswordResetEmail(email);

    _isLoading = false;

    if (error != null) {
      _errorMessage = error;
      _infoMessage = null;
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    _infoMessage =
        'Password reset link sent. Check your inbox (or spam).';

    notifyListeners();

    return true;
  }

  Future<void> logout() async {
    await _authService.signOut();

    _currentUserProfile = null;

    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _infoMessage = null;

    notifyListeners();
  }

  void _startLoading() {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;

    notifyListeners();
  }

  bool _finishAttempt(String? error) {
    _isLoading = false;

    if (error != null) {
      _errorMessage = error;

      notifyListeners();

      return false;
    }

    notifyListeners();

    return true;
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}