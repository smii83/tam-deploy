import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_provider.dart';
import '../../services/firestore_data_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_pressable.dart';
import '../../widgets/home_welcome_card.dart';
import '../../widgets/home_widgets.dart';
import 'subject_screen.dart';
import 'lessons_screen.dart';
import 'pdfs_screen.dart';
import '../settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _searchActive = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Global search results
  List<Map<String, dynamic>> _lessonResults = [];
  List<Map<String, dynamic>> _pdfResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Debounced search — fires 450ms after the user stops typing.
  void _onSearchChanged(String q) {
    setState(() => _searchQuery = q);
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _lessonResults = [];
        _pdfResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final results = await Future.wait([
          FirestoreDataService.searchLessons(q.trim()),
          FirestoreDataService.searchPDFs(q.trim()),
        ]);
        if (!mounted) return;
        setState(() {
          _lessonResults = results[0];
          _pdfResults = results[1];
          _isSearching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final userData = p.userData ?? {};

    // Prefer: Firestore name → SharedPreferences cached name → Firebase displayName → empty (shows skeleton)
    final pbName = (userData['name'] as String?)?.trim() ?? '';
    final fbName = p.cachedName.isNotEmpty
        ? p.cachedName
        : (FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '');
    final name = pbName.isNotEmpty ? pbName : fbName;

    final grade = userData['grade'] ?? 12;
    final section = userData['section'] ?? 'scientific';
    final country = (userData['country'] as String?) ?? p.selectedCountry;

    final allSubjects =
        p.curriculumSubjects ?? AppProvider.getSubjects(grade, section, country);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ── Animated gradient background ────────────────────────────
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: AppTheme.bgGradientFor(p.themeId, p.isDark),
              ),
            ),
          ),
          _tab == 0
              ? _buildHome(p, allSubjects, name, grade, section)
              : const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildNav(p),
    );
  }

  Widget _buildHome(
    AppProvider p,
    List<Map<String, String>> allSubjects,
    String name,
    int grade, [
    String section = '',
  ]) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _buildWelcomeCard(p, name),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 18),
              // ── Section header + Search toggle ─────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryFor(p.themeId),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        p.subjects,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Grade badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            p.isDark ? const Color(0xFF1E1E2C) : Colors.white,
                            AppTheme.primaryFor(p.themeId),
                            p.isDark ? 0.25 : 0.10,
                          )!,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.primaryFor(p.themeId)
                                .withValues(alpha: p.isDark ? 0.35 : 0.18),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🎓', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              section == 'tracks'
                                  ? (p.isAr ? 'عاشر • مسارات' : 'Grade 10 • Tracks')
                                  : section == 'scientific'
                                      ? (p.isAr ? 'الصف $grade • علمي' : 'Grade $grade • Sci')
                                      : section == 'literary'
                                          ? (p.isAr ? 'الصف $grade • أدبي' : 'Grade $grade • Lit')
                                          : (p.isAr ? 'الصف $grade' : 'Grade $grade'),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryFor(p.themeId),
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Search icon button
                      AnimatedPressable(
                        onTap: () => setState(() {
                          _searchActive = !_searchActive;
                          if (!_searchActive) {
                            _searchCtrl.clear();
                            _searchQuery = '';
                          }
                        }),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _searchActive
                                ? AppTheme.primaryFor(p.themeId).withValues(alpha: 0.18)
                                : (p.isDark
                                    ? Colors.white.withValues(alpha: 0.07)
                                    : AppTheme.primaryFor(p.themeId).withValues(alpha: 0.08)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryFor(p.themeId).withValues(
                                  alpha: _searchActive
                                      ? 0.50
                                      : (p.isDark ? 0.35 : 0.22)),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            _searchActive
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                            size: 18,
                            color: AppTheme.primaryFor(p.themeId),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Search bar (animated) ───────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _searchActive
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: p.isDark
                                ? const Color(0xFF1E1E2C)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryFor(p.themeId)
                                  .withValues(alpha: p.isDark ? 0.30 : 0.20),
                              width: 1.2,
                            ),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            textAlign:
                                p.isAr ? TextAlign.right : TextAlign.left,
                            onChanged: _onSearchChanged,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              color: p.isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                            ),
                            decoration: InputDecoration(
                              hintText: p.isAr
                                  ? 'ابحث عن درس أو ملف...'
                                  : 'Search lessons or files...',
                              hintStyle: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color:
                                    p.isDark ? Colors.white38 : Colors.black26,
                              ),
                              prefixIcon: _isSearching
                                  ? Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primaryFor(p.themeId),
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.search_rounded,
                                      color: AppTheme.primaryFor(p.themeId)
                                          .withValues(alpha: 0.7),
                                      size: 20,
                                    ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 20),

              // ── Search results OR subjects grid ────────────────────────
              if (_searchActive && _searchQuery.trim().length >= 2)
                _buildSearchResults(p, allSubjects, grade)
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = AppTheme.gridColsFor(p.themeId, constraints.maxWidth);
                    final aspect = AppTheme.gridAspectFor(p.themeId);
                    final spacing = p.themeId == AppThemeId.sakuraDream ? 14.0
                        : p.themeId == AppThemeId.winFlux ? 8.0 : 12.0;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        childAspectRatio: aspect,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                      ),
                      itemCount: allSubjects.length,
                      itemBuilder: (_, i) => _subjectCard(allSubjects[i], p, i),
                    );
                  },
                ),
              const SizedBox(height: 120),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Build inline search results ──────────────────────────────────────────
  Widget _buildSearchResults(
      AppProvider p, List<Map<String, String>> allSubjects, int grade) {
    final isDark = p.isDark;
    final bool noResults = _lessonResults.isEmpty && _pdfResults.isEmpty;

    // Nothing typed or still waiting for first char
    if (_isSearching && noResults) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (noResults) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Text('🔍', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              p.isAr
                  ? 'لا توجد نتائج لـ "$_searchQuery"'
                  : 'No results for "$_searchQuery"',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    /// Find a subject map by its Firestore subject_id
    Map<String, String>? subjectById(String subjectId) {
      try {
        return allSubjects.firstWhere((s) => s['id'] == subjectId);
      } catch (_) {
        return null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Lessons section ───────────────────────────────────────────────────────
        if (_lessonResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  p.isAr
                      ? 'دروس (${_lessonResults.length})'
                      : 'Lessons (${_lessonResults.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          ...(_lessonResults.map((lesson) {
            final subjectId = lesson['subject_id'] as String? ?? '';
            final subject = subjectById(subjectId);
            final subjectName = subject != null
                ? (p.isAr ? subject['ar']! : subject['en']!)
                : '';
            return _searchResultTile(
              icon: '🎦',
              iconColor: const Color(0xFF7B7FD9),
              title: lesson['name'] as String? ?? '',
              subtitle: subjectName,
              badge: p.isAr ? 'درس' : 'Lesson',
              badgeColor: const Color(0xFF7B7FD9),
              isDark: isDark,
              onTap: subject != null
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonsScreen(
                            subjectId: subjectId,
                            subject: subject,
                            grade: grade,
                          ),
                        ),
                      )
                  : null,
            );
          })),
          const SizedBox(height: 16),
        ],

        // ── PDFs section ──────────────────────────────────────────────────────────
        if (_pdfResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE87FA8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  p.isAr
                      ? 'ملفات PDF (${_pdfResults.length})'
                      : 'PDF Files (${_pdfResults.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          ...(_pdfResults.map((pdf) {
            final subjectId = pdf['subject_id'] as String? ?? '';
            final subject = subjectById(subjectId);
            final subjectName = subject != null
                ? (p.isAr ? subject['ar']! : subject['en']!)
                : '';
            final pdfType = pdf['pdf_type'] as String? ?? '';
            final typeLabel = pdfType == 'summary'
                ? (p.isAr ? 'ملخص' : 'Summary')
                : pdfType == 'exam_answer'
                    ? (p.isAr ? 'أجوبة امتحانات' : 'Exam Answers')
                    : (p.isAr ? 'ملف' : 'File');
            return _searchResultTile(
              icon: '📄',
              iconColor: const Color(0xFFE87FA8),
              title: pdf['name'] as String? ?? '',
              subtitle: subjectName,
              badge: typeLabel,
              badgeColor: const Color(0xFFE87FA8),
              isDark: isDark,
              onTap: subject != null
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PDFsScreen(
                            subjectId: subjectId,
                            subject: subject,
                            grade: grade,
                          ),
                        ),
                      )
                  : null,
            );
          })),
        ],
      ],
    );
  }

  Widget _searchResultTile({
    required String icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return SearchResultTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      badge: badge,
      badgeColor: badgeColor,
      isDark: isDark,
      onTap: onTap,
    );
  }

  Widget _buildWelcomeCard(AppProvider p, String name) {
    return HomeWelcomeCard(
      p: p,
      name: name,
      onAvatarTap: () => setState(() => _tab = 1),
    );
  }

  /// Delegates to the extracted [SubjectCard] widget
  Widget _subjectCard(Map<String, String> subject, AppProvider p, int index) {
    return SubjectCard(
      subject: subject,
      p: p,
      index: index,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubjectScreen(
            subject: subject,
            grade: (p.userData?['grade'] ?? 12),
          ),
        ),
      ),
    );
  }






  Widget _buildNav(AppProvider p) {
    final themeId = p.themeId;
    final isDark = p.isDark;
    final primary = AppTheme.primaryFor(themeId);

    // 🪟 Win Flux — شريط مستطيل Windows 11 style
    if (themeId == AppThemeId.winFlux) {
      return SizedBox(
        height: 72,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 56,
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2C2C2C).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Row(
                  children: [
                    Expanded(child: _navItemWin(0, Icons.grid_view_rounded, Icons.grid_view_outlined, p.home, p)),
                    Expanded(child: _navItemWin(1, Icons.person_rounded, Icons.person_outline_rounded, p.settings, p)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 🌸 Sakura Dream — pill وردي مع sparkle ✨
    if (themeId == AppThemeId.sakuraDream) {
      return SizedBox(
        height: 90,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 62,
            width: 230,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF3D0A50).withValues(alpha: 0.94),
                        const Color(0xFF1A0522).withValues(alpha: 0.94),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        const Color(0xFFFFF0F8).withValues(alpha: 0.95),
                      ],
                    ),
              borderRadius: BorderRadius.circular(31),
              border: Border.all(
                color: primary.withValues(alpha: isDark ? 0.50 : 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(31),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Row(
                  children: [
                    Expanded(child: _navItem(0, Icons.auto_awesome_rounded, Icons.auto_awesome_outlined, p.home, p)),
                    Expanded(child: _navItem(1, Icons.person_rounded, Icons.person_outline_rounded, p.settings, p)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 🌌 Deep Space / 🔷 TAM Indigo / 🧊 Arctic Glass — pill عادي
    return SizedBox(
      height: 90,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 62,
          width: 220,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.navDarkBgFor(themeId).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(31),
            border: Border.all(
              color: isDark
                  ? primary.withValues(alpha: 0.30)
                  : primary.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(31),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Row(
                children: [
                  Expanded(child: _navItem(0, Icons.auto_awesome_mosaic_rounded, Icons.auto_awesome_mosaic_outlined, p.home, p)),
                  Expanded(child: _navItem(1, Icons.person_rounded, Icons.person_outline_rounded, p.settings, p)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Win Flux nav item — flat Windows style
  Widget _navItemWin(int i, IconData activeIcon, IconData inactiveIcon, String label, AppProvider p) {
    final active = _tab == i;
    final primary = AppTheme.primaryFor(p.themeId);
    return AnimatedPressable(
      onTap: () => setState(() => _tab = i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: active ? primary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              active ? activeIcon : inactiveIcon,
              size: 22,
              color: active ? primary : AppTheme.textSec.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'Cairo',
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? primary : AppTheme.textSec.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    int i,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    AppProvider p,
  ) {
    final active = _tab == i;
    final icon = active ? activeIcon : inactiveIcon;

    return AnimatedPressable(
      onTap: () => setState(() => _tab = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: active ? 54 : 44,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? AppTheme.gradientFor(p.themeId) : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          boxShadow: active
              ? [
                  BoxShadow(
                    color:
                        AppTheme.primaryFor(p.themeId).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            icon,
            key: ValueKey(active),
            color: active
                ? Colors.white
                : AppTheme.textSec.withValues(alpha: 0.40),
            size: active ? 22 : 20,
          ),
        ),
      ),
    );
  }
}
