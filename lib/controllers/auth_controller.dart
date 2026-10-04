import 'dart:async';
import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// Handles login state, registration, and the current user's profile.
/// All validation lives here so the views only display results.
class AuthController extends ChangeNotifier {
  static const int resendCooldownSeconds = 60;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Shared email check, also used by the forgot-password dialog.
  static bool isValidEmail(String email) => _emailRegex.hasMatch(email.trim());

  final AuthService _authService;
  final StorageService _storage = StorageService();

  late final StreamSubscription<User?> _authSub;
  Timer? _cooldownTimer;

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _authSub = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  UserModel? _currentUserProfile;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;
  int _resendCooldown = 0;

  UserModel? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  /// Seconds left before another verification email can be requested.
  int get resendCooldown => _resendCooldown;

  bool get isLoggedIn {
    final u = _authService.currentUser;
    return u != null && u.emailVerified;
  }

  bool get isAdmin => _currentUserProfile?.isAdmin ?? false;

  Stream<UserModel?> get currentUserProfileStream {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      return Stream.value(null);
    }
    return _authService.streamUserData(uid);
  }

  // ---------- AUTH STATE ----------

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null || !firebaseUser.emailVerified) {
      _currentUserProfile = null;
      notifyListeners();
      return;
    }

    try {
      final profile = await _authService.getUserData(firebaseUser.uid);
      if (_authService.currentUser?.uid != firebaseUser.uid) return;
      _currentUserProfile = profile;
    } catch (_) {
      // Without a profile the app would show a loading spinner forever,
      // so sign the user out and let them log in again.
      await logout();
      return;
    }
    notifyListeners();
  }

  Future<void> _refreshProfile() async {
    try {
      final u = _authService.currentUser;
      _currentUserProfile =
          u == null ? null : await _authService.getUserData(u.uid);
    } catch (_) {
      // Keep the previous profile; _onAuthStateChanged handles hard failures.
    }
  }

  // ---------- LOGIN / REGISTER ----------

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    if (_isLoading) return false;

    if (email.trim().isEmpty || password.isEmpty) {
      return _fail('Please enter your email and password.');
    }

    _startLoading();
    try {
      final error = await _authService.signIn(
        email: email,
        password: password,
      );
      if (error != null) return _fail(error);
      await _refreshProfile();
      return _succeed();
    } catch (_) {
      return _fail('Something went wrong. Please try again.');
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_isLoading) return false;

    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      return _fail('Please fill in all fields.');
    }
    if (!isValidEmail(email)) {
      return _fail('Please enter a valid email address.');
    }
    if (password.length < 6) {
      return _fail('Password must be at least 6 characters.');
    }

    _startLoading();
    try {
      final error = await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      if (error != null) return _fail(error);

      await _authService.signOut();
      _currentUserProfile = null;
      return _succeed();
    } catch (_) {
      return _fail('Something went wrong. Please try again.');
    }
  }

  Future<bool> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    if (_isLoading || _resendCooldown > 0) return false;

    final cleaned = email.trim();
    if (cleaned.isEmpty || password.isEmpty) {
      return _fail(
        'Enter your email and password above, then tap "Resend verification email".',
      );
    }
    if (!isValidEmail(cleaned)) {
      return _fail('Please enter a valid email address.');
    }

    _startLoading();
    try {
      final error = await _authService.resendVerificationEmail(
        email: cleaned,
        password: password,
      );
      if (error != null) return _fail(error);

      _currentUserProfile = null;
      _infoMessage =
          'Verification email sent. Check your inbox and your spam folder.';
      _startResendCooldown();
      return _succeed();
    } catch (_) {
      return _fail('Could not send the email. Please try again.');
    }
  }

  Future<bool> signInWithGoogle() async {
    if (_isLoading) return false;

    _startLoading();
    try {
      final error = await _authService.signInWithGoogle();
      if (error == AuthService.googleCancelled) {
        return _fail(null); // user backed out: stay silent
      }
      if (error != null) return _fail(error);

      // Brand-new Google users get their profile document during sign-in.
      await _refreshProfile();
      return _succeed();
    } catch (_) {
      return _fail('Google Sign-In failed. Please try again.');
    }
  }

  Future<bool> resetPassword(String email) async {
    if (_isLoading) return false;

    if (!isValidEmail(email)) {
      return _fail('Please enter a valid email address.');
    }

    _startLoading();
    try {
      final error = await _authService.sendPasswordResetEmail(email.trim());
      if (error != null) return _fail(error);

      _infoMessage = 'Password reset link sent. Check your inbox (or spam).';
      return _succeed();
    } catch (_) {
      return _fail('Something went wrong. Please try again.');
    }
  }

  Future<void> logout() async {
    try {
      await _authService.signOut();
    } catch (_) {
      // Signing out locally below still clears the UI state.
    } finally {
      _currentUserProfile = null;
      notifyListeners();
    }
  }

  // ---------- PROFILE ----------

  Future<bool> uploadProfilePhoto(
    String uid,
    File file,
    String originalFilename,
  ) async {
    _startLoading();
    try {
      final result = await _storage.uploadFile(
        file: file,
        originalFilename: originalFilename,
        folder: 'users/profile_photos',
        resourceType: CloudinaryResourceType.Image,
        useRestrictedPreset: false,
      );

      await _authService.updateProfilePhoto(uid, result);
      _currentUserProfile = await _authService.getUserData(uid);
      return _succeed();
    } catch (_) {
      return _fail('Could not upload profile photo. Please try again.');
    }
  }

  Future<bool> updateProfile({
    String? name,
    DateTime? birthday,
    String? university,
    String? college,
    String? program,
    String? yearLevel,
    String? bio,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      return _fail('No logged-in user found.');
    }

    final cleanedName = name?.trim() ?? '';
    if (cleanedName.isEmpty) {
      return _fail('Name cannot be empty.');
    }

    _startLoading();
    try {
      await _authService.updateUserProfile(
        uid,
        name: cleanedName,
        birthday: birthday,
        university: university,
        college: college,
        program: program,
        yearLevel: yearLevel,
        bio: bio,
      );
      _currentUserProfile = await _authService.getUserData(uid);
      return _succeed();
    } catch (_) {
      return _fail('Could not update your profile. Please try again.');
    }
  }

  /// Live profile of any user (used to show a material's creator).
  Stream<UserModel?> userStream(String uid) => _authService.streamUserData(uid);

  // ---------- ADMIN ----------

  Stream<List<UserModel>> allUsers() => _authService.streamAllUsers();

  /// Admin only. Admins cannot delete their own account or other admins.
  Future<bool> deleteUser(String uid) async {
    if (uid == _authService.currentUser?.uid) {
      return _fail('You cannot delete your own account.');
    }

    _startLoading();
    try {
      final target = await _authService.getUserData(uid);
      if (target?.isAdmin ?? false) {
        return _fail('Admin accounts cannot be deleted.');
      }
      await _authService.deleteUserDocument(uid);
      return _succeed();
    } catch (_) {
      return _fail('Could not delete this user. Please try again.');
    }
  }

  // ---------- PRIVATE HELPERS ----------

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    _resendCooldown = resendCooldownSeconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _resendCooldown--;
      if (_resendCooldown <= 0) {
        _resendCooldown = 0;
        timer.cancel();
      }
      notifyListeners();
    });
  }

  void _startLoading() {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  bool _fail(String? message) {
    _isLoading = false;
    _errorMessage = message;
    notifyListeners();
    return false;
  }

  bool _succeed() {
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _authSub.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}