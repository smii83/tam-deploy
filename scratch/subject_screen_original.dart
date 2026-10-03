import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_provider.dart';
import '../../services/pocketbase_service.dart';
import 'lessons_screen.dart';
import 'pdfs_screen.dart';
import 'exam_review_screen.dart';
import 'quiz_screen.dart';
import 'ai_tutor_screen.dart';
import 'camera_screen.dart';

class SubjectScreen extends StatefulWidget {
  final Map<String, String> subject;
  final int grade;
  /// PocketBase subject record id — passed if already known
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
    // First check if id is already in the subject map (set when loaded from PocketBase)
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
    // Fallback: Try to find subject by name from PocketBase
    try {
      final grades = await PocketBaseService.getGrades();
      for (final g in grades) {
        if (g['grade_number'] == widget.grade) {
          final subs = await PocketBaseService.getSubjectsByGradeId(g['id']);
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

  Color _toCalmColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 0.65).clamp(0.38, 0.52))
        .withLightness((hsl.lightness * 1.12).clamp(0.62, 0.72))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isDark = p.isDark;
    final name = p.isAr ? widget.subject['ar']! : widget.subject['en']!;
    final rawColor =
        Color(int.parse('FF${widget.subject["color"]}', radix: 16));
    final baseColor = _toCalmColor(rawColor);
    final tintColor = isDark
        ? baseColor.withValues(alpha: 0.18)
        : baseColor.withValues(alpha: 0.10);
    final borderColor =
        baseColor.withValues(alpha: isDark ? 0.30 : 0.20);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  _SubjectHeader(
                    name: name,
                    emoji: widget.subject['em'] ?? '📚',
                    grade: widget.grade,
                    accentColor: baseColor,
                  ),
                  Positioned(
                    top: 50,
                    right: p.isAr ? null : 20,
                    left: p.isAr ? 20 : null,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            size: 22,
                            color: Colors.white,
                            textDirection: TextDirection.ltr),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
                    subtitle: p.isAr ? 'أسئلة الاختبارات السابقة' : 'Past Exams',
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
                      _route(QuizScreen(subject: widget.subject, grade: widget.grade)),
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
                    _route(AITutorScreen(subject: widget.subject, grade: widget.grade)),
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
                    _route(CameraScreen(subject: widget.subject, grade: widget.grade)),
                  ),
                ),
              ]),
            ),
          ),
        ],
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
// Subject Identity Header Card (Original Backup)
// ──────────────────────────────────────────────────────────
class _SubjectHeader extends StatelessWidget {
  final String name;
  final String emoji;
  final int grade;
  final Color accentColor;

  const _SubjectHeader({
    required this.name,
    required this.emoji,
    required this.grade,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            accentColor,
            accentColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Cairo',
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'الصف $grade',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
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
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : accentColor.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
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
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.20)
                  : accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: isAr
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
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
            Icon(
              isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: accentColor.withValues(alpha: 0.5),
              size: 14,
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
}
