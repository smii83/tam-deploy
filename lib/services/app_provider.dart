import 'dart:convert';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_data_service.dart';
import '../utils/app_theme.dart';

class AppProvider extends ChangeNotifier {
  bool _isDark = false;
  String _language = 'ar';
  String _selectedCountry = 'kw'; // Default country code: 'kw', 'sa', 'ae'
  AppThemeId _themeId = AppThemeId.deepSpace;
  Map<String, dynamic>? userData;
  List<Map<String, String>>? curriculumSubjects;

  /// SharedPreferences singleton — loaded once, reused everywhere
  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async => _prefs ??= await SharedPreferences.getInstance();

  /// Subjects cache timestamp — skip network refresh if < 5 minutes old
  DateTime? _subjectsCachedAt;

  /// Cached user name/email/country — available immediately from SharedPreferences
  String _cachedName = '';
  String _cachedEmail = '';
  String get cachedName => _cachedName;
  String get cachedEmail => _cachedEmail;
  String get selectedCountry => _selectedCountry;

  /// Whether user data has been loaded at least once
  bool _userLoaded = false;
  bool get userLoaded => _userLoaded;

  AppProvider() {
    _load();
  }

  // ── Persist settings ────────────────────────────────────────────────────────
  Future<void> _load() async {
    final p = await _p;
    _isDark = p.getBool('dark') ?? false;
    _language = p.getString('lang') ?? 'ar';
    _selectedCountry = p.getString('country') ?? 'kw';
    // ── Restore theme selection
    final savedTheme = p.getString('theme_id') ?? 'deepSpace';
    _themeId = AppThemeId.values.firstWhere(
      (e) => e.name == savedTheme,
      orElse: () => AppThemeId.deepSpace,
    );
    // ── Restore cached user name/email immediately (before network call)
    _cachedName = p.getString('cached_name') ?? '';
    _cachedEmail = p.getString('cached_email') ?? '';
    // ── Restore cached subjects immediately (before network call)
    _restoreCachedSubjects(p);
    notifyListeners();
  }

  Future<void> setCountry(String countryCode) async {
    _selectedCountry = countryCode;
    final p = await _p;
    await p.setString('country', countryCode);
    notifyListeners();
  }

  /// Restore previously cached subjects from SharedPreferences so the
  /// home screen renders instantly on the next app launch.
  void _restoreCachedSubjects(SharedPreferences p) {
    try {
      final raw = p.getString('cached_subjects');
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .cast<Map<String, dynamic>>()
            .map<Map<String, String>>(
              (m) => m.map((k, v) => MapEntry(k, v.toString())),
            )
            .toList();
        if (list.isNotEmpty) curriculumSubjects = list;
      }
    } catch (_) {}
  }

  /// Cache the current curriculumSubjects list to SharedPreferences.
  Future<void> _cacheSubjects() async {
    if (curriculumSubjects == null) return;
    try {
      final p = await _p;
      await p.setString('cached_subjects', jsonEncode(curriculumSubjects));
    } catch (_) {}
  }

  Future<void> toggleDark() async {
    _isDark = !_isDark;
    final p = await _p;
    await p.setBool('dark', _isDark);
    notifyListeners();
  }

  Future<void> setTheme(AppThemeId id) async {
    _themeId = id;
    final p = await _p;
    await p.setString('theme_id', id.name);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final p = await _p;
    await p.setString('lang', lang);
    // Also update Firestore if user is logged in
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirestoreDataService.updateUserLang(uid, lang);
    }
    notifyListeners();
  }

  bool get isDark => _isDark;
  String get language => _language;
  bool get isAr => _language == 'ar';
  AppThemeId get themeId => _themeId;

  // ── Load user data from Firestore ──────────────────────────────────────────
  Future<void> loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final data = await FirestoreDataService.getUserByUid(uid);
      if (data == null) return;

      userData = data;

      // Cache user name + email to SharedPreferences for instant display
      final fetchedName = (data['name'] as String?)?.trim() ?? '';
      final fetchedEmail = (data['email'] as String?)?.trim() ?? '';
      if (fetchedName.isNotEmpty) _cachedName = fetchedName;
      if (fetchedEmail.isNotEmpty) _cachedEmail = fetchedEmail;
      try {
        final p = await _p;
        if (fetchedName.isNotEmpty) await p.setString('cached_name', fetchedName);
        if (fetchedEmail.isNotEmpty) await p.setString('cached_email', fetchedEmail);
      } catch (_) {}

      // Sync language from Firestore user record
      final pbLang = data['lang'] as String?;
      if (pbLang != null && pbLang.isNotEmpty && pbLang != _language) {
        _language = pbLang;
        final p = await _p;
        await p.setString('lang', _language);
      }

      // Load subjects from Firestore based on user's grade
      final grade = (data['grade'] as num?)?.toInt() ?? 12;
      final section = data['section'] as String? ?? 'scientific';
      await _loadCurriculumFromFirestore(grade, section);

      _userLoaded = true;
      notifyListeners();
    } catch (_) {
      // Fallback: use static subjects list
      _userLoaded = true;
      notifyListeners();
    }
  }

  /// Load subjects from Firestore. Falls back to static list if unreachable.
  Future<void> _loadCurriculumFromFirestore(int grade, String section) async {
    try {
      final pbSubjects = await FirestoreDataService.getSubjectsByGradeNumber(
          grade, section, selectedCountry);
      if (pbSubjects.isNotEmpty) {
        // Map Firestore records → app-compatible Map<String, String>
        curriculumSubjects = pbSubjects.map<Map<String, String>>((s) {
          return <String, String>{
            'ar': (s['name_ar'] as String?) ?? '',
            'en': (s['name_en'] as String?) ?? '',
            'em': (s['icon'] as String?) ?? '📚',
            'color': ((s['color'] as String?) ?? '7c3aed').replaceAll('#', ''),
            'id': (s['id'] as String?) ?? '',
          };
        }).toList();
      } else {
        // Firestore has no subjects yet — use static list
        curriculumSubjects = getSubjects(grade, section, selectedCountry)
            .map<Map<String, String>>((s) {
              final copy = Map<String, String>.from(s);
              copy.remove('icon');
              return copy;
            })
            .toList();
      }
    } catch (_) {
      // Fallback to static list
      curriculumSubjects = getSubjects(grade, section, selectedCountry)
          .map((s) {
            final copy = Map<String, String>.from(s);
            copy.remove('icon');
            return copy;
          })
          .toList();
    }
    // Update cache timestamp and persist to SharedPreferences
    _subjectsCachedAt = DateTime.now();
    await _cacheSubjects();
  }

  /// Refresh curriculum subjects from Firestore.
  /// Skips network call if cache is less than 5 minutes old.
  Future<void> refreshSubjects({bool force = false}) async {
    if (!force && _subjectsCachedAt != null) {
      final age = DateTime.now().difference(_subjectsCachedAt!);
      if (age.inMinutes < 5) return; // Cache still fresh
    }
    final grade = (userData?['grade'] as num?)?.toInt() ?? 12;
    final section = userData?['section'] as String? ?? 'scientific';
    await _loadCurriculumFromFirestore(grade, section);
    notifyListeners();
  }

  /// Clear all user data on logout — prevents stale data from leaking between sessions
  Future<void> clearUserData() async {
    userData = null;
    curriculumSubjects = null;
    _userLoaded = false;
    _cachedName = '';
    _cachedEmail = '';
    _subjectsCachedAt = null;
    // Also clear caches so the next user gets fresh data
    try {
      final p = await _p;
      await p.remove('cached_subjects');
      await p.remove('cached_name');
      await p.remove('cached_email');
    } catch (_) {}
    notifyListeners();
  }

  /// Update grade in Firestore and refresh subjects
  Future<void> updateGrade(int grade, [String? section]) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirestoreDataService.updateUserGrade(uid, grade, section);
    if (userData != null) {
      userData!['grade'] = grade;
      if (section != null) userData!['section'] = section;
    }
    await _loadCurriculumFromFirestore(
      grade,
      section ?? (userData?['section'] as String? ?? 'scientific'),
    );
    notifyListeners();
  }

  // ── All UI text — AR/EN ─────────────────────────────────────────────────────
  String get appName       => isAr ? 'منصة تَم التعليمية' : 'TAM Educational Platform';
  String get home          => isAr ? 'الرئيسية' : 'Home';
  String get lessons       => isAr ? 'الدروس' : 'Lessons';
  String get settings      => isAr ? 'الإعدادات' : 'Settings';
  String get subjects      => isAr ? 'المواد الدراسية' : 'Subjects';
  String get chooseSubject => isAr ? 'اختر المادة' : 'Choose Subject';
  String get chooseGrade   => isAr ? 'اختر صفك الدراسي' : 'Choose Your Grade';
  String get files         => isAr ? 'ملفات المادة' : 'Subject Files';
  String get summaries     => isAr ? 'ملخصات' : 'Summaries';
  String get examAnswers   => isAr ? 'أجوبة امتحانات' : 'Exam Answers';
  String get shortQuiz     => isAr ? 'اختبار قصير' : 'Quick Quiz';
  String get askTeacher    => isAr ? 'اسأل المدرس' : 'Ask Teacher';
  String get login         => isAr ? 'تسجيل الدخول' : 'Login';
  String get register      => isAr ? 'إنشاء حساب' : 'Register';
  String get name          => isAr ? 'الاسم الكامل' : 'Full Name';
  String get email         => isAr ? 'البريد الإلكتروني' : 'Email';
  String get password      => isAr ? 'كلمة المرور' : 'Password';
  String get confirmPwd    => isAr ? 'تأكيد كلمة المرور' : 'Confirm Password';
  String get forgotPassword => isAr ? 'نسيت كلمة المرور؟' : 'Forgot Password?';
  String get resetPassword => isAr ? 'إعادة تعيين كلمة المرور' : 'Reset Password';
  String get resetPasswordSent => isAr ? 'تم إرسال رابط إعادة التعيين إلى بريدك. تحقق من صندوق البريد واتبع التعليمات.' : 'Password reset link sent to your email. Check your inbox.';
  String get logoutConfirmTitle => isAr ? 'تسجيل الخروج' : 'Log Out';
  String get logoutConfirmMsg => isAr ? 'هل أنت متأكد من رغبتك في تسجيل الخروج؟' : 'Are you sure you want to log out?';
  String get cancel         => isAr ? 'إلغاء' : 'Cancel';
  String get confirm        => isAr ? 'تأكيد' : 'Confirm';
  String get gradeLabel     => isAr ? 'الصف' : 'Grade';
  String get subscribe     => isAr ? 'اشترك وابدأ رحلتك التعليمية 🎓' : 'Subscribe & Start Learning 🎓';
  String get subscribeTitle => isAr ? 'اشتراك كورس كامل بلا حدود' : 'Unlimited Full Course Subscription';
  String get nextQuestion  => isAr ? 'السؤال التالي ←' : 'Next Question →';
  String get darkMode      => isAr ? 'الوضع الداكن' : 'Dark Mode';
  String get languageLabel => isAr ? 'اللغة' : 'Language';
  String get changePwd     => isAr ? 'تغيير كلمة المرور' : 'Change Password';
  String get logout        => isAr ? 'تسجيل الخروج' : 'Logout';
  String get withApple     => isAr ? 'متابعة مع Apple' : 'Continue with Apple';
  String get withGoogle    => isAr ? 'متابعة مع Google' : 'Continue with Google';
  String get paySecure     => isAr ? 'الدفع يتم عبر متجر جهازك بشكل آمن' : 'Payment processed securely via your device store';
  String get correct       => isAr ? '✅ الإجابة الصحيحة' : '✅ Correct!';
  String get wrong         => isAr ? '❌ إجابة خاطئة' : '❌ Wrong';
  String get cameraTitle   => isAr ? 'حل بالكاميرا' : 'Solve with Camera';
  String get cameraSub     => isAr ? 'صوّر سؤالك ونحله فوراً' : 'Photo your question and we solve it';
  String get takePhoto     => isAr ? 'التقط الصورة' : 'Take Photo';
  String get uploadPhoto   => isAr ? 'ارفع من الجهاز' : 'Upload from Device';
  String get solving       => isAr ? 'جاري حل السؤال...' : 'Solving...';
  String get solved        => isAr ? 'الحل الكامل' : 'Complete Solution';
  String get noLessons     => isAr ? 'لا توجد دروس حالياً' : 'No lessons available yet';
  String get noFiles       => isAr ? 'لا توجد ملفات حالياً' : 'No files available yet';
  String get startQuiz     => isAr ? 'ابدأ الاختبار' : 'Start Quiz';
  String get retryQuiz     => isAr ? 'إعادة الاختبار 🔄' : 'Retry Quiz 🔄';
  String get showResult    => isAr ? 'عرض النتيجة 🏆' : 'View Result 🏆';
  String get activeSubscription => isAr ? 'اشتراك نشط ✓' : 'Active Subscription ✓';
  String get notifications => isAr ? 'الإشعارات' : 'Notifications';
  String get notifLessons  => isAr ? 'إشعارات الدروس الجديدة' : 'New Lesson Notifications';
  String get notifReminder => isAr ? 'تذكير يومي بالمذاكرة' : 'Daily Study Reminder';
  String get account       => isAr ? 'الحساب' : 'Account';
  String get appearance    => isAr ? 'المظهر' : 'Appearance';
  String get about         => isAr ? 'عن التطبيق' : 'About';
  String get version       => isAr ? 'الإصدار 1.0.0' : 'Version 1.0.0';
  String get greetingMorn  => isAr ? 'صباح الخير 👋' : 'Good morning 👋';
  String get greetingAft   => isAr ? 'مساء الخير ☀️' : 'Good afternoon ☀️';
  String get greetingEve   => isAr ? 'مساء النور 🌙' : 'Good evening 🌙';
  String get subscribed    => isAr ? 'مشترك ✓' : 'Subscribed ✓';
  String get solveByCam    => isAr ? 'حل بالكاميرا' : 'Solve by Camera';
  String get solveDesc     => isAr ? 'صوّر السؤال → نحله فوراً ✨' : 'Photo question → Instant solution ✨';
  String get scientific    => isAr ? 'علمي' : 'Scientific';
  String get literary      => isAr ? 'أدبي' : 'Literary';
  String get chooseSection => isAr ? 'اختر القسم' : 'Choose Section';
  String get loading       => isAr ? 'جارٍ التحميل...' : 'Loading...';
  String get retry         => isAr ? 'إعادة المحاولة' : 'Retry';
  String get errLoadLessons => isAr ? 'تعذّر تحميل الدروس' : 'Could not load lessons';
  String get errLoadFiles   => isAr ? 'تعذّر تحميل الملفات' : 'Could not load files';
  String get errConnection  => isAr ? 'تحقق من اتصالك بالإنترنت' : 'Check your internet connection';
  String get errGeneric     => isAr ? 'حدث خطأ غير متوقع' : 'An unexpected error occurred';
  String get comingSoon     => isAr ? 'قريباً' : 'Coming Soon';
  String get newBadge       => isAr ? 'جديد' : 'New';
  String get lessonsAdded   => isAr ? 'سيتم إضافة الدروس قريباً' : 'Lessons will be added soon';
  String get filesAdded     => isAr ? 'سيتم إضافة الملفات قريباً' : 'Files will be added soon';
  String get noConnection  => isAr ? 'تحقق من الاتصال بالإنترنت' : 'Check your internet connection';

  // ── Settings screen strings ──────────────────────────────────────────────────
  String get pwdMismatch    => isAr ? 'كلمتا المرور غير متطابقتين ❌' : 'Passwords do not match ❌';
  String get pwdTooShort    => isAr ? 'كلمة المرور قصيرة (6 أحرف على الأقل) ❌' : 'Password too short (min 6 chars) ❌';
  String get pwdChanged     => isAr ? 'تم تغيير كلمة المرور بنجاح ✅' : 'Password changed successfully ✅';
  String get pwdError       => isAr ? 'خطأ في تغيير كلمة المرور' : 'Error changing password';
  String get deleteWarning {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return isAr
          ? '⚠️ تنبيه: إذا كان لديك اشتراك فعّال، يرجى إلغاؤه يدوياً من إعدادات جهازك (إعدادات Apple ID ← الاشتراكات) قبل حذف الحساب لتجنب استمرار التجديد.'
          : '⚠️ Note: If you have an active subscription, please cancel it manually in your device settings (Apple ID Settings → Subscriptions) before deleting your account.';
    }
    return isAr
        ? '⚠️ تنبيه: إذا كان لديك اشتراك فعّال، يرجى إلغاؤه يدوياً من إعدادات المتجر بجهازك قبل حذف الحساب لتجنب الاستمرار في الدفع.'
        : '⚠️ Note: If you have an active subscription, please cancel it manually in your device store settings before deleting your account.';
  }

  /// Returns a localized grade text, e.g. 'الصف 12' or 'Grade 12'
  String gradeText(int grade) => isAr ? 'الصف $grade' : 'Grade $grade';

  // ── Official Curricula Subjects (Kuwait, Saudi Arabia, UAE) ──────────────────
  static List<Map<String, String>> getSubjects(int grade, [String? section, String country = 'kw']) {
    if (country == 'sa') {
      if (grade == 99) return _saQudrat;
      if (grade >= 7 && grade <= 9) return _saMiddle;
      if (grade == 10) return _saHigh10;
      return _saHigh11_12;
    } else if (country == 'ae') {
      if (grade == 98) return _aeEmsat;
      if (grade >= 6 && grade <= 9) return _aeMiddle;
      return _aeHigh;
    }

    // Default: Kuwait Curriculum
    if (grade >= 1 && grade <= 6) return _elementary;
    if (grade >= 7 && grade <= 9) return _middle;
    if (grade == 10) {
      final isTracks = section?.toLowerCase() == 'tracks';
      return isTracks ? _kwTracks10 : _unified10;
    }

    final isLit = section?.toLowerCase() == 'literary';
    if (grade == 11) return isLit ? _literary11 : _scientific11;
    if (grade == 12) return isLit ? _literary12 : _scientific12;

    return _scientific12; // Default fallback
  }

  // ── Kuwait Official New Tracks Curriculum (الصف العاشر — نظام المسارات المطوّر) ───
  static const List<Map<String, String>> _kwTracks10 = [
    {'ar': 'العلوم المتكاملة',          'en': 'Integrated Science',  'em': '🔬', 'color': '059669'},
    {'ar': 'الرياضيات',                 'en': 'Mathematics',         'em': '🔢', 'color': 'F97316'},
    {'ar': 'الحوسبة والذكاء الاصطناعي', 'en': 'Computing & AI',      'em': '💻', 'color': '6D28D9'},
    {'ar': 'مقرر الاستكشاف (1 و 2)',    'en': 'Exploration Courses', 'em': '🧭', 'color': '0284C7'},
    {'ar': 'اللغة العربية',             'en': 'Arabic',              'em': '📝', 'color': '4F46E5'},
    {'ar': 'اللغة الإنجليزية',          'en': 'English',             'em': '🇬🇧', 'color': '2563EB'},
    {'ar': 'التربية الإسلامية',         'en': 'Islamic Ed.',         'em': '☪️', 'color': '10B981'},
    {'ar': 'الدراسات الاجتماعية',       'en': 'Social Studies',      'em': '🌍', 'color': 'B45309'},
    {'ar': 'دليل المسارات المستقبلية',   'en': 'Career Tracks Guide', 'em': '🎯', 'color': 'EC4899'},
  ];

  // ── Saudi Arabia Official MOE Curricula ─────────────────────────────────────
  static const List<Map<String, String>> _saQudrat = [
    {'ar': 'اختبار القدرات العامة (كمي)', 'en': 'Qudrat Quantitative', 'em': '🔢', 'color': 'F97316'},
    {'ar': 'اختبار القدرات العامة (لفظي)', 'en': 'Qudrat Verbal', 'em': '📝', 'color': '4F46E5'},
    {'ar': 'اختبار التحصيلي (علوم وفصل)', 'en': 'Tahsili Science', 'em': '⚛️', 'color': '7C3AED'},
    {'ar': 'اختبار التحصيلي (رياضيات)', 'en': 'Tahsili Math', 'em': '📊', 'color': '0284C7'},
  ];

  static const List<Map<String, String>> _saMiddle = [
    {'ar': 'الرياضيات', 'en': 'Mathematics', 'em': '🔢', 'color': 'F97316'},
    {'ar': 'العلوم', 'en': 'Science', 'em': '🔬', 'color': '059669'},
    {'ar': 'لغتي الخالدة', 'en': 'Arabic', 'em': '📝', 'color': '4F46E5'},
    {'ar': 'اللغة الإنجليزية (Super Goal)', 'en': 'English', 'em': '🇬🇧', 'color': '0284C7'},
    {'ar': 'الدراسات الإسلامية', 'en': 'Islamic Studies', 'em': '☪️', 'color': '10B981'},
    {'ar': 'الدراسات الاجتماعية', 'en': 'Social Studies', 'em': '🇸🇦', 'color': '2563EB'},
    {'ar': 'المهارات الرقمية', 'en': 'Digital Skills', 'em': '💻', 'color': '6D28D9'},
    {'ar': 'التفكير الناقد', 'en': 'Critical Thinking', 'em': '💡', 'color': 'B45309'},
  ];

  static const List<Map<String, String>> _saHigh10 = [
    {'ar': 'الرياضيات 1', 'en': 'Math 1', 'em': '🔢', 'color': 'F97316'},
    {'ar': 'الفيزياء 1', 'en': 'Physics 1', 'em': '⚛️', 'color': '7C3AED'},
    {'ar': 'الكيمياء 1', 'en': 'Chemistry 1', 'em': '🧪', 'color': '059669'},
    {'ar': 'الأحياء 1', 'en': 'Biology 1', 'em': '🧬', 'color': 'EC4899'},
    {'ar': 'الكفايات اللغوية', 'en': 'Arabic', 'em': '📝', 'color': '4F46E5'},
    {'ar': 'اللغة الإنجليزية (Mega Goal)', 'en': 'English', 'em': '🇬🇧', 'color': '0284C7'},
    {'ar': 'التقنية الرقمية', 'en': 'Digital Tech', 'em': '💻', 'color': '6D28D9'},
    {'ar': 'التفكير الناقد', 'en': 'Critical Thinking', 'em': '💡', 'color': 'B45309'},
  ];

  static const List<Map<String, String>> _saHigh11_12 = [
    {'ar': 'الرياضيات (مسارات)', 'en': 'Mathematics Tracks', 'em': '🔢', 'color': 'F97316'},
    {'ar': 'الفيزياء (مسارات)', 'en': 'Physics Tracks', 'em': '⚛️', 'color': '7C3AED'},
    {'ar': 'الكيمياء (مسارات)', 'en': 'Chemistry Tracks', 'em': '🧪', 'color': '059669'},
    {'ar': 'الأحياء (مسارات)', 'en': 'Biology Tracks', 'em': '🧬', 'color': 'EC4899'},
    {'ar': 'الأمن السيبراني والذكاء الاصطناعي', 'en': 'Cybersecurity & AI', 'em': '🤖', 'color': '6D28D9'},
    {'ar': 'اللغة الإنجليزية', 'en': 'English', 'em': '🇬🇧', 'color': '0284C7'},
    {'ar': 'الدراسات الإسلامية', 'en': 'Islamic Studies', 'em': '☪️', 'color': '10B981'},
  ];

  // ── UAE Official MOE Curricula ─────────────────────────────────────────────
  static const List<Map<String, String>> _aeEmsat = [
    {'ar': 'اختبار EmSAT رياضيات', 'en': 'EmSAT Math', 'em': '🔢', 'color': 'F97316'},
    {'ar': 'اختبار EmSAT فيزياء', 'en': 'EmSAT Physics', 'em': '⚛️', 'color': '7C3AED'},
    {'ar': 'اختبار EmSAT كيمياء', 'en': 'EmSAT Chemistry', 'em': '🧪', 'color': '059669'},
    {'ar': 'اختبار EmSAT أحياء', 'en': 'EmSAT Biology', 'em': '🧬', 'color': 'EC4899'},
    {'ar': 'اختبار EmSAT لغة إنجليزية', 'en': 'EmSAT English', 'em': '🇬🇧', 'color': '0284C7'},
  ];

  static const List<Map<String, String>> _aeMiddle = [
    {'ar': 'الرياضيات', 'en': 'Mathematics', 'em': '🔢', 'color': 'F97316'},
    {'ar': 'العلوم', 'en': 'Science', 'em': '🔬', 'color': '059669'},
    {'ar': 'اللغة العربية', 'en': 'Arabic', 'em': '📝', 'color': '4F46E5'},
    {'ar': 'اللغة الإنجليزية', 'en': 'English', 'em': '🇬🇧', 'color': '0284C7'},
    {'ar': 'التربية الإسلامية', 'en': 'Islamic Ed.', 'em': '☪️', 'color': '10B981'},
    {'ar': 'الدراسات الاجتماعية', 'en': 'Social Studies', 'em': '🇦🇪', 'color': '2563EB'},
  ];

  static const List<Map<String, String>> _aeHigh = [
    {'ar': 'الرياضيات (عام ومتقدم)', 'en': 'Mathematics', 'em': '🔢', 'color': 'F97316'},
    {'ar': 'الفيزياء (عام ومتقدم)', 'en': 'Physics', 'em': '⚛️', 'color': '7C3AED'},
    {'ar': 'الكيمياء (عام ومتقدم)', 'en': 'Chemistry', 'em': '🧪', 'color': '059669'},
    {'ar': 'الأحياء (عام ومتقدم)', 'en': 'Biology', 'em': '🧬', 'color': 'EC4899'},
    {'ar': 'اللغة العربية', 'en': 'Arabic', 'em': '📝', 'color': '4F46E5'},
    {'ar': 'اللغة الإنجليزية', 'en': 'English', 'em': '🇬🇧', 'color': '0284C7'},
    {'ar': 'التصميم والتكنولوجيا والذكاء الاصطناعي', 'en': 'Design & Tech', 'em': '💻', 'color': '6D28D9'},
    {'ar': 'الدراسات الاجتماعية والإماراتية', 'en': 'Emirates Studies', 'em': '🇦🇪', 'color': '2563EB'},
  ];

  static const List<Map<String, String>> _elementary = [
    {'ar': 'اللغة العربية', 'en': 'Arabic',           'em': '📝', 'color': '4F46E5'},
    {'ar': 'الرياضيات',    'en': 'Mathematics',       'em': '🔢', 'color': 'F97316'},
    {'ar': 'العلوم',       'en': 'Science',           'em': '🔬', 'color': '059669'},
    {'ar': 'التربية الإسلامية','en': 'Islamic Ed.',  'em': '☪️', 'color': '10B981'},
    {'ar': 'اللغة الإنجليزية','en': 'English',       'em': '🇬🇧', 'color': '0284C7'},
    {'ar': 'التربية الاجتماعية','en': 'Social',      'em': '🌍', 'color': '0891B2'},
    {'ar': 'التربية الفنية','en': 'Art',             'em': '🎨', 'color': 'DB2777'},
    {'ar': 'الحاسوب',      'en': 'Computer',         'em': '💻', 'color': '7C3AED'},
  ];

  static const List<Map<String, String>> _middle = [
    {'ar': 'اللغة العربية', 'en': 'Arabic',          'em': '📝', 'color': '4F46E5'},
    {'ar': 'الرياضيات',    'en': 'Mathematics',      'em': '🔢', 'color': 'F97316'},
    {'ar': 'الفيزياء',     'en': 'Physics',          'em': '⚛️', 'color': '7C3AED'},
    {'ar': 'الكيمياء',     'en': 'Chemistry',        'em': '🧪', 'color': '059669'},
    {'ar': 'الأحياء',      'en': 'Biology',          'em': '🧬', 'color': 'EC4899'},
    {'ar': 'التربية الإسلامية','en': 'Islamic Ed.', 'em': '☪️', 'color': '10B981'},
    {'ar': 'القرآن الكريم','en': 'Quran',           'em': '📖', 'color': '0D9488'},
    {'ar': 'الجغرافيا',    'en': 'Geography',        'em': '🗺️', 'color': '0891B2'},
    {'ar': 'التربية الوطنية','en': 'National Ed.',  'em': '🇰🇼', 'color': '2563EB'},
    {'ar': 'الحاسوب',      'en': 'Computer',         'em': '💻', 'color': '6D28D9'},
  ];

  static const List<Map<String, String>> _unified10 = [
    {'ar': 'الرياضيات',    'en': 'Mathematics',      'em': '🔢', 'color': 'F97316'},
    {'ar': 'الفيزياء',     'en': 'Physics',          'em': '⚛️', 'color': '7C3AED'},
    {'ar': 'الكيمياء',     'en': 'Chemistry',        'em': '🧪', 'color': '059669'},
    {'ar': 'الأحياء',      'en': 'Biology',          'em': '🧬', 'color': 'EC4899'},
    {'ar': 'اللغة العربية','en': 'Arabic',           'em': '📝', 'color': '4F46E5'},
    {'ar': 'اللغة الإنجليزية','en': 'English',      'em': '🇬🇧', 'color': '0284C7'},
    {'ar': 'التاريخ',      'en': 'History',          'em': '📜', 'color': 'B45309'},
    {'ar': 'الجغرافيا',    'en': 'Geography',        'em': '🗺️', 'color': '0891B2'},
    {'ar': 'التربية الإسلامية','en': 'Islamic Ed.', 'em': '☪️', 'color': '10B981'},
    {'ar': 'الحاسوب',      'en': 'Computer',         'em': '💻', 'color': '6D28D9'},
    {'ar': 'القرآن الكريم','en': 'Quran',           'em': '📖', 'color': '0D9488'},
  ];

  static const List<Map<String, String>> _scientific11 = [
    {'ar': 'الرياضيات',    'en': 'Mathematics',      'em': '🔢', 'color': 'F97316'},
    {'ar': 'الفيزياء',     'en': 'Physics',          'em': '⚛️', 'color': '7C3AED'},
    {'ar': 'الكيمياء',     'en': 'Chemistry',        'em': '🧪', 'color': '059669'},
    {'ar': 'الأحياء',      'en': 'Biology',          'em': '🧬', 'color': 'EC4899'},
    {'ar': 'اللغة العربية','en': 'Arabic',           'em': '📝', 'color': '4F46E5'},
    {'ar': 'اللغة الإنجليزية','en': 'English',      'em': '🇬🇧', 'color': '0284C7'},
    {'ar': 'التربية الإسلامية','en': 'Islamic Ed.', 'em': '☪️', 'color': '10B981'},
    {'ar': 'الحاسوب',      'en': 'Computer',         'em': '💻', 'color': '6D28D9'},
    {'ar': 'القرآن الكريم','en': 'Quran',           'em': '📖', 'color': '0D9488'},
  ];

  static const List<Map<String, String>> _scientific12 = [
    {'ar': 'الرياضيات',    'en': 'Mathematics',      'em': '🔢', 'color': 'F97316'},
    {'ar': 'الفيزياء',     'en': 'Physics',          'em': '⚛️', 'color': '7C3AED'},
    {'ar': 'الكيمياء',     'en': 'Chemistry',        'em': '🧪', 'color': '059669'},
    {'ar': 'الأحياء',      'en': 'Biology',          'em': '🧬', 'color': 'EC4899'},
    {'ar': 'اللغة العربية','en': 'Arabic',           'em': '📝', 'color': '4F46E5'},
    {'ar': 'اللغة الإنجليزية','en': 'English',      'em': '🇬🇧', 'color': '0284C7'},
    {'ar': 'التربية الإسلامية','en': 'Islamic Ed.', 'em': '☪️', 'color': '10B981'},
    {'ar': 'الدستور',      'en': 'Constitution',     'em': '🇰🇼', 'color': '2563EB'},
    {'ar': 'القرآن الكريم','en': 'Quran',           'em': '📖', 'color': '0D9488'},
  ];

  static const List<Map<String, String>> _literary11 = [
    {'ar': 'اللغة العربية',  'en': 'Arabic',          'em': '📝', 'color': '4F46E5'},
    {'ar': 'اللغة الإنجليزية','en': 'English',       'em': '🇬🇧', 'color': '0284C7'},
    {'ar': 'اللغة الفرنسية','en': 'French',          'em': '🇫🇷', 'color': '2563EB'},
    {'ar': 'التاريخ الأسلامي','en': 'History',       'em': '📜', 'color': 'B45309'},
    {'ar': 'الجغرافيا',     'en': 'Geography',        'em': '🗺️', 'color': '0891B2'},
    {'ar': 'علم النفس',     'en': 'Psychology',       'em': '🧠', 'color': '9333EA'},
    {'ar': 'مبادئ المنطق', 'en': 'Logic',            'em': '💡', 'color': 'D97706'},
    {'ar': 'الإحصاء',       'en': 'Statistics',       'em': '📊', 'color': '0369A1'},
    {'ar': 'التربية الإسلامية','en': 'Islamic Ed.',  'em': '☪️', 'color': '10B981'},
    {'ar': 'القرآن الكريم','en': 'Quran',            'em': '📖', 'color': '0D9488'},
  ];

  static const List<Map<String, String>> _literary12 = [
    {'ar': 'اللغة العربية',  'en': 'Arabic',          'em': '📝', 'color': '4F46E5'},
    {'ar': 'اللغة الإنجليزية','en': 'English',       'em': '🇬🇧', 'color': '0284C7'},
    {'ar': 'اللغة الفرنسية','en': 'French',          'em': '🇫🇷', 'color': '2563EB'},
    {'ar': 'تاريخ العالم',  'en': 'History',          'em': '📜', 'color': 'B45309'},
    {'ar': 'الجغرافيا',     'en': 'Geography',        'em': '🗺️', 'color': '0891B2'},
    {'ar': 'الفلسفة',       'en': 'Philosophy',       'em': '🏺', 'color': 'BE185D'},
    {'ar': 'الإحصاء',       'en': 'Statistics',       'em': '📊', 'color': '0369A1'},
    {'ar': 'التربية الإسلامية','en': 'Islamic Ed.',  'em': '☪️', 'color': '10B981'},
    {'ar': 'الدستور',       'en': 'Constitution',     'em': '🇰🇼', 'color': '2563EB'},
    {'ar': 'القرآن الكريم','en': 'Quran',            'em': '📖', 'color': '0D9488'},
  ];
}
