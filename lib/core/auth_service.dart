import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Why a login attempt failed.
enum AuthError {
  invalidCredentials,
  tooManyRequests,
  network,
  disabled,
  emailInUse,
  weakPassword,
  invalidEmail,
  cancelled,
  unknown,
}

/// Login through Firebase Authentication (email + password).
///
/// People sign in with their email and password, and can create their own
/// account from the app (name, birth date, email, password). A plain word
/// without "@" is still accepted and becomes "word@argus.app" (old accounts).
/// The person's name is saved in the account's display name.
class AuthService {
  AuthService._();

  /// Domain added to usernames that are not already an email address.
  static const String emailDomain = 'argus.app';

  /// Only Gmail addresses can sign in or sign up.
  static bool isAllowedEmail(String email) =>
      RegExp(r'^[^@\s]+@gmail\.com$').hasMatch(email.trim().toLowerCase());

  static String emailFor(String username) => username.trim().toLowerCase();

  static User? get _user => FirebaseAuth.instance.currentUser;

  static bool get isSignedIn => _user != null;

  /// Unique id of the signed-in account ('' if none).
  static String get uid => _user?.uid ?? '';

  /// The account email.
  static String get email => _user?.email ?? '';

  /// Short name from the email ("admin" for admin@argus.app, "sara" for
  /// sara@gmail.com). Used only when the person has no saved name.
  static String get username {
    final email = _user?.email ?? '';
    final suffix = '@$emailDomain';
    if (email.endsWith(suffix)) {
      return email.substring(0, email.length - suffix.length);
    }
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  /// The person's saved name ('' if they never set one).
  static String get displayName => (_user?.displayName ?? '').trim();

  /// Name shown in the app: the saved name, or the username if there is none.
  static String get accountName =>
      displayName.isNotEmpty ? displayName : username;

  /// Saves the person's name in their Firebase account (needs internet).
  static Future<void> updateDisplayName(String name) async {
    final user = _user;
    if (user == null) return;
    final trimmed = name.trim();
    await user.updateDisplayName(trimmed.isEmpty ? null : trimmed);
    await user.reload();
  }

  /// Signs in. Returns null on success, or the reason it failed.
  static Future<AuthError?> signIn(String username, String password) async {
    if (!isAllowedEmail(username)) return AuthError.invalidEmail;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailFor(username),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _map(e.code);
    } catch (_) {
      return AuthError.unknown;
    }
  }

  /// Creates a new account and signs in. Returns null on success.
  static Future<AuthError?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!isAllowedEmail(email)) return AuthError.invalidEmail;
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = cred.user;
      if (user != null) {
        await user.updateDisplayName(name.trim());
        await user.reload();
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _map(e.code);
    } catch (_) {
      return AuthError.unknown;
    }
  }

  /// Signs in (or signs up) with a Google account. Returns null on success.
  static Future<AuthError?> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider()..addScope('email');
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
      // Google Workspace / other domains are not allowed.
      if (!isAllowedEmail(email)) {
        await signOut();
        return AuthError.invalidEmail;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request' ||
          e.code == 'web-context-canceled' ||
          e.code == 'canceled') {
        return AuthError.cancelled;
      }
      return _map(e.code);
    } catch (_) {
      return AuthError.unknown;
    }
  }

  /// Changes the password of the signed-in account (needs the current one).
  /// Returns null on success.
  static Future<AuthError?> changePassword(
    String current,
    String newPassword,
  ) async {
    final user = _user;
    final email = user?.email;
    if (user == null || email == null) return AuthError.unknown;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: current),
      );
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _map(e.code);
    } catch (_) {
      return AuthError.unknown;
    }
  }

  /// Sends a "reset your password" email. Returns null when it was sent.
  static Future<AuthError?> sendPasswordReset(String email) async {
    if (!isAllowedEmail(email)) return AuthError.invalidEmail;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailFor(email),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      // "user-not-found" is reported as success so nobody can use this
      // screen to find out which emails have accounts.
      if (e.code == 'user-not-found') return null;
      return _map(e.code);
    } catch (_) {
      return AuthError.unknown;
    }
  }

  static AuthError _map(String code) => switch (code) {
    'invalid-credential' ||
    'user-not-found' ||
    'wrong-password' => AuthError.invalidCredentials,
    'invalid-email' => AuthError.invalidEmail,
    'email-already-in-use' => AuthError.emailInUse,
    'weak-password' => AuthError.weakPassword,
    'too-many-requests' => AuthError.tooManyRequests,
    'network-request-failed' => AuthError.network,
    'user-disabled' => AuthError.disabled,
    _ => AuthError.unknown,
  };

  static Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Nothing to do: the app returns to the login page anyway.
    }
  }
}
