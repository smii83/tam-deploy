import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_pressable.dart';
import '../../widgets/tam_logo_widget.dart';
import 'register_screen.dart';
import '../../services/firestore_data_service.dart';

import '../student/home_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? errorMsg;
  const LoginScreen({super.key, this.errorMsg});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;
  bool _resetLoading = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    if (widget.errorMsg != null) {
      _error = widget.errorMsg;
    }
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// Shows a dialog to enter email and sends a password reset link.
  Future<void> _forgotPassword() async {
    final p = context.read<AppProvider>();
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            p.forgotPassword,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.isAr
                    ? 'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة تعيين كلمة المرور.'
                    : 'Enter your email and we will send you a password reset link.',
                style: TextStyle(fontSize: 12, fontFamily: 'Cairo', color: AppTheme.textSec),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: p.email,
                  prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppTheme.primary.withValues(alpha: 0.7)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              if (_resetLoading) const Padding(
                padding: EdgeInsets.only(top: 12),
                child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(p.cancel, style: const TextStyle(fontFamily: 'Cairo', color: AppTheme.textSec)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty) return;
                setD(() => _resetLoading = true);
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(p.resetPasswordSent,
                          style: const TextStyle(fontFamily: 'Cairo')),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ));
                  }
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(
                      p.isAr ? 'تعذّر إرسال الرابط. تأكد من البريد الإلكتروني.' : 'Failed to send link. Check your email.',
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                    backgroundColor: Colors.red,
                  ));
                } finally {
                  if (mounted) setD(() => _resetLoading = false);
                }
              },
              child: Text(p.resetPassword,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await context
        .read<AuthService>()
        .login(email: _emailCtrl.text, password: _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      _toHome();
    }
  }

  Future<void> _apple() async {
    setState(() => _error = null);
    // Show grade picker BEFORE setting _loading, so the dialog is not
    // obscured by the spinner — and _loading stays false if user cancels.
    final gradeInfo = await _pickGradeIfNeeded();
    if (!mounted) return;
    setState(() => _loading = true);
    final err = await context.read<AuthService>().signInWithApple(
      grade: gradeInfo.$1,
      section: gradeInfo.$2,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      _toHome();
    }
  }

  Future<void> _google() async {
    setState(() => _error = null);
    // Show grade picker BEFORE setting _loading, so the dialog is not
    // obscured by the spinner — and _loading stays false if user cancels.
    final gradeInfo = await _pickGradeIfNeeded();
    if (!mounted) return;
    setState(() => _loading = true);
    final err = await context.read<AuthService>().signInWithGoogle(
      grade: gradeInfo.$1,
      section: gradeInfo.$2,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      _toHome();
    }
  }

  /// Shows a dialog to pick grade before social sign in.
  /// Returns (grade, section) aligned with the user's country & high school phase.
  Future<(int, String)> _pickGradeIfNeeded() async {
    final p = context.read<AppProvider>();
    final country = p.selectedCountry;
    final gradesList = FirestoreDataService.getStaticGradesForCountry(country);
    
    int selectedGrade = (gradesList.first['grade_number'] as num).toInt();
    String selectedSection = gradesList.first['section'] as String? ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('اختر صفك الدراسي',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('حتى نتمكن من تخصيص المحتوى لك 🎓',
                  style: TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.grey)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: '$selectedGrade${selectedSection.isNotEmpty ? '_$selectedSection' : ''}',
                decoration: InputDecoration(
                  labelText: 'الصف الدراسي',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                isExpanded: true,
                items: gradesList.map((g) {
                  final numVal = (g['grade_number'] as num).toInt();
                  final sec = g['section'] as String? ?? '';
                  final val = sec.isNotEmpty ? '${numVal}_$sec' : '$numVal';
                  final name = p.isAr ? (g['name_ar'] as String) : (g['name_en'] as String);
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setD(() {
                    if (v.contains('_')) {
                      final parts = v.split('_');
                      selectedGrade = int.parse(parts[0]);
                      selectedSection = parts[1];
                    } else {
                      selectedGrade = int.parse(v);
                      selectedSection = '';
                    }
                  });
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('تأكيد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    return (selectedGrade, selectedSection);
  }

  void _toHome() async {
    final data = await context.read<AuthService>().getUserData();
    if (mounted) {
      if (data != null && data['is_blocked'] == true) {
        await context.read<AuthService>().logout();
        setState(() => _error = 'لقد تم حظر هذا الحساب من قبل الإدارة.');
        return;
      }
      context.read<AppProvider>().userData = data;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isDark = p.isDark;
    return Scaffold(
      body: Stack(
        children: [
          // ── Background solid color ──────────────────────────────────────
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F111A) : const Color(0xFFEEEDFF),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Language toggle
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _langToggle(p),
                      ),
                      const SizedBox(height: 28),

                      // ── Logo Hero Section ──────────────────────────
                      Center(
                        child: Column(
                          children: [
                            // Logo with glow
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: AppTheme.primary.withValues(
                                      alpha: isDark ? 0.18 : 0.12),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary
                                        .withValues(alpha: isDark ? 0.20 : 0.12),
                                    blurRadius: 28,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const TamLogoWidget(size: 70),
                            ),
                            const SizedBox(height: 14),
                            // Platform name
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppTheme.gradientFor(p.themeId).createShader(bounds),
                              child: const Text(
                                'منصة تـم التعليمية',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.isAr
                                  ? 'تعلّم بذكاء — كل ما تحتاجه في مكان واحد'
                                  : 'Learn smart — everything in one place',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: AppTheme.textSec
                                    .withValues(alpha: isDark ? 0.7 : 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Login Card ────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF181A24)
                              : Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppTheme.primaryFor(p.themeId)
                                .withValues(alpha: isDark ? 0.25 : 0.12),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.25 : 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: AppTheme.primary
                                  .withValues(alpha: isDark ? 0.08 : 0.04),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card header
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGrad,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.login_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  p.login,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Cairo',
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textPri,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Error box with animation
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, -0.3),
                                    end: Offset.zero,
                                  ).animate(anim),
                                  child: child,
                                ),
                              ),
                              child: _error != null
                                  ? _errorBox(_error!)
                                  : const SizedBox.shrink(),
                            ),

                            // Email field
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                hintText: p.email,
                                prefixIcon: Icon(Icons.email_outlined,
                                    size: 18,
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.7)),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF7F5FF),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: AppTheme.primary, width: 1.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Password field
                            TextField(
                              controller: _passCtrl,
                              obscureText: _obscure,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                hintText: p.password,
                                prefixIcon: Icon(Icons.lock_outline,
                                    size: 18,
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.7)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 18,
                                      color: AppTheme.textSec),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF7F5FF),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: AppTheme.primary, width: 1.8),
                                ),
                              ),
                              onSubmitted: (_) => _login(),
                            ),
                            // Forgot password link
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AnimatedPressable(
                                onTap: _forgotPassword,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: ShaderMask(
                                    shaderCallback: (b) => AppTheme.gradientFor(p.themeId).createShader(b),
                                    child: Text(
                                      p.forgotPassword,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Login button
                            _loading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primary,
                                    ))
                                : AnimatedPressable(
                                    onTap: _login,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 15),
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.gradientFor(p.themeId),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Text(
                                          p.login,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      _divider(p),
                      const SizedBox(height: 20),
                      _appleBtn(p),
                      const SizedBox(height: 10),
                      _googleBtn(p),
                      const SizedBox(height: 28),

                      // Register link
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              p.isAr
                                  ? 'ليس لديك حساب؟ '
                                  : "Don't have an account? ",
                              style: TextStyle(
                                  color: AppTheme.textSec, fontSize: 13),
                            ),
                            AnimatedPressable(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const RegisterScreen())),
                              child: ShaderMask(
                                shaderCallback: (bounds) =>
                                    AppTheme.primaryGrad.createShader(bounds),
                                child: Text(
                                  p.register,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ]),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        key: ValueKey(msg),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.red.withValues(alpha: 0.8), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      );

  Widget _divider(AppProvider p) => Row(children: [
        Expanded(
            child: Divider(
                color: AppTheme.border.withValues(alpha: 0.6), thickness: 1)),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(p.isAr ? 'أو' : 'OR',
                style: TextStyle(
                    color: AppTheme.textSec.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.bold))),
        Expanded(
            child: Divider(
                color: AppTheme.border.withValues(alpha: 0.6), thickness: 1)),
      ]);

  Widget _langToggle(AppProvider p) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: p.isDark ? 0.12 : 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langBtn('en', 'EN', p),
          _langBtn('ar', 'ع', p),
        ],
      ),
    );
  }

  Widget _langBtn(String code, String label, AppProvider p) {
    final active = p.language == code;
    return AnimatedPressable(
      onTap: () => p.setLanguage(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? AppTheme.primaryGrad : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : (p.isDark ? Colors.white54 : Colors.black54),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }

  Widget _appleBtn(AppProvider p) => AnimatedPressable(
        onTap: _apple,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: p.isDark ? const Color(0xFF1C1C28) : Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: p.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.isAr ? 'متابعة مع' : 'Continue with',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10,
                        fontFamily: 'Cairo',
                        height: 1.1)),
                const Text('Apple',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2)),
              ],
            ),
            const SizedBox(width: 14),
            const Icon(Icons.apple, color: Colors.white, size: 26),
          ]),
        ),
      );

  Widget _googleBtn(AppProvider p) => AnimatedPressable(
        onTap: _google,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: p.isDark ? const Color(0xFF1C1C28) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: p.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppTheme.border,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.isAr ? 'متابعة مع' : 'Continue with',
                    style: TextStyle(
                        color: p.isDark ? Colors.white60 : Colors.black54,
                        fontSize: 10,
                        fontFamily: 'Cairo',
                        height: 1.1)),
                Text('Google',
                    style: TextStyle(
                        color: p.isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2)),
              ],
            ),
            const SizedBox(width: 14),
            _googleLogo(),
          ]),
        ),
      );

  Widget _googleLogo() => SizedBox(
        width: 24,
        height: 24,
        child: CustomPaint(painter: _GoogleLogoPainter()),
      );
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double scale = s / 100;
    final Matrix4 matrix = Matrix4.identity()
      ..scaleByDouble(scale, scale, 1.0, 1.0);
    final m = matrix.storage;

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // 1. Blue (Right & Bar)
    paint.color = const Color(0xFF4285F4);
    final Path bluePath = Path()
      ..moveTo(98.9, 51.5)
      ..cubicTo(98.9, 48, 98.6, 44.4, 98, 41)
      ..lineTo(50.5, 41)
      ..lineTo(50.5, 60.9)
      ..lineTo(77.6, 60.9)
      ..cubicTo(76.4, 67.2, 72.9, 72.5, 67.6, 76.7)
      ..lineTo(83.8, 89.3)
      ..cubicTo(93.3, 80.3, 98.9, 67.2, 98.9, 51.5)
      ..close();
    canvas.drawPath(bluePath.transform(m), paint);

    // 2. Green (Bottom)
    paint.color = const Color(0xFF34A853);
    final Path greenPath = Path()
      ..moveTo(50.5, 101)
      ..cubicTo(64.1, 101, 75.6, 96.5, 83.9, 88.8)
      ..lineTo(67.7, 76.2)
      ..cubicTo(63.1, 79.3, 57.2, 81.1, 50.5, 81.1)
      ..cubicTo(37.3, 81.1, 26.1, 72.2, 22.1, 60.2)
      ..lineTo(5.3, 73.2)
      ..cubicTo(13.9, 91, 30.5, 101, 50.5, 101)
      ..close();
    canvas.drawPath(greenPath.transform(m), paint);

    // 3. Yellow (Left)
    paint.color = const Color(0xFFFBBC05);
    final Path yellowPath = Path()
      ..moveTo(22.1, 60.2)
      ..cubicTo(21, 57.1, 20.4, 53.7, 20.4, 50.2)
      ..cubicTo(20.4, 46.7, 21, 43.3, 22.1, 40.2)
      ..lineTo(5.3, 27.2)
      ..cubicTo(1.9, 33.8, 0, 41.7, 0, 50.2)
      ..cubicTo(0, 58.7, 1.9, 66.6, 5.3, 73.2)
      ..lineTo(22.1, 60.2)
      ..close();
    canvas.drawPath(yellowPath.transform(m), paint);

    // 4. Red (Top)
    paint.color = const Color(0xFFEA4335);
    final Path redPath = Path()
      ..moveTo(50.5, 19.3)
      ..cubicTo(57.9, 19.3, 64.5, 21.8, 69.8, 26.9)
      ..lineTo(84.4, 12.3)
      ..cubicTo(74.6, 3.2, 64, 0, 50.5, 0)
      ..cubicTo(31, 0, 13.9, 11.2, 5.3, 27.2)
      ..lineTo(22.1, 40.2)
      ..cubicTo(26.1, 28.2, 37.3, 19.3, 50.5, 19.3)
      ..close();
    canvas.drawPath(redPath.transform(m), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
