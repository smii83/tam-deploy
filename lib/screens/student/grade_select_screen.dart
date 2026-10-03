import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/app_provider.dart';
import '../../services/firestore_data_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_pressable.dart';
import 'payment_screen.dart';
import 'home_screen.dart';

/// شاشة اختيار الصف الدراسي
/// تجلب الصفوف من Firestore وتحترم is_visible
class GradeSelectScreen extends StatefulWidget {
  const GradeSelectScreen({super.key});
  @override
  State<GradeSelectScreen> createState() => _GradeSelectScreenState();
}

class _GradeSelectScreenState extends State<GradeSelectScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _grades = [];
  String? _selectedId;
  int? _selectedGradeNum;
  String? _selectedSection;
  bool _loading = true;
  bool _saving = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Emoji/color per grade_number
  static const Map<int, Map<String, dynamic>> _meta = {
    6: {'em': '🌱', 'color': 0xFF6C63FF, 'stage': 'ابتدائي'},
    7: {'em': '📘', 'color': 0xFF00B8A9, 'stage': 'متوسط'},
    8: {'em': '🔭', 'color': 0xFF8B5CF6, 'stage': 'متوسط'},
    9: {'em': '⚗️', 'color': 0xFF22C55E, 'stage': 'متوسط'},
    10: {'em': '🚀', 'color': 0xFFF59E0B, 'stage': 'ثانوي'},
    11: {'em': '🎯', 'color': 0xFFEF4444, 'stage': 'ثانوي'},
    12: {'em': '🏆', 'color': 0xFFFFBB00, 'stage': 'ثانوي'},
  };

  String _selectedCountryCode = 'kw';
  List<Map<String, dynamic>> _countries = [];

  @override
  void initState() {
    super.initState();
    _loadCountriesAndGrades();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCountriesAndGrades() async {
    setState(() => _loading = true);
    try {
      final p = context.read<AppProvider>();
      _selectedCountryCode = p.selectedCountry;
      final countryList = await FirestoreDataService.getCountries();
      final allGrades = await FirestoreDataService.getGrades(_selectedCountryCode);
      if (!mounted) return;
      setState(() {
        _countries = countryList;
        _grades = allGrades;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _grades = FirestoreDataService.getStaticGradesForCountry(_selectedCountryCode);
        _loading = false;
      });
    }
  }

  Future<void> _changeCountry(String code) async {
    setState(() {
      _selectedCountryCode = code;
      _selectedId = null;
      _selectedGradeNum = null;
      _selectedSection = null;
      _loading = true;
    });
    final p = context.read<AppProvider>();
    await p.setCountry(code);
    final allGrades = await FirestoreDataService.getGrades(code);
    if (!mounted) return;
    setState(() {
      _grades = allGrades;
      _loading = false;
    });
  }

  Future<void> _next() async {
    if (_selectedId == null) return;
    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _saving = false);
      return;
    }

    await FirestoreDataService.updateUserGrade(
      uid,
      _selectedGradeNum!,
      _selectedSection,
      _selectedCountryCode,
    );
    final subscribed = await FirestoreDataService.isSubscribed(uid);
    if (!mounted) return;
    setState(() => _saving = false);

    if (subscribed) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PaymentScreen()),
      );
    }
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

          Column(
            children: [
              // ── Custom Header ──────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF6C63FF),
                      Color(0xFF4F46E5),
                      Color(0xFF00B8A9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.asset(
                              'assets/images/logo_dark.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'اختر صفك الدراسي',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              Text(
                                _selectedCountryCode == 'sa'
                                    ? 'سنخصص لك المحتوى حسب المنهج السعودي'
                                    : _selectedCountryCode == 'ae'
                                        ? 'سنخصص لك المحتوى حسب المنهج الإماراتي'
                                        : 'سنخصص لك المحتوى حسب المنهج الكويتي',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Country Selector Bar (If multiple countries active in Backend) ──
              if (_countries.length > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _countries.map((c) {
                        final code = c['code'] as String;
                        final flag = c['flag'] as String;
                        final name = p.isAr ? (c['name_ar'] as String) : (c['name_en'] as String);
                        final active = _selectedCountryCode == code;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: () => _changeCountry(code),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppTheme.primary
                                    : (isDark ? const Color(0xFF181A24) : Colors.white),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: active ? AppTheme.primary : AppTheme.border,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(flag, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: active ? Colors.white : (isDark ? Colors.white70 : AppTheme.textPri),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],

              // ── Grades list ──────────────────────────────────────
              if (_loading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: RefreshIndicator(
                      onRefresh: _loadCountriesAndGrades,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        itemCount: _grades.length,
                        itemBuilder: (_, i) {
                          final g = _grades[i];
                          final gradeNum =
                              (g['grade_number'] as num).toInt();
                          final m = _meta[gradeNum] ??
                              {
                                'em': '📚',
                                'color': 0xFF6C63FF,
                                'stage': 'دراسي'
                              };
                          final gradeColor = Color(m['color'] as int);
                          final sel = _selectedId ==
                              (g['id'] ?? g['grade_number'].toString());

                          return AnimatedPressable(
                            onTap: () => setState(() {
                              _selectedId =
                                  g['id'] ?? g['grade_number'].toString();
                              _selectedGradeNum = gradeNum;
                              _selectedSection =
                                  (g['section'] as String?)?.isNotEmpty ==
                                          true
                                      ? g['section']
                                      : null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: sel
                                    ? (isDark
                                        ? gradeColor.withValues(alpha: 0.12)
                                        : gradeColor.withValues(alpha: 0.07))
                                    : (isDark
                                        ? const Color(0xFF181A24)
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: sel
                                      ? gradeColor.withValues(
                                          alpha: isDark ? 0.5 : 0.35)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : AppTheme.border),
                                  width: sel ? 2 : 1.5,
                                ),
                                boxShadow: sel
                                    ? [
                                        BoxShadow(
                                          color: gradeColor
                                              .withValues(alpha: 0.20),
                                          blurRadius: 16,
                                          offset: const Offset(0, 5),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                              ),
                              child: Row(
                                children: [
                                  // Emoji icon
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: gradeColor
                                          .withValues(alpha: isDark ? 0.15 : 0.10),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      border: Border.all(
                                        color: gradeColor.withValues(
                                            alpha: isDark ? 0.30 : 0.15),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        m['em'] as String,
                                        style:
                                            const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          g['name_ar'] ??
                                              g['name_en'] ??
                                              'صف $gradeNum',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Cairo',
                                            color: sel
                                                ? gradeColor
                                                : (isDark
                                                    ? Colors.white
                                                    : AppTheme.textPri),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: gradeColor.withValues(
                                                alpha:
                                                    isDark ? 0.15 : 0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'المرحلة ال${m['stage']}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.w600,
                                              color: gradeColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Selection indicator
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      gradient:
                                          sel ? AppTheme.primaryGrad : null,
                                      color: sel
                                          ? null
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: sel
                                            ? Colors.transparent
                                            : (isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.15)
                                                : AppTheme.border),
                                        width: 1.5,
                                      ),
                                      boxShadow: sel
                                          ? [
                                              BoxShadow(
                                                color: gradeColor
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset:
                                                    const Offset(0, 2),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: sel
                                        ? const Icon(Icons.check_rounded,
                                            color: Colors.white, size: 14)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              // ── CTA Button ────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 12,
                ),
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : AnimatedOpacity(
                        opacity: _selectedId != null ? 1.0 : 0.5,
                        duration: const Duration(milliseconds: 300),
                        child: AnimatedPressable(
                          onTap: _selectedId != null ? _next : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: _selectedId != null
                                  ? AppTheme.gradientFor(p.themeId)
                                  : const LinearGradient(colors: [
                                      Color(0xFFB0B0C0),
                                      Color(0xFF9090A0)
                                    ]),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'التالي',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_back_rounded,
                                      color: Colors.white, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
