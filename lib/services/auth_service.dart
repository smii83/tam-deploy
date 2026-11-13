import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'firestore_data_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Auth Service — Firebase Design
///
/// Firebase Auth  → handles authentication tokens (email, Apple, Google)
/// Firestore      → stores all user profile data, subscriptions, progress
///
/// After every successful login/register we call FirestoreDataService.upsertUser()
/// to keep both systems in sync.
/// ─────────────────────────────────────────────────────────────────────────────
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStream => _auth.authStateChanges();
  bool get isPasswordUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  // ── Register ──────────────────────────────────────────────────────────────
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required int grade,
    String? section,
    String country = 'kw',
    String lang = 'ar',
  }) async {
    final isAr = lang != 'en';
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.updateDisplayName(name.trim());

      // Sync to Firestore
      await FirestoreDataService.upsertUser(
        firebaseUid: cred.user!.uid,
        name: name.trim(),
        email: email.trim(),
        grade: grade,
        section: section ?? 'scientific',
        country: country,
        lang: lang,
      );

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code, isAr: isAr);
    } catch (e) {
      return isAr ? 'حدث خطأ أثناء التسجيل' : 'An error occurred during sign up';
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<String?> login({
    required String email,
    required String password,
    String lang = 'ar',
  }) async {
    final isAr = lang != 'en';
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Ensure user exists in Firestore (in case they registered elsewhere)
      final user = cred.user!;
      await FirestoreDataService.upsertUser(
        firebaseUid: user.uid,
        name: user.displayName ?? email.split('@').first,
        email: email.trim(),
        lang: lang,
      );

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code, isAr: isAr);
    } catch (e) {
      return isAr ? 'حدث خطأ أثناء تسجيل الدخول' : 'An error occurred during sign in';
    }
  }

  // ── Apple Sign In ─────────────────────────────────────────────────────
  Future<String?> signInWithApple({
    int grade = 12,
    String section = 'scientific',
    String country = 'kw',
    String lang = 'ar',
  }) async {
    final isAr = lang != 'en';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return isAr
          ? 'تسجيل الدخول بـ Apple متاح على أجهزة Apple فقط (iPhone / iPad). يرجى المتابعة عبر Google أو البريد الإلكتروني.'
          : 'Sign in with Apple is only available on Apple devices (iPhone / iPad). Please continue with Google or email.';
    }
    try {
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oAuth = OAuthProvider('apple.com').credential(
        idToken: cred.identityToken,
        accessToken: cred.authorizationCode,
      );
      final userCred = await _auth.signInWithCredential(oAuth);
      final user = userCred.user!;
      final isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;
      final fullName =
          [cred.givenName ?? '', cred.familyName ?? ''].join(' ').trim();

      // Only upsert on first signup — preserve existing grade/section for returning users
      if (isNewUser) {
        await FirestoreDataService.upsertUser(
          firebaseUid: user.uid,
          name: fullName.isNotEmpty
              ? fullName
              : (user.displayName ?? (isAr ? 'مستخدم' : 'User')),
          email: cred.email ?? user.email ?? '',
          grade: grade,
          section: section,
          country: country,
          lang: lang,
        );
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        return isAr
            ? 'تسجيل الدخول بـ Apple غير مفعّل في Firebase Console (Sign-in providers).'
            : 'Apple Sign-In is not enabled in Firebase Console.';
      }
      return _authError(e.code, isAr: isAr);
    } catch (e) {
      final msg = e.toString();
      // User cancelled Apple Sign-In — don't show error
      if (msg.contains('AuthorizationErrorCode.canceled') ||
          msg.contains('canceled') ||
          msg.contains('cancel')) {
        return null;
      }
      return isAr
          ? 'حدث خطأ أثناء تسجيل الدخول بـ Apple. يرجى المحاولة مجدداً.'
          : 'An error occurred during Apple Sign-In. Please try again.';
    }
  }

  // ── Google Sign In ─────────────────────────────────────────────────────
  Future<String?> signInWithGoogle({
    int grade = 12,
    String section = 'scientific',
    String country = 'kw',
    String lang = 'ar',
  }) async {
    final isAr = lang != 'en';
    try {
      final g = await _googleSignIn().signIn();
      if (g == null) return null; // Cancelled by user — not an error
      final gAuth = await g.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user!;
      final isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;

      // Only upsert on first signup — preserve existing grade/section for returning users
      if (isNewUser) {
        await FirestoreDataService.upsertUser(
          firebaseUid: user.uid,
          name: g.displayName ?? (isAr ? 'مستخدم' : 'User'),
          email: g.email,
          grade: grade,
          section: section,
          country: country,
          lang: lang,
        );
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        return isAr
            ? 'تسجيل الدخول بـ Google غير مفعّل في Firebase Console (Sign-in providers).'
            : 'Google Sign-In is not enabled in Firebase Console.';
      }
      return _authError(e.code, isAr: isAr);
    } catch (e) {
      final msg = e.toString();
      // User cancelled Google Sign-In — don't show error
      if (msg.contains('canceled') || msg.contains('cancel') || msg.contains('sign_in_canceled')) {
        return null;
      }
      if (msg.contains('ApiException: 10') || msg.contains('10:')) {
        return isAr
            ? 'خطأ مطوّر في Google Sign-In (ApiException 10): يلزم إضافة بصمة SHA-1 في Firebase Console وإعادة تحميل google-services.json.'
            : 'Google Sign-In configuration error (ApiException 10): check Firebase SHA-1 fingerprint.';
      }
      return isAr
          ? 'حدث خطأ أثناء تسجيل الدخول بـ Google. يرجى المحاولة مجدداً.'
          : 'An error occurred during Google Sign-In. Please try again.';
    }
  }

  GoogleSignIn _googleSignIn() => GoogleSignIn(
        clientId: kIsWeb || defaultTargetPlatform == TargetPlatform.iOS
            ? '82581349835-39166noa7oa449lakj80plqsgegau8rm.apps.googleusercontent.com'
            : null,
        serverClientId:
            '82581349835-hlk2cucplkba8e9j0aen58pqga6nk6m9.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

  // ── Change Password ────────────────────────────────────────────────────────
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
    String lang = 'ar',
  }) async {
    final isAr = lang != 'en';
    try {
      final user = _auth.currentUser;
      final email = user?.email;
      if (user == null || email == null || email.isEmpty) {
        return isAr
            ? 'لا يمكن تغيير كلمة المرور لهذا الحساب'
            : 'Password cannot be changed for this account';
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: oldPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code, isAr: isAr);
    } catch (_) {
      return isAr
          ? 'حدث خطأ أثناء تغيير كلمة المرور'
          : 'An error occurred while changing the password';
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  /// Re-authenticates a social login user (Apple or Google) before account deletion.
  /// Returns null on success or an error/cancel message.
  Future<String?> _reauthenticateSocialUser(
    User user, {
    required bool isAr,
  }) async {
    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (providers.contains('apple.com')) {
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oAuth = OAuthProvider('apple.com').credential(
        idToken: cred.identityToken,
        accessToken: cred.authorizationCode,
      );
      await user.reauthenticateWithCredential(oAuth);
      return null;
    }
    if (providers.contains('google.com')) {
      final g = await _googleSignIn().signIn();
      if (g == null) {
        return isAr ? 'تم إلغاء التحقق من الهوية' : 'Identity verification canceled';
      }
      final gAuth = await g.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return null;
    }
    return isAr
        ? 'يرجى تسجيل الخروج وإعادة الدخول أولاً، ثم حذف الحساب'
        : 'Please sign out and sign in again before deleting your account';
  }

  // ── Delete Account (Apple App Store requirement — Guideline 5.1.1-v) ────────
  Future<String?> deleteAccount({
    String? password,
    String lang = 'ar',
  }) async {
    final isAr = lang != 'en';
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return isAr ? 'لا يوجد مستخدم مسجّل' : 'No signed-in user found';
      }

      // 1. Re-authenticate BEFORE deleting any Firestore data so a cancelled or
      // failed re-authentication never leaves an orphaned user profile.
      if (password != null && user.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        final lastSignIn = user.metadata.lastSignInTime;
        final sessionOld = lastSignIn == null ||
            DateTime.now().difference(lastSignIn).inMinutes >= 4;
        if (sessionOld) {
          final reauthErr = await _reauthenticateSocialUser(user, isAr: isAr);
          if (reauthErr != null) return reauthErr;
        }
      }

      // 2. Delete user data from Firestore first while auth token is still valid.
      await FirestoreDataService.deleteUserData(user.uid);

      // 3. Delete Firebase Auth account (with last-chance reauth fallback).
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code != 'requires-recent-login') rethrow;
        final reauthErr = await _reauthenticateSocialUser(user, isAr: isAr);
        if (reauthErr != null) return reauthErr;
        await user.delete();
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return isAr
            ? 'يرجى تسجيل الخروج وإعادة الدخول أولاً، ثم حذف الحساب'
            : 'Please sign out and sign in again before deleting your account';
      }
      return _authError(e.code, isAr: isAr);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('canceled') || msg.contains('cancel')) {
        return isAr ? 'تم إلغاء التحقق من الهوية' : 'Identity verification canceled';
      }
      return isAr
          ? 'حدث خطأ أثناء حذف الحساب'
          : 'An error occurred while deleting the account';
    }
  }

  // ── Get user data from Firestore ─────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return FirestoreDataService.getUserByUid(user.uid);
  }

  // ── Get display name ──────────────────────────────────────────────────────
  Future<String> getUserName() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    try {
      final data = await FirestoreDataService.getUserByUid(user.uid);
      return data?['name'] ?? user.displayName ?? '';
    } catch (_) {
      return user.displayName ?? '';
    }
  }

  // ── Auth error messages ───────────────────────────────────────────────────
  String _authError(String code, {bool isAr = true}) {
    switch (code) {
      case 'user-not-found':
        return isAr ? 'البريد الإلكتروني غير مسجل' : 'Email not registered';
      case 'wrong-password':
        return isAr ? 'كلمة المرور غير صحيحة' : 'Incorrect password';
      case 'email-already-in-use':
        return isAr ? 'البريد الإلكتروني مسجل مسبقاً' : 'Email is already registered';
      case 'weak-password':
        return isAr
            ? 'كلمة المرور ضعيفة (6 أحرف على الأقل)'
            : 'Weak password (at least 6 characters)';
      case 'invalid-email':
        return isAr ? 'البريد الإلكتروني غير صحيح' : 'Invalid email address';
      case 'network-request-failed':
        return isAr ? 'تحقق من الاتصال بالإنترنت' : 'Check your internet connection';
      case 'invalid-credential':
        return isAr
            ? 'البريد أو كلمة المرور غير صحيحة'
            : 'Invalid email or password';
      default:
        return isAr ? 'حدث خطأ: $code' : 'Authentication error: $code';
    }
  }
}
