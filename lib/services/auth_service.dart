import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> initGoogleSignIn() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize();
    _googleInitialized = true;
  }

  // EMAIL/PASSWORD SIGN IN & verification
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user != null && !user.emailVerified) {
        await _firebaseAuth.signOut();
        return 'Please verify your email before logging in.';
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    }
  }

  // EMAIL/PASSWORD REGISTER 
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user != null) {
        await user.updateDisplayName(name);

        await _createUserDocument(
          uid: user.uid,
          name: name,
          email: email,
        );

        await user.sendEmailVerification();
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    }
  }

  // GOOGLE SIGN IN 
  Future<String?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
      } else {
        await initGoogleSignIn();
        if (!_googleSignIn.supportsAuthenticate()) {
          return 'Google Sign-In is not supported on this device.';
        }
        final googleUser = await _googleSignIn.authenticate();
        final googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
        userCredential = await _firebaseAuth.signInWithCredential(credential);
      }

      final user = userCredential.user;
      if (user != null && userCredential.additionalUserInfo?.isNewUser == true) {
        await _createUserDocument(
          uid: user.uid,
          name: user.displayName ?? 'Student',
          email: user.email ?? '',
        );
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return null;
    }
  }

  // FORGOT PASSWORD 
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _firebaseAuth.signOut();
  }

  Future<UserModel?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }

  // AuthService
  Stream<UserModel?> streamUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> updateProfilePhoto(String uid, Map<String, dynamic> profilePhoto) async {
    await _db.collection('users').doc(uid).update({
      'profile_photo': profilePhoto,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Partial update for the My Profile edit fields (birthday, university,
  /// college, course, year_level, bio, name). Caller passes only the keys
  /// that changed — untouched fields are left alone by Firestore's update().
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createUserDocument({
    required String uid,
    required String name,
    required String email,
  }) async {
    await _db.collection('users').doc(uid).set({
      'user_id': uid,
      'name': name,
      'email': email,
      'role': 'student',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'weak-password':
        return 'Password is too weak (use at least 6 characters).';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}