import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '/models/user_model.dart';
import '/services/auth_service.dart';
import '../services/storage_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService;
  final StorageService _storage = StorageService();

  late final StreamSubscription<User?> _authSub;

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _authSub = _authService.authStateChanges.listen(
      _onAuthStateChanged,
    );
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

  Stream<UserModel?> get currentUserProfileStream {
    final uid = _authService.currentUser?.uid;

    if (uid == null) {
      return Stream.value(null);
    }

    return _authService.streamUserData(uid);
  }

  Future<void> _onAuthStateChanged(
    User? firebaseUser,
  ) async {
    if (firebaseUser == null) {
      _currentUserProfile = null;
    } else {
      _currentUserProfile =
          await _authService.getUserData(firebaseUser.uid);
    }

    notifyListeners();
  }

  // ============================================================
  // LOGIN
  // ============================================================

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

  // ============================================================
  // REGISTER
  // ============================================================

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

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================

  Future<bool> signInWithGoogle() async {
    _startLoading();

    final error = await _authService.signInWithGoogle();

    return _finishAttempt(error);
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

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

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    await _authService.signOut();

    _currentUserProfile = null;

    notifyListeners();
  }

  // ============================================================
  // PROFILE PHOTO
  // ============================================================

  Future<bool> uploadProfilePhoto(
    String uid,
    File file,
    String originalFilename,
  ) async {
    _startLoading();

    try {
      debugPrint('==========================================');
      debugPrint('PROFILE PHOTO UPLOAD STARTED');
      debugPrint('UID: $uid');
      debugPrint('File: ${file.path}');
      debugPrint('Filename: $originalFilename');
      debugPrint('File exists: ${await file.exists()}');
      debugPrint('==========================================');

      final result = await _storage.uploadFile(
        file: file,
        originalFilename: originalFilename,
        folder: 'users/profile_photos',
        resourceType: CloudinaryResourceType.Image,
        useRestrictedPreset: false,
      );

      debugPrint('==========================================');
      debugPrint('CLOUDINARY UPLOAD SUCCESS');
      debugPrint('Result: $result');
      debugPrint('URL: ${result['url']}');
      debugPrint('Public ID: ${result['public_id']}');
      debugPrint('==========================================');

      await _authService.updateProfilePhoto(
        uid,
        result,
      );

      debugPrint('==========================================');
      debugPrint('FIRESTORE PROFILE PHOTO UPDATE SUCCESS');
      debugPrint('==========================================');

      // Refresh the cached profile.
      _currentUserProfile =
          await _authService.getUserData(uid);

      _isLoading = false;
      _errorMessage = null;

      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      debugPrint('==========================================');
      debugPrint('PROFILE PHOTO UPLOAD FAILED');
      debugPrint('ERROR TYPE: ${e.runtimeType}');
      debugPrint('ERROR: $e');
      debugPrint('STACK TRACE:');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('==========================================');

      _isLoading = false;

      // Keep the actual error visible while debugging.
      _errorMessage =
          'Could not upload profile photo.\n$e';

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // UPDATE PROFILE
  // ============================================================

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

    _startLoading();

    final cleanedName = name?.trim() ?? '';

    final cleanedUniversity =
        university?.trim().isEmpty == true
            ? null
            : university?.trim();

    final cleanedCollege =
        college?.trim().isEmpty == true
            ? null
            : college?.trim();

    final cleanedProgram =
        program?.trim().isEmpty == true
            ? null
            : program?.trim();

    final cleanedYearLevel =
        yearLevel?.trim().isEmpty == true
            ? null
            : yearLevel?.trim();

    final cleanedBio =
        bio?.trim().isEmpty == true
            ? null
            : bio?.trim();

    final data = <String, dynamic>{
      'name': cleanedName,

      'birthday': birthday != null
          ? Timestamp.fromDate(birthday)
          : null,

      'university': cleanedUniversity,
      'college': cleanedCollege,
      'program': cleanedProgram,
      'year_level': cleanedYearLevel,
      'bio': cleanedBio,
    };

    try {
      await _authService.updateUserProfile(
        uid,
        data,
      );

      // Refresh local profile.
      _currentUserProfile =
          await _authService.getUserData(uid);

      _isLoading = false;
      _errorMessage = null;

      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      debugPrint('PROFILE UPDATE ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      _isLoading = false;

      _errorMessage =
          'Could not update your profile. Please try again.';

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // ADMIN
  // ============================================================

  /// Every user profile on the platform — for the admin dashboard's user
  /// list. Gate access to whatever screen calls this with `isAdmin`;
  /// Firestore's `allow list: if isAdmin()` on /users is the real
  /// enforcement, this is just a UI-level convenience.
  Stream<List<UserModel>> allUsers() => _authService.streamAllUsers();

  /// Deletes a user's Firestore profile document ONLY.
  ///
  /// A client app cannot delete another user's Firebase Auth account — the
  /// SDK only allows a user to delete themselves
  /// (`FirebaseAuth.instance.currentUser.delete()`). Deleting an arbitrary
  /// other account requires the Admin SDK, i.e. a Cloud Function this
  /// project doesn't have. So after this succeeds, the deleted person's
  /// login credentials still work; they'll just find no profile document.
  ///
  /// Worth revisiting later: have `_onAuthStateChanged` treat a signed-in
  /// Firebase user whose `getUserData` comes back null as "deleted" and
  /// force `signOut()`, so a deleted account can't linger in a broken
  /// logged-in state.
  ///
  /// Reuses `isLoading`/`errorMessage` like every other write here — a
  /// given admin screen only triggers one of these at a time.
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

  // ============================================================
  // MESSAGES / LOADING
  // ============================================================

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