import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_urls.dart';
import '../../widgets/animated_pressable.dart';
import '../../widgets/tam_logo_widget.dart';
import '../student/payment_screen.dart';
import '../../services/firestore_data_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _confCtrl  = TextEditingController();
  bool _loading = false, _obscure = true;
  int _grade = 12;
  String _section = 'scientific'; // default section
  String _country = 'kw'; // default country: 'kw', 'sa', 'ae'
  String? _error;
  List<Map<String, dynamic>> _gradesList = [];
  List<Map<String, dynamic>> _countriesList = [];

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _loadGrades(_country);
  }

  Future<void> _loadCountries() async {
    try {
      final list = await FirestoreDataService.getCountries();
      if (mounted) {
        setState(() {
          _countriesList = list;
          if (_countriesList.isNotEmpty && !_countriesList.any((c) => c['code'] == _country)) {
            _country = _countriesList.first['code'] as String? ?? 'kw';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGrades(String countryCode) async {
    try {
      final list = await FirestoreDataService.getGrades(countryCode);
      if (list.isNotEmpty && mounted) {
        setState(() {
          _gradesList = list;
          
          final currentVal = '$_grade${_section.isNotEmpty ? '_$_section' : ''}';
          final isValid = _gradesList.any((g) {
            final sec = g['section'] as String? ?? '';
            final numVal = (g['grade_number'] as num).toInt();
            final val = sec.isNotEmpty ? '${numVal}_$sec' : '$numVal';
            return val == currentVal;
          });

          if (!isValid) {
            final firstG = _gradesList.first;
            _grade = (firstG['grade_number'] as num).toInt();
            _section = firstG['section'] as String? ?? '';
          }
        });
      }
    } catch (e) {
      // Error is caught silently, UI uses fallback values
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) { setState(() => _error = 'يرجى إدخال اسمك الكامل'); return; }
    if (_passCtrl.text != _confCtrl.text) { setState(() => _error = 'كلمتا المرور غير متطابقتين'); return; }
    if (_passCtrl.text.length < 6) { setState(() => _error = 'كلمة المرور قصيرة'); return; }
    setState(() { _loading = true; _error = null; });
    final err = await context.read<AuthService>().register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      grade: _grade,
      section: (_section.isNotEmpty) ? _section : null,
      country: _country,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      final data = await context.read<AuthService>().getUserData();
      if (mounted) {
        final p = context.read<AppProvider>();
        p.userData = data;
        await p.setCountry(_country);
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const PaymentScreen()));
      }
    }
  }

  Widget _langToggle(AppProvider p) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
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
    return GestureDetector(
      onTap: () => p.setLanguage(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active 
            ? (p.isDark ? Colors.white : AppTheme.primary) 
            : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active ? [
            BoxShadow(
              color: (p.isDark ? Colors.white : AppTheme.primary).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active 
              ? (p.isDark ? Colors.black : Colors.white) 
              : (p.isDark ? Colors.white54 : Colors.black54),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isDark = p.isDark;

    return Scaffold(
      body: Stack(
        children: [
          // Background solid color
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F111A) : const Color(0xFFEEEDFF),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Top row: back + lang toggle
                Row(
                  children: [
                    AnimatedPressable(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Icon(
                          p.isAr
                              ? Icons.arrow_forward_rounded
                              : Icons.arrow_back_rounded,
                          size: 18,
                          color: isDark ? Colors.white : AppTheme.textPri,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _langToggle(p),
                  ],
                ),
                const SizedBox(height: 24),

                // Logo
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: isDark ? 0.18 : 0.12),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: isDark ? 0.15 : 0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const TamLogoWidget(size: 60),
                      ),
                      const SizedBox(height: 12),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.auroraGrad.createShader(bounds),
                        child: Text(
                          p.register,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF181A24)
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: isDark ? 0.12 : 0.08),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Animated error
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(
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
                          ? Container(
                              key: ValueKey(_error),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.18)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      color: Colors.red.withValues(alpha: 0.8),
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Cairo')),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    _buildField(p.name, Icons.person_outline, _nameCtrl),
                    const SizedBox(height: 12),
                    _buildField(p.email, Icons.email_outlined, _emailCtrl,
                        keyboard: TextInputType.emailAddress,
                        isLtr: true),
                    const SizedBox(height: 12),
                    _buildPasswordField(p.password, _passCtrl),
                    const SizedBox(height: 12),
                    _buildPasswordField(p.confirmPwd, _confCtrl),
                    const SizedBox(height: 16),
                    // ── Country Selector Dropdown ─────────────────────────
                    _buildCountryDropdown(p, isDark),
                    const SizedBox(height: 12),
                    // ── Grade Selector Dropdown ───────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF7F5FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              AppTheme.accent.withValues(alpha: isDark ? 0.15 : 0.10),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:
                              '$_grade${_section.isNotEmpty ? '_$_section' : ''}',
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.accent),
                          dropdownColor: isDark
                              ? const Color(0xFF1E1E2C)
                              : Colors.white,
                          items: _buildGradeItems(p),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              if (v.contains('_')) {
                                final parts = v.split('_');
                                _grade = int.parse(parts[0]);
                                _section = parts[1];
                              } else {
                                _grade = int.parse(v);
                                _section = '';
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.accent))
                        : AnimatedPressable(
                            onTap: _register,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                gradient: AppTheme.auroraGrad,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accent
                                        .withValues(alpha: 0.30),
                                    blurRadius: 16,
                                    spreadRadius: -4,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  p.register,
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
                        const SizedBox(height: 16),
                        // ── Terms & Privacy agreement (Apple Guideline 5.1.1) ─
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              p.isAr
                                  ? 'بالتسجيل، أنت توافق على '
                                  : 'By registering, you agree to our ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSec,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(AppUrls.termsOfUse);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(
                                p.isAr ? 'شروط الاستخدام' : 'Terms of Use',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                            Text(
                              p.isAr ? ' و ' : ' and ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSec,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(AppUrls.privacyPolicy);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(
                                p.isAr ? 'سياسة الخصوصية' : 'Privacy Policy',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                          ],
                        ),
                  ]),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String hint,
    IconData icon,
    TextEditingController ctrl, {
    TextInputType? keyboard,
    bool isLtr = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      textDirection: isLtr ? TextDirection.ltr : null,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18,
            color: AppTheme.accent.withValues(alpha: 0.7)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF7F5FF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: AppTheme.accent.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: AppTheme.accent.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppTheme.accent, width: 1.8),
        ),
      ),
    );
  }

  Widget _buildPasswordField(String hint, TextEditingController ctrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      obscureText: _obscure,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.lock_outline, size: 18,
            color: AppTheme.accent.withValues(alpha: 0.7)),
        suffixIcon: IconButton(
          icon: Icon(
              _obscure ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: AppTheme.textSec),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF7F5FF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: AppTheme.accent.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: AppTheme.accent.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppTheme.accent, width: 1.8),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildGradeItems(AppProvider p) {
    if (_gradesList.isEmpty) {
      List<DropdownMenuItem<String>> items = [];
      for (int g = 6; g <= 9; g++) {
        items.add(DropdownMenuItem(value: '$g', child: Text('الصف $g', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))));
      }
      items.add(DropdownMenuItem(value: '10', child: Text('الصف العاشر (عام)', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))));
      items.add(DropdownMenuItem(value: '10_tracks', child: Text('الصف العاشر — نظام المسارات (2026)', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))));
      items.add(DropdownMenuItem(value: '11_scientific', child: Text('الصف 11 علمي', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))));
      items.add(DropdownMenuItem(value: '11_literary', child: Text('الصف 11 أدبي', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))));
      items.add(DropdownMenuItem(value: '12_scientific', child: Text('الصف 12 علمي', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))));
      items.add(DropdownMenuItem(value: '12_literary', child: Text('الصف 12 أدبي', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))));
      return items;
    }

    return _gradesList.map((g) {
      final sec = g['section'] as String? ?? '';
      final numVal = (g['grade_number'] as num).toInt();
      final val = sec.isNotEmpty ? '${numVal}_$sec' : '$numVal';
      final name = p.isAr ? (g['name_ar'] as String? ?? '') : (g['name_en'] as String? ?? '');
      return DropdownMenuItem<String>(
        value: val,
        child: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
      );
    }).toList();
  }

  Widget _buildCountryDropdown(AppProvider p, bool isDark) {
    final countries = _countriesList.isNotEmpty
        ? _countriesList
        : FirestoreDataService.GCC_COUNTRIES.where((c) => c['is_visible'] == true).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF7F5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: isDark ? 0.15 : 0.10),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _country,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.accent),
          dropdownColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          items: countries.map((c) {
            final code = c['code'] as String;
            final flag = c['flag'] as String;
            final name = p.isAr ? (c['name_ar'] as String) : (c['name_en'] as String);
            return DropdownMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _country = val;
            });
            _loadGrades(val);
          },
        ),
      ),
    );
  }
}

