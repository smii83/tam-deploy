import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tam_app/models/interactive_lesson_model.dart';
import 'package:tam_app/screens/auth/login_screen.dart';
import 'package:tam_app/screens/auth/register_screen.dart';
import 'package:tam_app/screens/student/payment_screen.dart';
import 'package:tam_app/screens/student/quiz_screen.dart';
import 'package:tam_app/screens/student/slide_lesson_screen.dart';
import 'package:tam_app/services/app_provider.dart';
import 'package:tam_app/services/auth_service.dart';

/// Pure in-memory fake for [AuthService] so full multi-screen UI journeys run
/// deterministically without touching live Firebase Auth.
class FakeAuthService extends ChangeNotifier implements AuthService {
  bool registered = false;
  bool loggedIn = false;
  bool loggedOut = false;
  String? nextLoginError = 'بيانات الدخول غير صحيحة';
  String? nextRegisterError;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStream => const Stream<User?>.empty();

  @override
  bool get isPasswordUser => true;

  @override
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required int grade,
    String? section,
    String country = 'kw',
    String lang = 'ar',
  }) async {
    if (nextRegisterError != null) return nextRegisterError;
    registered = true;
    return null;
  }

  @override
  Future<String?> login({
    required String email,
    required String password,
    String lang = 'ar',
  }) async {
    if (nextLoginError != null) return nextLoginError;
    loggedIn = true;
    return null;
  }

  @override
  Future<String?> signInWithApple({
    int grade = 12,
    String section = 'scientific',
    String country = 'kw',
    String lang = 'ar',
  }) async =>
      null;

  @override
  Future<String?> signInWithGoogle({
    int grade = 12,
    String section = 'scientific',
    String country = 'kw',
    String lang = 'ar',
  }) async =>
      null;

  @override
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
    String lang = 'ar',
  }) async =>
      null;

  @override
  Future<void> logout() async {
    loggedOut = true;
    loggedIn = false;
    notifyListeners();
  }

  @override
  Future<String?> deleteAccount({
    String? password,
    String lang = 'ar',
  }) async =>
      null;

  @override
  Future<Map<String, dynamic>?> getUserData() async => null;

  @override
  Future<String> getUserName() async => 'طالب تجريبي';
}

/// Pure in-memory [AppProvider] avoiding native Firebase calls on `loadUserData`/`clearUserData`.
class FakeAppProvider extends AppProvider {
  bool cleared = false;
  final bool? _forceDark;

  FakeAppProvider({bool? forceDark}) : _forceDark = forceDark;

  @override
  bool get isDark => _forceDark ?? super.isDark;

  @override
  Future<void> loadUserData() async {
    notifyListeners();
  }

  @override
  Future<void> clearUserData() async {
    cleared = true;
    setSubscribed(false);
    notifyListeners();
  }
}

Widget _wrapWithProviders(
  FakeAppProvider appProvider,
  FakeAuthService authService,
  Widget child,
) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ChangeNotifierProvider<AuthService>.value(value: authService),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'lang': 'ar'});
  });

  testWidgets(
      'Student Journey E2E: Login error -> Language toggle -> Navigate to Register -> Validation -> Register -> Payment Guard -> Logout',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

    final appProvider = FakeAppProvider();
    final authService = FakeAuthService();

    await tester.pumpWidget(
      _wrapWithProviders(appProvider, authService, const LoginScreen()),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Toggle language EN <-> AR and verify localized strings update
    expect(find.text('منصة تـم التعليمية'), findsOneWidget);
    await tester.tap(find.text('EN'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('TAM Educational Platform'), findsOneWidget);

    await tester.tap(find.text('ع'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('منصة تـم التعليمية'), findsOneWidget);

    // 2. Invalid login displays inline error banner
    await tester.enterText(find.byType(TextField).at(0), 'bad@test.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrongpass');
    final loginBtn = find.text('تسجيل الدخول').last;
    await tester.ensureVisible(loginBtn);
    await tester.tap(loginBtn);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('بيانات الدخول غير صحيحة'), findsOneWidget);

    // 3. Navigate from LoginScreen to RegisterScreen
    final registerNav = find.text('إنشاء حساب');
    await tester.ensureVisible(registerNav);
    await tester.tap(registerNav);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RegisterScreen), findsOneWidget);

    // 4. Register client-side validation checks (empty name -> mismatch -> short pass)
    final registerSubmit = find.text('إنشاء حساب').last;
    await tester.ensureVisible(registerSubmit);
    await tester.tap(registerSubmit);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('يرجى إدخال اسمك الكامل'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'سارة أحمد');
    await tester.enterText(find.byType(TextField).at(1), 'sara@test.com');
    await tester.enterText(find.byType(TextField).at(2), 'Secret123!');
    await tester.enterText(find.byType(TextField).at(3), 'Mismatch!');
    await tester.ensureVisible(registerSubmit);
    await tester.tap(registerSubmit);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), '123');
    await tester.enterText(find.byType(TextField).at(3), '123');
    await tester.ensureVisible(registerSubmit);
    await tester.tap(registerSubmit);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('كلمة المرور قصيرة (على الأقل 6 أحرف)'), findsOneWidget);

    // 5. Valid registration transitions cleanly to PaymentScreen
    await tester.enterText(find.byType(TextField).at(2), 'Secret123!');
    await tester.enterText(find.byType(TextField).at(3), 'Secret123!');
    await tester.ensureVisible(registerSubmit);
    await tester.tap(registerSubmit);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(authService.registered, isTrue);
    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(find.text('اشتراك كورس كامل بلا حدود'), findsWidgets);

    // 6. Tapping Subscribe on non-mobile platform triggers official store guard snackbar
    final subscribeCta = find.textContaining('اشترك وابدأ رحلتك التعليمية');
    await tester.ensureVisible(subscribeCta);
    await tester.tap(subscribeCta);
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.text('الاشتراك متاح فقط عبر تطبيق iOS أو Android الرسمي'),
      findsOneWidget,
    );

    // 7. Logout clears provider state and returns cleanly to LoginScreen
    final logoutBtn = find.text('تسجيل الخروج');
    await tester.ensureVisible(logoutBtn);
    await tester.tap(logoutBtn);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

      expect(authService.loggedOut, isTrue);
      expect(appProvider.cleared, isTrue);
      expect(find.byType(LoginScreen), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
      'Student QuizScreen renders subject header and initial start state',
      (WidgetTester tester) async {
    final appProvider = FakeAppProvider();
    final authService = FakeAuthService();

    await tester.pumpWidget(
      _wrapWithProviders(
        appProvider,
        authService,
        const QuizScreen(
          subject: {'ar': 'الفيزياء', 'en': 'Physics', 'color': '7C3AED'},
          grade: 12,
          subjectId: 'phys_12',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('الفيزياء — اختبار قصير'), findsOneWidget);
    expect(find.text('ابدأ الاختبار'), findsOneWidget);
    expect(find.text('يتم توليد الأسئلة من ملفات المادة'), findsOneWidget);
  });

  testWidgets(
      'PaymentScreen Dark Mode renders with zero displayed prices and zero overflow',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final appProvider = FakeAppProvider(forceDark: true);
      final authService = FakeAuthService();

      await tester.pumpWidget(
        _wrapWithProviders(appProvider, authService, const PaymentScreen()),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.text('اشترك وابدأ رحلتك التعليمية 🎓'), findsOneWidget);
      expect(find.text('وصول شامل وفوري'), findsOneWidget);
      expect(find.text('دفع آمن ومحمي'), findsOneWidget);
      expect(find.textContaining('د.ك'), findsNothing);
      expect(find.textContaining('KWD'), findsNothing);
      expect(find.textContaining('12 '), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
      'SlideLessonScreen renders one unified explanation view without dual-version switcher',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channelName in const [
      'flutter_tts',
      'plugin.csdcorp.com/speech_to_text',
      'plugins.flutter.io/screen_protector',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channelName),
        (_) async => null,
      );
      addTearDown(
          () => messenger.setMockMethodCallHandler(MethodChannel(channelName), null));
    }

    final appProvider = FakeAppProvider(forceDark: true);
    final authService = FakeAuthService();
    const lesson = InteractiveLesson(
      pdfId: 'unit-lesson-1',
      title: 'درس الحركة والتسارع',
      subject: 'الفيزياء',
      versions: {
        InteractiveLesson.kamila: [
          LessonSlide(
            kind: SlideKind.welcome,
            heading: 'مقدمة الحركة',
            body: 'السرعة المتجهة والتسارع المنتظم',
            duration: 5.0,
          ),
        ],
        InteractiveLesson.mukhtasar: [
          LessonSlide(
            kind: SlideKind.zubda,
            heading: 'ملخص سريع',
            body: 'a = Δv / Δt',
            duration: 3.0,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      _wrapWithProviders(
        appProvider,
        authService,
        const SlideLessonScreen(
          pdfId: 'unit-lesson-1',
          title: 'درس الحركة والتسارع',
          initialLesson: lesson,
          autoStart: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('درس الحركة والتسارع'), findsOneWidget);
    expect(find.text('الشرح الكامل'), findsNothing);
    expect(find.text('الزبدة'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
