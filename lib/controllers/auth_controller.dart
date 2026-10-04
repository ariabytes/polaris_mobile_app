import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService;
  final StorageService _storage = StorageService();

  late final StreamSubscription<User?> _authSub;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _authSub = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  UserModel? _currentUserProfile;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  UserModel? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

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
    } catch (e) {
      debugPrint('PROFILE LOAD ERROR: $e');
    }
    notifyListeners();
  }

  Future<void> _refreshProfile() async {
    try {
      final u = _authService.currentUser;
      _currentUserProfile =
          u == null ? null : await _authService.getUserData(u.uid);
    } catch (e) {
      debugPrint('PROFILE REFRESH ERROR: $e');
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
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
    final cleaned = email.trim();
    if (!_emailRegex.hasMatch(cleaned)) {
      return _fail('Please enter a valid email address.');
    }
    if (password.isEmpty) {
      return _fail('Please enter your password.');
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
      return _succeed();
    } catch (_) {
      return _fail('Could not send the email. Please try again.');
    }
  }

  Future<bool> signInWithGoogle() async {
    _startLoading();
    try {
      final error = await _authService.signInWithGoogle();
      if (error == AuthService.googleCancelled) {
        return _fail(null); // user backed out: stay silent
      }
      if (error != null) return _fail(error);

      await _refreshProfile();
      return _succeed();
    } catch (_) {
      return _fail('Google Sign-In failed. Please try again.');
    }
  }

  Future<bool> resetPassword(String email) async {
    final cleaned = email.trim();
    if (!_emailRegex.hasMatch(cleaned)) {
      _isLoading = false;
      _errorMessage = 'Please enter a valid email address.';
      _infoMessage = null;
      notifyListeners();
      return false;
    }

    _startLoading();
    try {
      final error = await _authService.sendPasswordResetEmail(cleaned);
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
    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');
    } finally {
      _currentUserProfile = null;
      notifyListeners();
    }
  }


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

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('PROFILE PHOTO UPLOAD FAILED: $e');
      debugPrintStack(stackTrace: stackTrace);

      _isLoading = false;
      _errorMessage = 'Could not upload profile photo. Please try again.';
      notifyListeners();
      return false;
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
      _errorMessage = 'No logged-in user found.';
      notifyListeners();
      return false;
    }

    final cleanedName = name?.trim() ?? '';
    if (cleanedName.isEmpty) {
      _errorMessage = 'Name cannot be empty.';
      notifyListeners();
      return false;
    }

    _startLoading();

    String? clean(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final data = <String, dynamic>{
      'name': cleanedName,
      'birthday': birthday != null ? Timestamp.fromDate(birthday) : null,
      'university': clean(university),
      'college': clean(college),
      'program': clean(program),
      'year_level': clean(yearLevel),
      'bio': clean(bio),
    };

    try {
      await _authService.updateUserProfile(uid, data);
      _currentUserProfile = await _authService.getUserData(uid);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('PROFILE UPDATE ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      _isLoading = false;
      _errorMessage = 'Could not update your profile. Please try again.';
      notifyListeners();
      return false;
    }
  }

  
  Stream<List<UserModel>> allUsers() => _authService.streamAllUsers();

  Future<bool> deleteUser(String uid) async {
    _startLoading();
    try {
      await _authService.deleteUserDocument(uid);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('DELETE USER ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      _isLoading = false;
      _errorMessage = 'Could not delete this user. Please try again.';
      notifyListeners();
      return false;
    }
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
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}