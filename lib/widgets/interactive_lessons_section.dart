import 'package:flutter/material.dart';
import '../models/interactive_lesson_model.dart';
import '../utils/app_theme.dart';
import 'animated_pressable.dart';

/// "الشرح التفاعلي" block shown at the top of a subject's lessons screen.
///
/// Every uploaded summary PDF appears here under exactly the same name
/// (`pdfs.title_ar`). Tapping the name opens the whiteboard and the teacher
/// starts explaining. Summaries whose lesson is not generated yet are shown
/// dimmed with a "قيد التجهيز" tag.
class InteractiveLessonsSection extends StatelessWidget {
  final List<Map<String, dynamic>> summaries; // pdfs (type == summary)
  final Map<String, InteractiveLessonMeta> metas; // keyed by pdfId
  final Set<String> completed; // progress ids ('il_<pdfId>')
  final Color color;
  final bool isDark;
  final bool isAr;
  final void Function(String pdfId, String title) onOpen;

  const InteractiveLessonsSection({
    super.key,
    required this.summaries,
    required this.metas,
    required this.completed,
    required this.color,
    required this.isDark,
    required this.isAr,
    required this.onOpen,
  });

  String _title(Map<String, dynamic> d) {
    final ar = (d['title_ar'] ?? d['name'] ?? '').toString().trim();
    final en = (d['title_en'] ?? '').toString().trim();
    if (isAr) return ar.isNotEmpty ? ar : en;
    return en.isNotEmpty ? en : ar;
  }

  @override
  Widget build(BuildContext context) {
    final textMain = isDark ? Colors.white : const Color(0xFF1A1A2E);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.65)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'الشرح التفاعلي' : 'Interactive lessons',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                        color: textMain,
                      ),
                    ),
                    Text(
                      isAr
                          ? 'اضغط على الاسم ويبدأ الأستاذ بالشرح، وتقدر تسأله بأي لحظة'
                          : 'Tap a title and the teacher starts — ask anytime',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSec,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final d in summaries) _card(d, textMain),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> d, Color textMain) {
    final pdfId = d['id'] as String;
    final title = _title(d);
    final meta = metas[pdfId];
    final ready = meta?.isReady == true;
    final done = completed.contains('il_$pdfId');
    final minutes = ready && meta!.durationKamila > 0
        ? (meta.durationKamila / 60).ceil()
        : 0;

    final subtitle = ready
        ? (isAr
            ? (minutes > 0 ? 'شرح تفاعلي · $minutes دقيقة' : 'شرح تفاعلي')
            : (minutes > 0 ? 'Interactive · $minutes min' : 'Interactive'))
        : (isAr ? 'قيد التجهيز…' : 'Being prepared…');

    final baseBg = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final card = Opacity(
      opacity: ready ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color.lerp(baseBg, color, isDark ? 0.22 : 0.09)!,
              Color.lerp(baseBg, color, isDark ? 0.06 : 0.02)!,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: done
                ? AppTheme.success.withValues(alpha: 0.45)
                : color.withValues(alpha: isDark ? 0.30 : 0.16),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.12 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (done ? AppTheme.success : color).withValues(alpha: 0.15),
              ),
              child: Icon(
                done
                    ? Icons.check_rounded
                    : (ready ? Icons.play_arrow_rounded : Icons.hourglass_top_rounded),
                color: done ? AppTheme.success : color,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        ready ? Icons.mic_rounded : Icons.schedule_rounded,
                        size: 12,
                        color: AppTheme.textSec,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSec,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (done) ...[
                        const SizedBox(width: 8),
                        Text(
                          isAr ? '✓ مكتمل' : '✓ Done',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.success,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (ready)
              Icon(
                isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.7),
              ),
          ],
        ),
      ),
    );

    if (!ready) return card;
    return AnimatedPressable(onTap: () => onOpen(pdfId, title), child: card);
  }
}
