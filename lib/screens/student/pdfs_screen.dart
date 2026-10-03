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
    _load();
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
      itemBuilder: (_, i) {
        final d = _pdfs[i];
        final title = p.isAr
            ? (d['title_ar'] ?? 'ملف ${i + 1}')
            : (d['title_en'] ?? 'File ${i + 1}');
        final url = _fileUrl(d);
        final pdfType = d['pdf_type'] as String? ?? '';
        final typeLabels = {
          'summary': ('ملخص', const Color(0xFF7C5CFC)),
          'exam_answer': ('حل امتحان', const Color(0xFF10B981)),
          'worksheet': ('ورقة عمل', const Color(0xFFF59E0B)),
        };
        final typeInfo = typeLabels[pdfType];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: const Center(
                  child: Text('📄', style: TextStyle(fontSize: 22))),
            ),
            title: Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            subtitle: typeInfo != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: Container(
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
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  )
                : null,
            trailing: url.isNotEmpty
                ? ElevatedButton.icon(
                    icon:
                        const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('اقرأ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(
                              url: url, title: title, color: color)),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppTheme.textSec.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('قريباً',
                        style: TextStyle(
                            fontSize: 10, color: AppTheme.textSec))),
          ),
        );
      },
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

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _downloadAndOpen();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _downloadAndOpen() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final fileName =
            'tam_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
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
