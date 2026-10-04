import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';

class AuthService {
  static const String googleCancelled = 'google_cancelled';

  static const String unverifiedMessage =
      'Please verify your email before logging in. '
      'Check your spam folder, or tap "Resend verification email" below.';

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

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) return 'Login failed. Please try again.';

      if (!user.emailVerified) {
        await _firebaseAuth.signOut();
        return unverifiedMessage;
      }

      await _ensureUserDocument(user);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name.trim());

        await _createUserDocument(
          uid: user.uid,
          name: name.trim(),
          email: email.trim(),
        );

        try {
          await user.sendEmailVerification();
        } catch (_) {
        }
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return 'Could not create your account. Please try again.';
    }
  }

  Future<String?> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    var signedInHere = false;
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      signedInHere = true;

      final user = credential.user;
      if (user == null) {
        return 'Could not send the email. Please try again.';
      }

      if (user.emailVerified) {
        return 'This email is already verified. You can log in now.';
      }

      await user.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return 'Could not send the email. Please try again.';
    } finally {
      if (signedInHere) {
        try {
          await _firebaseAuth.signOut();
        } catch (_) {}
      }
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        userCredential =
            await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
      } else {
        await initGoogleSignIn();
        if (!_googleSignIn.supportsAuthenticate()) {
          return 'Google Sign-In is not supported on this device.';
        }
        final googleUser = await _googleSignIn.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null) {
          return 'Google Sign-In failed. Please try again.';
        }
        userCredential = await _firebaseAuth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }

      final user = userCredential.user;
      if (user != null) {
        await _ensureUserDocument(user);
      }
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return googleCancelled;
      }
      return 'Google Sign-In failed. Please try again.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return googleCancelled;
      }
      return _mapAuthError(e);
    } catch (_) {
      return 'Google Sign-In failed. Please try again.';
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await initGoogleSignIn(); 
        await _googleSignIn.signOut();
      }
    } catch (_) {
    }
    await _firebaseAuth.signOut();
  }

  Future<UserModel?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }

  Stream<UserModel?> streamUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<UserModel>> streamAllUsers() {
    return _db
        .collection('users')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> deleteUserDocument(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  Future<void> updateProfilePhoto(
    String uid,
    Map<String, dynamic> profilePhoto,
  ) async {
    await _db.collection('users').doc(uid).update({
      'profile_photo': profilePhoto,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    await _db.collection('users').doc(uid).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ensureUserDocument(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;

    final displayName = user.displayName?.trim() ?? '';
    await _createUserDocument(
      uid: user.uid,
      name: displayName.isNotEmpty ? displayName : 'Student',
      email: user.email ?? '',
    );
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
      case 'missing-email':
        return 'Please enter your email.';
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
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}