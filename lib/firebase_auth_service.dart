import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'auth.dart';
import 'backend.dart';

/// Firebase-backed implementation of [BackendAuthService] and [AuthenticationService].
///
/// Uses genuine Firebase Authentication for email/password account creation,
/// sign-in, session restoration, and sign-out. Employs Firebase Auth UID as the
/// stable user identity (never using email as the identifier).
class FirebaseAuthService implements BackendAuthService {
  FirebaseAuthService({this.auth});

  final fb.FirebaseAuth? auth;

  fb.FirebaseAuth get _authInstance => auth ?? fb.FirebaseAuth.instance;

  @override
  Stream<RoadSenseUser?> get authStateChanges {
    try {
      return _authInstance.authStateChanges().map(_mapFirebaseUserNullable);
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  RoadSenseUser? get currentUser {
    try {
      return _mapFirebaseUserNullable(_authInstance.currentUser);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RoadSenseUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authInstance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('The email or password is incorrect.');
      }
      return mapFirebaseUser(user);
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(mapFirebaseAuthErrorCode(error.code));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('The email or password is incorrect.');
    }
  }

  @override
  Future<RoadSenseUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authInstance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Account creation failed. Please try again.');
      }

      final trimmedName = name.trim();
      if (trimmedName.isNotEmpty) {
        try {
          await user.updateDisplayName(trimmedName);
        } catch (_) {
          // Display name sync failure is non-fatal for account creation.
        }
      }

      return mapFirebaseUser(user, fallbackName: trimmedName);
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(mapFirebaseAuthErrorCode(error.code));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('Unable to create account. Please try again.');
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _authInstance.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(mapFirebaseAuthErrorCode(error.code));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Unable to send password reset email. Please try again.',
      );
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = _authInstance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(mapFirebaseAuthErrorCode(error.code));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Unable to send verification email. Please try again.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _authInstance.signOut();
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(mapFirebaseAuthErrorCode(error.code));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('Sign out failed. Please try again.');
    }
  }

  static RoadSenseUser? _mapFirebaseUserNullable(fb.User? user) =>
      user == null ? null : mapFirebaseUser(user);

  /// Maps a Firebase [fb.User] to the domain [RoadSenseUser].
  ///
  /// Strictly maps [fb.User.uid] to [RoadSenseUser.id], ensuring email addresses
  /// are never used as user IDs. Uses [UserRole.user] as the safe client-side default,
  /// preventing fabrication of administrative or researcher privileges.
  static RoadSenseUser mapFirebaseUser(fb.User user, {String? fallbackName}) {
    final displayName = user.displayName?.trim();
    final name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (fallbackName?.trim().isNotEmpty == true
              ? fallbackName!.trim()
              : (user.email?.split('@').firstOrNull ?? 'RoadSense driver'));

    return RoadSenseUser(
      id: user.uid,
      name: name,
      email: user.email ?? '',
      role: UserRole.user,
      isEmailVerified: user.emailVerified,
    );
  }

  /// Maps Firebase Authentication error codes to user-friendly messages
  /// without leaking internal implementation details or private data.
  static String mapFirebaseAuthErrorCode(String code) => switch (code) {
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'The email or password is incorrect.',
    'email-already-in-use' => 'An account with this email already exists.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'The password is too weak. Use at least 8 characters.',
    'operation-not-allowed' =>
      'Email and password sign-in is not enabled. Please contact support.',
    'user-disabled' =>
      'This account has been disabled. Please contact support.',
    'too-many-requests' =>
      'Too many unsuccessful attempts. Please try again later.',
    'network-request-failed' =>
      'Network connection issue. Please check your internet connection.',
    _ => 'Authentication failed. Please check your details and try again.',
  };
}
