import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../../services/app_provider.dart';
import '../../services/firestore_data_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/security.dart';
import '../../widgets/skeleton_loader.dart';

/// صفحة ملخصات المادة — تعرض ملفات PDF المرفوعة (Firestore)
class PDFsScreen extends StatefulWidget {
  /// The Firestore subject record id
  final String subjectId;
  final Map<String, String> subject;
  final int grade;
  const PDFsScreen({
    super.key,
    required this.subjectId,
    required this.subject,
    required this.grade,
  });

  @override
  State<PDFsScreen> createState() => _PDFsScreenState();
}

class _PDFsScreenState extends State<PDFsScreen> {
  List<Map<String, dynamic>> _pdfs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SecurityUtils.enableSecureMode(); // summaries are protected content
    _load();
  }

  @override
  void dispose() {
    SecurityUtils.disableSecureMode();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch ALL active PDFs for this subject (all types)
      final pdfs = await FirestoreDataService.getPDFs(widget.subjectId);
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

  /// Build the public file URL for a Firestore PDF record
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
                  '$name — ${p.summaries}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  p.isAr ? 'الصف ${widget.grade}' : 'Grade ${widget.grade}',
                  style:
                      const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _load,
                tooltip: p.retry,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(32),
              child: _buildBreadcrumb(p, name, color),
            ),
          ),
        ],
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.bgGradientFor(p.themeId, p.isDark),
          ),
          child: _buildBody(p, color),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(AppProvider p, String subjectName, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: color.withValues(alpha: 0.85),
      child: Row(
        children: [
          Icon(Icons.home_rounded, size: 11, color: Colors.white.withValues(alpha: 0.65)),
          const SizedBox(width: 4),
          Text(p.home,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.65),
                  fontFamily: 'Cairo')),
          Icon(p.isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 12, color: Colors.white.withValues(alpha: 0.50)),
          Text(subjectName,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.65),
                  fontFamily: 'Cairo')),
          Icon(p.isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 12, color: Colors.white.withValues(alpha: 0.50)),
          Text(p.summaries,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildBody(AppProvider p, Color color) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => const PdfCardSkeleton(),
      );
    }
    if (_error != null) {
      return Center(
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
              Text(p.errLoadFiles,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
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
    }
    if (_pdfs.isEmpty) {
      return Center(
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
                    child: Text('📄', style: TextStyle(fontSize: 42))),
              ),
              const SizedBox(height: 20),
              Text(p.noFiles,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(p.filesAdded,
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
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pdfs.length,
      itemBuilder: (_, i) => _summaryCard(p, color, _pdfs[i], i),
    );
  }

  /// The summary's own name (never a generic "file N" when a real title exists).
  String _titleOf(AppProvider p, Map<String, dynamic> d, int i) {
    String s(dynamic v) => (v ?? '').toString().trim();
    final ar = s(d['title_ar']).isNotEmpty ? s(d['title_ar']) : s(d['name']);
    final en = s(d['title_en']);
    final primary = p.isAr ? ar : en;
    if (primary.isNotEmpty) return primary;
    final other = p.isAr ? en : ar;
    if (other.isNotEmpty) return other;
    return p.isAr ? 'ملخص ${i + 1}' : 'Summary ${i + 1}';
  }

  Widget _summaryCard(
      AppProvider p, Color color, Map<String, dynamic> d, int i) {
    final isDark = p.isDark;
    final title = _titleOf(p, d, i);
    final url = _fileUrl(d);
    final pdfType = d['pdf_type'] as String? ?? '';
    final typeLabels = {
      'summary': (p.isAr ? 'ملخص' : 'Summary', const Color(0xFF7C5CFC)),
      'exam_answer': (p.isAr ? 'حل امتحان' : 'Exam solution', const Color(0xFF10B981)),
      'worksheet': (p.isAr ? 'ورقة عمل' : 'Worksheet', const Color(0xFFF59E0B)),
    };
    final typeInfo = typeLabels[pdfType];
    final textMain = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final canOpen = url.isNotEmpty;

    void open() => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  PdfViewerScreen(url: url, title: title, color: color)),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: canOpen ? open : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order number
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [color, color.withValues(alpha: 0.70)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo',
                            color: textMain),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (typeInfo != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeInfo.$2.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                typeInfo.$1,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: typeInfo.$2,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          const Spacer(),
                          if (canOpen)
                            TextButton.icon(
                              onPressed: open,
                              icon: const Icon(Icons.menu_book_rounded, size: 16),
                              label: Text(p.isAr ? 'اقرأ' : 'Read'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: color,
                                visualDensity: VisualDensity.compact,
                                textStyle: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: AppTheme.textSec.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(p.isAr ? 'قريباً' : 'Soon',
                                  style: TextStyle(
                                      fontSize: 10, color: AppTheme.textSec)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🔒 عارض PDF داخلي — لا يوجد شريط عنوان خارجي، لا زر تحميل، لا مشاركة رابط
// ─────────────────────────────────────────────────────────────────────────────
class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final Color color;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
    required this.color,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _loading = true;
  String? _localPath;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;
  // Simple in-memory cache for downloaded PDFs (url -> local file path)
  static final Map<String, String> _pdfCache = {};

  @override
  void initState() {
    super.initState();
    SecurityUtils.enableSecureMode(); // block screenshots / screen recording of the PDF
    if (!kIsWeb) {
      _downloadAndOpen();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    SecurityUtils.disableSecureMode();
    super.dispose();
  }

  Future<void> _downloadAndOpen() async {
    try { final cached = _pdfCache[widget.url]; if (cached != null && await File(cached).exists()) { if (mounted) setState(() { _localPath = cached; _loading = false; }); return; }
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final fileName =
            'tam_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes); _pdfCache[widget.url] = file.path;
        if (mounted) {
          setState(() {
            _localPath = file.path;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'تعذّر تحميل الملف';
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر تحميل الملف، تحقق من الاتصال';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (kIsWeb) return _webPlaceholder();
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: widget.color),
            const SizedBox(height: 12),
            const Text('جاري تحميل الملخص...',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('تحقق من الاتصال بالإنترنت',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _downloadAndOpen();
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: false,
      pageFling: true,
      pageSnap: true,
      defaultPage: 0,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: true,
      onPageChanged: (page, total) => setState(() {
        _currentPage = page ?? 0;
        _totalPages = total ?? 0;
      }),
      onError: (err) => setState(() => _error = 'خطأ في عرض الملف'),
      onPageError: (page, err) {},
    );
  }

  Widget _webPlaceholder() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24)),
                child: const Center(
                    child: Text('📚', style: TextStyle(fontSize: 40))),
              ),
              const SizedBox(height: 20),
              const Text('المحتوى محمي',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                'الملخصات متاحة للقراءة عبر التطبيق فقط\nلا يمكن تحميل أو مشاركة هذا المحتوى',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smartphone, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text('حمّل التطبيق للوصول للمحتوى',
                        style:
                            TextStyle(color: Colors.orange, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
