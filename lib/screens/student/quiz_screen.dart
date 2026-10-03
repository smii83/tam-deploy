import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/app_provider.dart';
import '../../services/firestore_data_service.dart';
import '../../services/ai_service.dart';
import '../../utils/app_theme.dart';

class QuizScreen extends StatefulWidget {
  final Map<String, String> subject;
  final int grade;
  const QuizScreen({super.key, required this.subject, required this.grade});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> _quizQs = [];
  int _qIdx = 0, _score = 0;
  bool _quizLoading = false, _qAnswered = false, _quizDone = false;

  Future<void> _loadQuiz() async {
    setState(() => _quizLoading = true);
    final qs = await AIService.generateQuiz(
      subject: context.read<AppProvider>().isAr
          ? widget.subject['ar']!
          : widget.subject['en']!,
      grade: widget.grade,
      pdfTexts: [],
    );
    setState(() {
      _quizQs = qs;
      _qIdx = 0;
      _score = 0;
      _qAnswered = false;
      _quizDone = false;
      _quizLoading = false;
    });
  }

  void _answer(int idx) {
    if (_qAnswered) return;
    final correct = _quizQs[_qIdx]['correctIndex'] as int;
    setState(() {
      _qAnswered = true;
      if (idx == correct) _score++;
    });
  }

  Future<void> _next() async {
    if (_qIdx < _quizQs.length - 1) {
      setState(() {
        _qIdx++;
        _qAnswered = false;
      });
    } else {
      setState(() => _quizDone = true);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        try {
          await FirestoreDataService.saveQuizResult(
            firebaseUid: uid,
            // 🔒 Fix: Use Firestore document ID, not a generated string from subject name
            subjectId: widget.subject['id'] ?? widget.subject['en']!.toLowerCase().replaceAll(' ', '_'),
            subjectName: widget.subject['ar'] ?? widget.subject['en'] ?? '',
            grade: widget.grade,
            score: _score,
            total: _quizQs.length,
          );
        } catch (_) {
          // Non-critical: show subtle notification if save fails
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تعذّر حفظ النتيجة. ستظهر في سجلك عند الاتصال.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final name = p.isAr ? widget.subject['ar']! : widget.subject['en']!;
    final color = AppTheme.parseColor(widget.subject["color"]);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        leading: IconButton(
          // 🔁 RTL-aware: يتكيف تلقائياً مع اتجاه اللغة
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name — ${p.shortQuiz}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              p.gradeText(widget.grade),
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.bgGradientFor(p.themeId, p.isDark),
        ),
        child: _quizBody(p, color),
      ),
    );
  }

  Widget _quizBody(AppProvider p, Color color) {
    if (_quizQs.isEmpty && !_quizLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  '✏️',
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(p.shortQuiz,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
                p.isAr
                    ? 'يتم توليد الأسئلة من ملفات المادة'
                    : 'Questions are generated from subject files',
                style: TextStyle(fontSize: 12, color: AppTheme.textSec)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow, size: 20),
              label: Text(p.startQuiz),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loadQuiz,
            ),
          ],
        ),
      );
    }
    if (_quizLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: color),
            const SizedBox(height: 12),
            Text(p.solving, style: TextStyle(color: AppTheme.textSec)),
          ],
        ),
      );
    }
    if (_quizDone) return _results(p, color);
    return _question(p, color);
  }

  Widget _question(AppProvider p, Color color) {
    final q = _quizQs[_qIdx];
    final opts = List<String>.from(q['options'] ?? []);
    final correct = q['correctIndex'] as int? ?? 0;
    final letters = ['أ', 'ب', 'ج', 'د'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Progress
        LinearProgressIndicator(
          value: (_qIdx + 1) / _quizQs.length,
          backgroundColor: color.withValues(alpha: 0.15),
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${p.isAr ? 'السؤال' : 'Question'} ${_qIdx + 1} / ${_quizQs.length}',
            style: TextStyle(color: AppTheme.textSec, fontSize: 11),
          ),
        ),
        // Question
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            q['question']?.toString() ?? '',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(height: 16),
        // Options
        ...List.generate(opts.length, (i) {
          Color? bg;
          Color border = color.withValues(alpha: 0.2);
          if (_qAnswered) {
            if (i == correct) {
              bg = AppTheme.success.withValues(alpha: 0.1);
              border = AppTheme.success;
            } else if (i != correct) {
              bg = Colors.red.withValues(alpha: 0.06);
              border = Colors.red.withValues(alpha: 0.3);
            }
          }
          return GestureDetector(
            onTap: () => _answer(i),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bg ?? Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: 1.5),
              ),
              child: Row(children: [
                if (_qAnswered && i == correct)
                  const Icon(Icons.check_circle,
                      color: AppTheme.success, size: 20)
                else if (_qAnswered && i != correct)
                  Icon(Icons.cancel_outlined,
                      color: Colors.red.withValues(alpha: 0.6), size: 20)
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        letters[i],
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSec),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(opts[i], style: const TextStyle(fontSize: 13)),
                ),
              ]),
            ),
          );
        }),
        // Explanation
        if (_qAnswered) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 شرح الإجابة:',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(q['explanation']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _next,
              child: Text(
                _qIdx < _quizQs.length - 1 ? p.nextQuestion : p.showResult,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _results(AppProvider p, Color color) {
    final pct = (_score / _quizQs.length * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(pct >= 60 ? '🎉' : '💪', style: const TextStyle(fontSize: 60)),
            const SizedBox(height: 12),
            Text(
              '$pct%',
              style: TextStyle(
                  fontSize: 48, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              '$_score / ${_quizQs.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              pct >= 60 ? 'ممتاز! 🌟' : 'تحتاج مراجعة 📚',
              style: TextStyle(color: AppTheme.textSec),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loadQuiz,
              child: Text(p.retryQuiz),
            ),
          ],
        ),
      ),
    );
  }
}
