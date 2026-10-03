import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/app_provider.dart';
import '../../services/firestore_data_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_pressable.dart';
import '../../widgets/skeleton_loader.dart';
import 'video_player_screen.dart';

class LessonsScreen extends StatefulWidget {
  /// The Firestore subject record id
  final String subjectId;

  /// Display info map (ar, en, color, em, …)
  final Map<String, String> subject;
  final int grade;
  const LessonsScreen({
    super.key,
    required this.subjectId,
    required this.subject,
    required this.grade,
  });

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  List<Map<String, dynamic>> _lessons = [];
  Set<String> _completed = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final results = await Future.wait([
        FirestoreDataService.getLessons(widget.subjectId),
        if (uid.isNotEmpty) FirestoreDataService.getCompletedLessons(uid),
      ]);
      if (!mounted) return;
      setState(() {
        _lessons = results[0] as List<Map<String, dynamic>>;
        _completed = uid.isNotEmpty ? results[1] as Set<String> : <String>{};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markComplete(String lessonId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirestoreDataService.markLessonComplete(uid, lessonId);
    if (!mounted) return;
    setState(() => _completed.add(lessonId));
  }

  Color _toCalmColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 1.1).clamp(0.75, 0.90))
        .withLightness((hsl.lightness * 0.9).clamp(0.50, 0.60))
        .toColor();
  }

  /// Returns true if the lesson was added within the last 7 days
  bool _isNew(Map<String, dynamic> lesson) {
    try {
      final createdStr = lesson['created'] as String?;
      if (createdStr == null) return false;
      final created = DateTime.tryParse(createdStr);
      if (created == null) return false;
      return DateTime.now().difference(created).inDays < 7;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final name = p.isAr ? widget.subject['ar']! : widget.subject['en']!;
    final rawColor = AppTheme.parseColor(widget.subject["color"]);
    final color = p.themeId == AppThemeId.deepSpace
        ? _toCalmColor(rawColor)
        : AppTheme.primaryFor(p.themeId);

    // Lesson header decoration for Win Flux: flat Windows style
    // Sakura Dream: bubbly pink header
    // Others: existing gradient

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.bgGradientFor(p.themeId, p.isDark),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: _buildHeader(p, name, color),
              ),
            ),
            // Breadcrumb
            SliverToBoxAdapter(
              child: _buildBreadcrumb(p, name),
            ),
            ..._buildSlivers(p, color),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(AppProvider p, String subjectName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Icon(Icons.home_rounded, size: 12, color: AppTheme.textSec.withValues(alpha: 0.55)),
          const SizedBox(width: 4),
          Text(p.home,
              style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSec.withValues(alpha: 0.55),
                  fontFamily: 'Cairo')),
          Icon(p.isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 12, color: AppTheme.textSec.withValues(alpha: 0.4)),
          Text(subjectName,
              style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSec.withValues(alpha: 0.55),
                  fontFamily: 'Cairo')),
          Icon(p.isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 12, color: AppTheme.textSec.withValues(alpha: 0.4)),
          Text(p.lessons,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryFor(p.themeId).withValues(alpha: 0.85),
                  fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildHeader(AppProvider p, String name, Color color) {
    final isDark = p.isDark;
    final baseBg = Theme.of(context).scaffoldBackgroundColor;
    final cardBgStart = Color.lerp(
      baseBg,
      color,
      isDark ? 0.60 : 0.42,
    )!;
    final cardBgEnd = Color.lerp(
      baseBg,
      color,
      isDark ? 0.28 : 0.16,
    )!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [cardBgStart, cardBgEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.45 : 0.30),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.22 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          AnimatedPressable(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: isDark ? 0.45 : 0.26),
                  width: 1.2,
                ),
              ),
              child: Icon(
                p.isAr ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                size: 20,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Subject Name and Lessons count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$name — ${p.lessons}',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color.lerp(baseBg, color, isDark ? 0.35 : 0.16)!,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: color.withValues(alpha: isDark ? 0.40 : 0.22),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎓', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        p.isAr
                            ? 'الصف ${widget.grade}'
                            : 'Grade ${widget.grade}',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.9)
                              : color.withValues(alpha: 0.95),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Refresh Button
          AnimatedPressable(
            onTap: _load,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: isDark ? 0.45 : 0.26),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSlivers(AppProvider p, Color color) {
    if (_loading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, __) => const LessonCardSkeleton(),
              childCount: 6,
            ),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _errorView(p, color),
        ),
      ];
    }
    if (_lessons.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _emptyView(p, color),
        ),
      ];
    }

    final completedCount =
        _lessons.where((l) => _completed.contains(l['id'] as String)).length;

    return [
      SliverToBoxAdapter(
        child: _buildProgressCard(p, color, completedCount, _lessons.length),
      ),
      SliverPadding(
        padding: const EdgeInsets.only(bottom: 32),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _buildLessonCard(_lessons[i], i, p, color),
            childCount: _lessons.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildProgressCard(
      AppProvider p, Color color, int completedCount, int totalCount) {
    final isDark = p.isDark;
    final pct = totalCount > 0 ? completedCount / totalCount : 0.0;
    final pctText = '${(pct * 100).toInt()}%';

    final baseBg = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final cardBgStart = Color.lerp(
      baseBg,
      color,
      isDark ? 0.28 : 0.12,
    )!;
    final cardBgEnd = Color.lerp(
      baseBg,
      color,
      isDark ? 0.08 : 0.03,
    )!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [cardBgStart, cardBgEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.32 : 0.16),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.14 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.isAr ? 'تقدمك الدراسي' : 'Your Progress',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Cairo',
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.isAr
                        ? 'أنجزت $completedCount من أصل $totalCount دروس'
                        : 'Completed $completedCount of $totalCount lessons',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSec,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      AppTheme.success.withValues(alpha: isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.success
                        .withValues(alpha: isDark ? 0.35 : 0.20),
                    width: 1,
                  ),
                ),
                child: Text(
                  pctText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth * pct;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    width: width,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.success, Color(0xFF38ef7d)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.success.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(
      Map<String, dynamic> d, int index, AppProvider p, Color color) {
    final isDark = p.isDark;
    final themeId = p.themeId;
    final lessonId = d['id'] as String;
    final title = p.isAr
        ? (d['title_ar'] ?? 'الدرس ${index + 1}')
        : (d['title_en'] ?? 'Lesson ${index + 1}');
    final videoUrl = d['video_url'] as String? ?? '';
    final duration = d['duration_min'] ?? 0;
    final done = _completed.contains(lessonId);
    final isNew = _isNew(d);

    // ══════════════════════════════════════════════════
    // 🪟 Win Flux — Fluent Design: بطاقة مسطحة حادة Windows 11
    // ══════════════════════════════════════════════════
    if (themeId == AppThemeId.winFlux) {
      Widget winCard = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2C2C2C).withValues(alpha: 0.90)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: done
                ? AppTheme.success.withValues(alpha: isDark ? 0.35 : 0.20)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFD0D0D0)),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Left accent bar
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: done ? AppTheme.success : color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: done
                      ? AppTheme.success.withValues(alpha: 0.12)
                      : color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: done
                        ? AppTheme.success.withValues(alpha: 0.25)
                        : color.withValues(alpha: 0.20),
                    width: 1,
                  ),
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.play_arrow_rounded,
                  color: done ? AppTheme.success : color,
                  size: 22,
                ),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF202020),
                  fontFamily: 'Cairo',
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 11, color: AppTheme.textSec),
                  const SizedBox(width: 3),
                  Text(
                    p.isAr ? '$duration دقيقة' : '$duration min',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSec, fontFamily: 'Cairo'),
                  ),
                  if (done) ...[
                    const SizedBox(width: 8),
                    Text(
                      p.isAr ? '✓ مكتمل' : '✓ Done',
                      style: const TextStyle(fontSize: 10, color: AppTheme.success, fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
              trailing: videoUrl.isNotEmpty
                  ? Icon(
                      p.isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                      size: 20,
                      color: done ? AppTheme.success : (isDark ? Colors.white38 : color.withValues(alpha: 0.60)),
                    )
                  : _comingSoonTag(p),
            ),
          ],
        ),
      );
      if (videoUrl.isNotEmpty) {
        return AnimatedPressable(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(url: videoUrl, title: title, themeColor: color),
            ));
            await _markComplete(lessonId);
          },
          child: winCard,
        );
      }
      return winCard;
    }

    // ══════════════════════════════════════════════════
    // 🌸 Sakura Dream — بطاقة Pastel وردية فقاعية
    // ══════════════════════════════════════════════════
    if (themeId == AppThemeId.sakuraDream) {
      Widget sakuraCard = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: isDark
                ? [const Color(0xFF3D0A50).withValues(alpha: 0.70), const Color(0xFF1A0522).withValues(alpha: 0.85)]
                : [const Color(0xFFFCE4EC), const Color(0xFFF8EBF8)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: done
                ? AppTheme.success.withValues(alpha: 0.35)
                : color.withValues(alpha: isDark ? 0.40 : 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: done
                        ? [AppTheme.success, const Color(0xFF38ef7d)]
                        : [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: (done ? AppTheme.success : color).withValues(alpha: 0.30),
                      blurRadius: 10, offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.favorite_rounded,
                  color: Colors.white, size: 22,
                ),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF4A0060),
                  fontFamily: 'Cairo',
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.20), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('⏱️', style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Text(
                            p.isAr ? '$duration دقيقة' : '$duration min',
                            style: TextStyle(
                              fontSize: 10, color: done ? AppTheme.success : color,
                              fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (done) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          p.isAr ? '✨ مكتمل' : '✨ Done',
                          style: const TextStyle(fontSize: 10, color: AppTheme.success, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing: videoUrl.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.20), width: 1),
                      ),
                      child: Icon(
                        p.isAr ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: done ? AppTheme.success : color,
                      ),
                    )
                  : _comingSoonTag(p),
            ),
            if (isNew && !done)
              Positioned(
                top: 10, left: p.isAr ? null : 10, right: p.isAr ? 10 : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6BB5), Color(0xFFE91E8C)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(p.newBadge, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
                ),
              ),
          ],
        ),
      );
      if (videoUrl.isNotEmpty) {
        return AnimatedPressable(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(url: videoUrl, title: title, themeColor: color),
            ));
            await _markComplete(lessonId);
          },
          child: sakuraCard,
        );
      }
      return sakuraCard;
    }

    // ══════════════════════════════════════════════════
    // 🌌 Deep Space / 🔷 TAM Indigo / 🧊 Arctic Glass — التصميم الأصلي
    // ══════════════════════════════════════════════════
    Widget cardContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            isDark
                ? const Color(0xFF1C1C28).withValues(alpha: 0.9)
                : Colors.white,
            isDark
                ? const Color(0xFF12121A).withValues(alpha: 0.9)
                : const Color(0xFFF9FAFF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done
              ? AppTheme.success.withValues(alpha: isDark ? 0.35 : 0.22)
              : color.withValues(alpha: isDark ? 0.28 : 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (done ? AppTheme.success : color)
                .withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          if (done)
            BoxShadow(
              color: AppTheme.success.withValues(alpha: isDark ? 0.05 : 0.02),
              blurRadius: 16,
              spreadRadius: -2,
            ),
        ],
      ),
      child: Stack(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: done
                      ? [AppTheme.success, const Color(0xFF38ef7d)]
                      : [color, color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (done ? AppTheme.success : color).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                done ? Icons.check_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                fontFamily: 'Cairo',
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          (done ? AppTheme.success : color).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (done ? AppTheme.success : color)
                            .withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: done ? AppTheme.success : color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          p.isAr ? '$duration دقيقة' : '$duration min',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: done ? AppTheme.success : color,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (done) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.20),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        p.isAr ? 'مكتمل' : 'Completed',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.success,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing: videoUrl.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          (isDark ? Colors.white : color).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            (isDark ? Colors.white : color).withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      p.isAr
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: done
                          ? (isDark ? const Color(0xFF38ef7d) : AppTheme.success)
                          : (isDark ? Colors.white70 : color),
                    ),
                  )
                : _comingSoonTag(p),
          ),
          // ── "New" badge ───────────────────────────────────────────
          if (isNew && !done)
            Positioned(
              top: 10,
              left: p.isAr ? null : 10,
              right: p.isAr ? 10 : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  p.newBadge,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (videoUrl.isNotEmpty) {
      return AnimatedPressable(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                url: videoUrl,
                title: title,
                themeColor: color,
              ),
            ),
          );
          await _markComplete(lessonId);
        },
        child: cardContent,
      );
    } else {
      return cardContent;
    }
  }

  Widget _errorView(AppProvider p, Color color) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(child: Text('⚠️', style: TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 16),
              Text(p.errLoadLessons,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(p.errConnection,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSec)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: Text(p.retry),
                style: ElevatedButton.styleFrom(
                    backgroundColor: color, foregroundColor: Colors.white),
                onPressed: _load,
              ),
            ],
          ),
        ),
      );

  Widget _emptyView(AppProvider p, Color color) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: color.withValues(alpha: 0.18),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                    child: Text('📺', style: TextStyle(fontSize: 42))),
              ),
              const SizedBox(height: 20),
              Text(p.noLessons,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(p.lessonsAdded,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSec)),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, size: 16, color: color),
                label: Text(p.retry,
                    style: TextStyle(
                        color: color,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );

  Widget _comingSoonTag(AppProvider p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: AppTheme.textSec.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Text(p.comingSoon,
            style: TextStyle(
                fontSize: 11, color: AppTheme.textSec, fontFamily: 'Cairo')),
      );
}
