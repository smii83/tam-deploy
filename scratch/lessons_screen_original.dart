import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/app_provider.dart';
import '../../services/pocketbase_service.dart';
import '../../utils/app_theme.dart';
import 'video_player_screen.dart';

class LessonsScreen extends StatefulWidget {
  /// The PocketBase subject record id
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
    setState(() { _loading = true; _error = null; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final results = await Future.wait([
        PocketBaseService.getLessons(widget.subjectId),
        if (uid.isNotEmpty) PocketBaseService.getCompletedLessons(uid),
      ]);
      if (!mounted) return;
      setState(() {
        _lessons = results[0] as List<Map<String, dynamic>>;
        _completed = uid.isNotEmpty
            ? results[1] as Set<String>
            : <String>{};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _markComplete(String lessonId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await PocketBaseService.markLessonComplete(uid, lessonId);
    if (!mounted) return;
    setState(() => _completed.add(lessonId));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final name = p.isAr ? widget.subject['ar']! : widget.subject['en']!;
    final color = Color(int.parse('FF${widget.subject["color"]}', radix: 16));

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
                  '$name — ${p.lessons}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
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
                tooltip: 'تحديث',
              ),
            ],
          ),
        ],
        body: _buildBody(p, color),
      ),
    );
  }

  Widget _buildBody(AppProvider p, Color color) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: color));
    }
    if (_error != null) {
      return _errorView(color);
    }
    if (_lessons.isEmpty) {
      return _emptyView(p, color);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _lessons.length,
      itemBuilder: (_, i) {
        final d = _lessons[i];
        final lessonId = d['id'] as String;
        final title = p.isAr
            ? (d['title_ar'] ?? 'الدرس ${i + 1}')
            : (d['title_en'] ?? 'Lesson ${i + 1}');
        final videoUrl = d['video_url'] as String? ?? '';
        final duration = d['duration_min'] ?? 0;
        final done = _completed.contains(lessonId);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: done
                  ? AppTheme.success.withValues(alpha: 0.35)
                  : color.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (done ? AppTheme.success : color)
                    .withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: done
                      ? [AppTheme.success, const Color(0xFF38ef7d)]
                      : [color, color.withValues(alpha: 0.75)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                done ? Icons.check_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: done ? AppTheme.success : null,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '⏱ $duration دقيقة',
                style: TextStyle(fontSize: 10, color: AppTheme.textSec),
              ),
            ),
            trailing: videoUrl.isNotEmpty
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.play_circle_rounded, size: 16),
                    label: const Text('شاهد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: done ? AppTheme.success : color,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () async {
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
                  )
                : _comingSoonTag(),
          ),
        );
      },
    );
  }

  Widget _errorView(Color color) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              const Text('تعذّر تحميل الدروس',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('تحقق من اتصالك بالإنترنت',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSec)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
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
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24)),
                child: const Center(
                    child: Text('📺', style: TextStyle(fontSize: 40))),
              ),
              const SizedBox(height: 16),
              Text(p.noLessons,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('سيتم إضافة الدروس قريباً',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSec)),
            ],
          ),
        ),
      );

  Widget _comingSoonTag() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: AppTheme.textSec.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Text('قريباً',
            style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSec,
                fontFamily: 'Cairo')),
      );
}
