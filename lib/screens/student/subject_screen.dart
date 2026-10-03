import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_provider.dart';
import '../../services/firestore_data_service.dart';
import '../../utils/app_theme.dart';
import 'lessons_screen.dart';
import 'pdfs_screen.dart';
import 'exam_review_screen.dart';
import 'quiz_screen.dart';
import 'ai_tutor_screen.dart';
import 'camera_screen.dart';

class SubjectScreen extends StatefulWidget {
  final Map<String, String> subject;
  final int grade;

  /// Firestore subject record id — passed if already known
  final String? subjectId;
  const SubjectScreen({
    super.key,
    required this.subject,
    required this.grade,
    this.subjectId,
  });

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  String _subjectId = '';

  @override
  void initState() {
    super.initState();
    // First check if id is already in the subject map (set when loaded from Firestore)
    final mapId = widget.subject['id'] ?? '';
    if (widget.subjectId != null && widget.subjectId!.isNotEmpty) {
      _subjectId = widget.subjectId!;
    } else if (mapId.isNotEmpty) {
      _subjectId = mapId;
    } else {
      _fetchSubjectId();
    }
  }

  Future<void> _fetchSubjectId() async {
    // Fallback: Try to find subject by name from Firestore
    try {
      final grades = await FirestoreDataService.getGrades();
      for (final g in grades) {
        if (g['grade_number'] == widget.grade) {
          final subs = await FirestoreDataService.getSubjectsByGradeId(g['id']);
          for (final s in subs) {
            if ((s['name_ar'] as String? ?? '') == widget.subject['ar'] ||
                (s['name_en'] as String? ?? '').toLowerCase() ==
                    (widget.subject['en'] ?? '').toLowerCase()) {
              if (mounted) setState(() => _subjectId = s['id'] as String);
              return;
            }
          }
        }
      }
    } catch (_) {}
  }


  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isDark = p.isDark;
    final name = p.isAr ? widget.subject['ar']! : widget.subject['en']!;
    final rawColor = AppTheme.parseColor(widget.subject["color"]);
    final baseColor = p.themeId == AppThemeId.deepSpace
        ? AppTheme.toCalmColor(rawColor)
        : AppTheme.primaryFor(p.themeId);
    final tintColor = isDark
        ? baseColor.withValues(alpha: 0.18)
        : baseColor.withValues(alpha: 0.10);
    final borderColor = baseColor.withValues(alpha: isDark ? 0.30 : 0.20);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.bgGradientFor(p.themeId, isDark),
        ),
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: _SubjectHeader(
                name: name,
                emoji: widget.subject['em'] ?? '📚',
                grade: widget.grade,
                accentColor: baseColor,
                isDark: isDark,
                isAr: p.isAr,
                onBack: () => Navigator.pop(context),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Video Lessons Card + Summaries Card ──
                _rowTwo(
                  left: _SectionCard(
                    emoji: '🎬',
                    title: p.isAr ? 'الدروس' : 'Lessons',
                    subtitle: p.isAr ? 'شروحات المادة' : 'Video Lessons',
                    accentColor: baseColor,
                    tintColor: tintColor,
                    borderColor: borderColor,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      _route(LessonsScreen(
                        subjectId: _subjectId,
                        subject: widget.subject,
                        grade: widget.grade,
                      )),
                    ),
                  ),
                  right: _SectionCard(
                    emoji: '📄',
                    title: p.isAr ? 'ملخصات المادة' : 'Summaries',
                    subtitle: p.isAr ? 'ملخصات المادة' : 'Notes & Files',
                    accentColor: baseColor,
                    tintColor: tintColor,
                    borderColor: borderColor,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      _route(PDFsScreen(
                        subjectId: _subjectId,
                        subject: widget.subject,
                        grade: widget.grade,
                      )),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _rowTwo(
                  left: _SectionCard(
                    emoji: '📝',
                    title: p.isAr ? 'مراجعة الاختبارات' : 'Exam Review',
                    subtitle:
                        p.isAr ? 'أسئلة الاختبارات السابقة' : 'Past Exams',
                    accentColor: baseColor,
                    tintColor: tintColor,
                    borderColor: borderColor,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      _route(ExamReviewScreen(
                        subjectId: _subjectId,
                        subject: widget.subject,
                        grade: widget.grade,
                      )),
                    ),
                  ),
                  right: _SectionCard(
                    emoji: '✏️',
                    title: p.isAr ? 'الاختبار' : 'Quiz',
                    subtitle: p.isAr ? 'اختبر نفسك الآن' : 'Test Yourself',
                    accentColor: baseColor,
                    tintColor: tintColor,
                    borderColor: borderColor,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      _route(QuizScreen(
                          subject: widget.subject, grade: widget.grade)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _WideCard(
                  emoji: '🤖',
                  title: p.isAr ? 'اسأل المدرس' : 'Ask Teacher',
                  subtitle: p.isAr ? 'مدرسك الذكي المخصص ✨' : 'Your AI Tutor ✨',
                  accentColor: baseColor,
                  isDark: isDark,
                  isAr: p.isAr,
                  onTap: () => Navigator.push(
                    context,
                    _route(AITutorScreen(
                        subject: widget.subject, grade: widget.grade)),
                  ),
                ),
                const SizedBox(height: 12),
                _WideCard(
                  emoji: '📸',
                  title: p.isAr ? 'صور وحل' : 'Solve by Photo',
                  subtitle: p.isAr
                      ? 'صوّر السؤال → نحله فوراً ✨'
                      : 'Photo question → Instant solution ✨',
                  accentColor: baseColor,
                  isDark: isDark,
                  isAr: p.isAr,
                  secondary: true,
                  onTap: () => Navigator.push(
                    context,
                    _route(CameraScreen(
                        subject: widget.subject, grade: widget.grade)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _rowTwo({required Widget left, required Widget right}) {
    return Row(children: [
      Expanded(child: left),
      const SizedBox(width: 12),
      Expanded(child: right),
    ]);
  }

  Route _route(Widget screen) => MaterialPageRoute(builder: (_) => screen);
}

// ──────────────────────────────────────────────────────────
// Subject Identity Header Card
// ──────────────────────────────────────────────────────────
class _SubjectHeader extends StatelessWidget {
  final String name;
  final String emoji;
  final int grade;
  final Color accentColor;
  final bool isDark;
  final bool isAr;
  final VoidCallback onBack;

  const _SubjectHeader({
    required this.name,
    required this.emoji,
    required this.grade,
    required this.accentColor,
    required this.isDark,
    required this.isAr,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final baseBg = Theme.of(context).scaffoldBackgroundColor;
    final cardBgStart = Color.lerp(
      baseBg,
      accentColor,
      isDark ? 0.60 : 0.42,
    )!;
    final cardBgEnd = Color.lerp(
      baseBg,
      accentColor,
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
          color: accentColor.withValues(alpha: isDark ? 0.45 : 0.30),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Emoji container
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Color.lerp(baseBg, accentColor, isDark ? 0.42 : 0.24)!,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withValues(alpha: isDark ? 0.55 : 0.35),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 12),
          // Name and Grade tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    fontSize: 19,
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
                    color:
                        Color.lerp(baseBg, accentColor, isDark ? 0.35 : 0.16)!,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          accentColor.withValues(alpha: isDark ? 0.40 : 0.22),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎓', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        isAr ? 'الصف $grade' : 'Grade $grade',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.9)
                              : accentColor.withValues(alpha: 0.95),
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
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: isDark ? 0.45 : 0.26),
                  width: 1.2,
                ),
              ),
              child: Icon(
                isAr ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                size: 20,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Square Section Card (top 4 grid cards)
// ──────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color tintColor;
  final Color borderColor;
  final bool isDark;
  final VoidCallback onTap;

  const _SectionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.tintColor,
    required this.borderColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 150,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Stack(
          children: [
            // Emoji icon
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
            ),
            // Text at bottom
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: accentColor.withValues(alpha: 0.85),
                      fontSize: 9.5,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Wide Horizontal Card (bottom 2 full-width cards)
// ──────────────────────────────────────────────────────────
class _WideCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isDark;
  final bool isAr;
  final bool secondary;
  final VoidCallback onTap;

  const _WideCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.isDark,
    required this.isAr,
    required this.onTap,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    // Wide cards use a subtle gradient of the subject color
    final gradientStart = secondary
        ? (isDark
            ? accentColor.withValues(alpha: 0.25)
            : accentColor.withValues(alpha: 0.12))
        : (isDark
            ? accentColor.withValues(alpha: 0.30)
            : accentColor.withValues(alpha: 0.15));

    final gradientEnd = isDark ? const Color(0xFF1E1E2C) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [gradientStart, gradientEnd],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.28 : 0.18),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Emoji icon (Right in RTL, Left in LTR)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.22 : 0.13),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor.withValues(alpha: isDark ? 0.35 : 0.22),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment:
                    isAr ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: accentColor.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Arrow icon (Left in RTL, Right in LTR)
            Icon(
              isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: accentColor.withValues(alpha: 0.5),
              size: 14,
              textDirection: TextDirection.ltr, // Prevent automatic mirroring
            ),
          ],
        ),
      ),
    );
  }
}
