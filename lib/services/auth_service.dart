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

  // ── Register ──────────────────────────────────────────────────────────────
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required int grade,
    String? section,
    String country = 'kw',
  }) async {
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
        lang: 'ar',
      );

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    } catch (e) {
      return 'حدث خطأ أثناء التسجيل';
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<String?> login({
    required String email,
    required String password,
  }) async {
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
      );

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    } catch (e) {
      return 'حدث خطأ أثناء تسجيل الدخول';
    }
  }

  // ── Apple Sign In ─────────────────────────────────────────────────────
  Future<String?> signInWithApple({int grade = 12, String section = 'scientific'}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'تسجيل الدخول بـ Apple متاح على أجهزة Apple فقط (iPhone / iPad). يرجى المتابعة عبر Google أو البريد الإلكتروني.';
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
          name: fullName.isNotEmpty ? fullName : (user.displayName ?? 'مستخدم'),
          email: cred.email ?? user.email ?? '',
          grade: grade,
          section: section,
          lang: 'ar',
        );
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        return 'تسجيل الدخول بـ Apple غير مفعّل في Firebase Console (Sign-in providers).';
      }
      return _authError(e.code);
    } catch (e) {
      final msg = e.toString();
      // User cancelled Apple Sign-In — don't show error
      if (msg.contains('AuthorizationErrorCode.canceled') ||
          msg.contains('canceled') ||
          msg.contains('cancel')) {
        return null;
      }
      return 'حدث خطأ أثناء تسجيل الدخول بـ Apple. يرجى المحاولة مجدداً.';
    }
  }

  // ── Google Sign In ─────────────────────────────────────────────────────
  Future<String?> signInWithGoogle({int grade = 12, String section = 'scientific'}) async {
    try {
      final googleSignIn = GoogleSignIn(
        clientId: kIsWeb || defaultTargetPlatform == TargetPlatform.iOS
            ? '82581349835-39166noa7oa449lakj80plqsgegau8rm.apps.googleusercontent.com'
            : null,
        serverClientId:
            '82581349835-hlk2cucplkba8e9j0aen58pqga6nk6m9.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
      final g = await googleSignIn.signIn();
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
          name: g.displayName ?? 'مستخدم',
          email: g.email,
          grade: grade,
          section: section,
          lang: 'ar',
        );
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        return 'تسجيل الدخول بـ Google غير مفعّل في Firebase Console (Sign-in providers).';
      }
      return _authError(e.code);
    } catch (e) {
      final msg = e.toString();
      // User cancelled Google Sign-In — don't show error
      if (msg.contains('canceled') || msg.contains('cancel') || msg.contains('sign_in_canceled')) {
        return null;
      }
      if (msg.contains('ApiException: 10') || msg.contains('10:')) {
        return 'خطأ مطوّر في Google Sign-In (ApiException 10): يلزم إضافة بصمة SHA-1 في Firebase Console وإعادة تحميل google-services.json.';
      }
      return 'حدث خطأ أثناء تسجيل الدخول بـ Google. يرجى المحاولة مجدداً.';
    }
  }

  // ── Change Password ────────────────────────────────────────────────────────
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      final email = user?.email;
      if (user == null || email == null || email.isEmpty) {
        return 'لا يمكن تغيير كلمة المرور لهذا الحساب';
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: oldPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    } catch (_) {
      return 'حدث خطأ أثناء تغيير كلمة المرور';
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  // ── Delete Account (Apple App Store requirement — Guideline 5.1.1-v) ────────
  Future<String?> deleteAccount({String? password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'لا يوجد مستخدم مسجّل';

      // Re-authenticate before deletion for security
      if (password != null && user.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // 1. Delete user data from Firestore first
      await FirestoreDataService.deleteUserData(user.uid);

      // 2. Delete Firebase Auth account
      await user.delete();

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'يرجى تسجيل الخروج وإعادة الدخول أولاً، ثم حذف الحساب';
      }
      return _authError(e.code);
    } catch (e) {
      return 'حدث خطأ أثناء حذف الحساب';
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
  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'البريد الإلكتروني غير مسجل';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مسجل مسبقاً';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (6 أحرف على الأقل)';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';
      case 'network-request-failed':
        return 'تحقق من الاتصال بالإنترنت';
      case 'invalid-credential':
        return 'البريد أو كلمة المرور غير صحيحة';
      default:
        return 'حدث خطأ: $code';
    }
  }
}
