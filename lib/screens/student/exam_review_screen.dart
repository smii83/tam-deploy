import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_provider.dart';
import '../../services/firestore_data_service.dart';
import '../../utils/app_theme.dart';
import 'pdfs_screen.dart'; // 🔒 استخدام عارض PDF الداخلي

/// صفحة مراجعة الاختبارات — تعرض ملفات PDF نوع exam_answer (Firestore)
class ExamReviewScreen extends StatefulWidget {
  final String subjectId;
  final Map<String, String> subject;
  final int grade;
  const ExamReviewScreen({
    super.key,
    required this.subjectId,
    required this.subject,
    required this.grade,
  });

  @override
  State<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends State<ExamReviewScreen> {
  List<Map<String, dynamic>> _pdfs = [];
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
      final pdfs = await FirestoreDataService.getPDFs(
        widget.subjectId,
        'exam_answer',
      );
      if (!mounted) return;
      setState(() {
        _pdfs = pdfs;
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

  String _fileUrl(Map<String, dynamic> record) {
    final filename = FirestoreDataService.getPdfFilename(record);
    if (filename.isEmpty) return '';
    final collectionId = record['collectionId'] as String? ?? 'pdfs';
    final recordId = record['id'] as String;
    return FirestoreDataService.getPdfUrl(collectionId, recordId, filename);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final name = p.isAr ? widget.subject['ar']! : widget.subject['en']!;
    final color = p.themeId == AppThemeId.deepSpace
        ? AppTheme.parseColor(widget.subject["color"])
        : AppTheme.primaryFor(p.themeId);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: color,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name — مراجعة الاختبارات',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'الصف ${widget.grade}',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _load,
              ),
            ],
          ),
        ],
        body: _buildBody(p, color),
      ),
    );
  }

  Widget _buildBody(AppProvider p, Color color) {
    if (_loading) return Center(child: CircularProgressIndicator(color: color));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text('تعذّر تحميل الملفات'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    if (_pdfs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
                child: const Center(
                  child: Text('📋', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'لا توجد اختبارات قديمة بعد',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'سيتم إضافة الاختبارات قريباً',
                style: TextStyle(fontSize: 12, color: AppTheme.textSec),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pdfs.length,
      itemBuilder: (_, i) {
        final d = _pdfs[i];
        final title = p.isAr
            ? (d['title_ar'] ?? 'اختبار ${i + 1}')
            : (d['title_en'] ?? 'Exam ${i + 1}');
        final url = _fileUrl(d);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('📄', style: TextStyle(fontSize: 22)),
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            trailing: url.isNotEmpty
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('اقرأ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(
                          url: url,
                          title: title,
                          color: color,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
