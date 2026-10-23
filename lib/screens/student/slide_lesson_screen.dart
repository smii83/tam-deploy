import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/interactive_lesson_model.dart';
import '../../services/app_provider.dart';
import '../../services/firestore_data_service.dart';
import '../../services/lesson_player_controller.dart';
import '../../utils/security.dart';
import '../../widgets/slide_canvas.dart';

/// Interactive whiteboard lesson (السبورة التفاعلية).
///
/// Opened from the lessons list: the student taps a summary's name and the
/// teacher starts explaining immediately. The mic button interrupts the lesson,
/// the answer overlays the slide, and "كمّل الدرس" continues from the same moment.
class SlideLessonScreen extends StatefulWidget {
  final String pdfId;
  final String title;

  const SlideLessonScreen({super.key, required this.pdfId, required this.title});

  @override
  State<SlideLessonScreen> createState() => _SlideLessonScreenState();
}

class _SlideLessonScreenState extends State<SlideLessonScreen>
    with SingleTickerProviderStateMixin {
  LessonPlayerController? _c;
  String? _error;
  bool _loading = true;
  late bool _dark;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    SecurityUtils.enableSecureMode();
    _dark = context.read<AppProvider>().isDark;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lesson = await FirestoreDataService.getInteractiveLesson(widget.pdfId);
      if (!mounted) return;
      if (lesson == null || lesson.slides(InteractiveLesson.kamila).isEmpty) {
        setState(() {
          _error = 'هذا الدرس لم يجهز بعد. جرّب بعد قليل.';
          _loading = false;
        });
        return;
      }
      final country = context.read<AppProvider>().selectedCountry;
      final ctrl = LessonPlayerController(
        lesson: lesson,
        country: country,
        version: lesson.versions.containsKey(InteractiveLesson.kamila)
            ? InteractiveLesson.kamila
            : InteractiveLesson.mukhtasar,
        onFinished: _onFinished,
      );
      ctrl.addListener(_onCtrl);
      setState(() {
        _c = ctrl;
        _loading = false;
      });
      await ctrl.start(); // the teacher starts explaining right away
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل الدرس. تأكد من الاتصال وحاول مرة ثانية.';
        _loading = false;
      });
    }
  }

  void _onCtrl() {
    final listening = _c?.askPhase == AskPhase.listening;
    if (listening && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!listening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  Future<void> _onFinished() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirestoreDataService.markLessonComplete(uid, 'il_${widget.pdfId}');
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('برافو — أنهيت الدرس كاملاً 🎉', style: TextStyle(fontFamily: 'Cairo')),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    SecurityUtils.disableSecureMode();
    _pulse.dispose();
    _c?.removeListener(_onCtrl);
    _c?.dispose();
    super.dispose();
  }

  SlidePalette get _pal => SlidePalette.of(_dark);
  Color get _pageBg => _dark ? const Color(0xFF050507) : const Color(0xFFEFF0F4);
  Color get _chrome => _dark ? Colors.white : const Color(0xFF1D1D1F);

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          child: _loading
              ? _centerMsg(showSpinner: true, msg: 'جاري تجهيز الدرس...')
              : _error != null
                  ? _centerMsg(msg: _error!, retry: true)
                  : _player(),
        ),
      ),
    );
  }

  Widget _centerMsg({bool showSpinner = false, required String msg, bool retry = false}) {
    return Column(
      children: [
        _topBar(null),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSpinner)
                    CircularProgressIndicator(color: _pal.accent)
                  else
                    Icon(Icons.hourglass_empty_rounded, size: 52, color: _pal.accent),
                  const SizedBox(height: 16),
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _chrome.withValues(alpha: 0.75),
                      fontFamily: 'Cairo',
                      fontSize: 14,
                    ),
                  ),
                  if (retry) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _load,
                      style: FilledButton.styleFrom(backgroundColor: _pal.accent),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('جرّب مرة ثانية',
                          style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _player() {
    final c = _c!;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final size = MediaQuery.of(context).size;
        final landscape = size.width > size.height;
        return Column(
          children: [
            _topBar(c),
            if (c.lesson.versions.length > 1) _versionToggle(c),
            Expanded(child: _stage(c, landscape)),
            _progressBar(c),
            _controls(c, landscape),
          ],
        );
      },
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _topBar(LessonPlayerController? c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_forward_rounded, color: _chrome),
            tooltip: 'رجوع',
          ),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _chrome,
                fontFamily: 'Almarai',
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _dark = !_dark),
            icon: Icon(
              _dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _chrome.withValues(alpha: 0.8),
            ),
            tooltip: _dark ? 'الوضع الفاتح' : 'الوضع الغامق',
          ),
        ],
      ),
    );
  }

  // ── Mukhtasar / Kamila ─────────────────────────────────────────────────────
  Widget _versionToggle(LessonPlayerController c) {
    Widget chip(String label, String v, IconData icon) {
      final on = c.version == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => c.setVersion(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: on ? _pal.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: on ? Colors.white : _chrome.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: on ? Colors.white : _chrome.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _chrome.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          chip('النسخة الكاملة', InteractiveLesson.kamila, Icons.menu_book_rounded),
          chip('نسخة الزبدة', InteractiveLesson.mukhtasar, Icons.bolt_rounded),
        ],
      ),
    );
  }

  // ── Canvas stage (16:9, or a taller stage on portrait phones) ─────────────
  Widget _stage(LessonPlayerController c, bool landscape) {
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 600 || landscape;
      final aspect = wide ? 16 / 9 : 4 / 5;
      final maxW = box.maxWidth - 24;
      final maxH = box.maxHeight - 8;
      var w = maxW;
      var h = w / aspect;
      if (h > maxH) {
        h = maxH;
        w = h * aspect;
      }
      return Center(
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _dark ? 0.65 : 0.22),
                blurRadius: 36,
                spreadRadius: -4,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                SlideCanvas(slide: c.current, palette: _pal),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: c.interrupted
                      ? _askOverlay(c)
                      : const SizedBox.shrink(key: ValueKey('no-overlay')),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── AI overlay (glass) ─────────────────────────────────────────────────────
  Widget _askOverlay(LessonPlayerController c) {
    final p = _pal;
    Widget body;
    switch (c.askPhase) {
      case AskPhase.listening:
        body = _overlayText(
          c.question.isEmpty ? 'أسمعك... تكلّم الحين 🎙' : c.question,
          dim: c.question.isEmpty,
        );
      case AskPhase.thinking:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.question.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text('«${c.question}»',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.textSec,
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                    )),
              ),
            _ThinkingDots(color: p.accent),
            const SizedBox(height: 10),
            Text('الأستاذ يفكر ويجهز الإجابة...',
                style: TextStyle(
                    color: p.textSec, fontFamily: 'Cairo', fontSize: 12.5)),
          ],
        );
      case AskPhase.answered:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.question.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('سؤالك: ${c.question}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: p.textSec,
                        fontFamily: 'Tajawal',
                        fontSize: 12.5)),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  c.answer,
                  style: TextStyle(
                    color: p.text,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w500,
                    fontSize: 15.5,
                    height: 1.75,
                  ),
                ),
              ),
            ),
          ],
        );
      case AskPhase.error:
        body = _overlayText(c.askError, color: const Color(0xFFFF6B6B));
      case AskPhase.idle:
        body = const SizedBox.shrink();
    }

    return ClipRect(
      key: const ValueKey('overlay'),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: p.bg.withValues(alpha: _dark ? 0.74 : 0.80),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.accent.withValues(alpha: 0.18),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, size: 17, color: p.accent),
                  ),
                  const SizedBox(width: 10),
                  Text('الأستاذ يشرح',
                      style: TextStyle(
                        color: p.text,
                        fontFamily: 'Almarai',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      )),
                  const Spacer(),
                  if (c.answerSpeaking)
                    Icon(Icons.graphic_eq_rounded, size: 18, color: p.accent),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: Center(child: body)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: c.resumeAfterAsk,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('كمّل الدرس',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlayText(String text, {bool dim = false, Color? color}) {
    return SingleChildScrollView(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? (dim ? _pal.textSec : _pal.text),
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w500,
          fontSize: 16,
          height: 1.7,
        ),
      ),
    );
  }

  // ── Progress ───────────────────────────────────────────────────────────────
  String _fmt(double sec) {
    final s = sec.isNaN ? 0 : sec.round();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _progressBar(LessonPlayerController c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
      child: ValueListenableBuilder<double>(
        valueListenable: c.elapsed,
        builder: (context, value, _) {
          final total = c.totalSeconds <= 0 ? 1.0 : c.totalSeconds;
          final f = (value / total).clamp(0.0, 1.0);
          return Column(
            children: [
              LayoutBuilder(builder: (context, box) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    // RTL: the bar fills from the right
                    final frac = 1 - (d.localPosition.dx / box.maxWidth);
                    c.seekFraction(frac);
                  },
                  child: SizedBox(
                    height: 20,
                    child: Align(
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: _chrome.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: f,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  _pal.accent,
                                  _pal.accent.withValues(alpha: 0.65),
                                ]),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_fmt(value)} / ${_fmt(c.totalSeconds)}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 11,
                      color: _chrome.withValues(alpha: 0.55),
                    ),
                  ),
                  Text(
                    '${c.index + 1} / ${c.slides.length}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 11,
                      color: _chrome.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Controls: transport + tap-to-talk ──────────────────────────────────────
  Widget _controls(LessonPlayerController c, bool landscape) {
    final listening = c.askPhase == AskPhase.listening;

    Widget round(IconData icon, VoidCallback? onTap, {double size = 46, String? tip}) {
      return Tooltip(
        message: tip ?? '',
        child: InkResponse(
          onTap: onTap,
          radius: size / 2 + 6,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _chrome.withValues(alpha: onTap == null ? 0.04 : 0.09),
            ),
            child: Icon(icon,
                size: size * 0.5,
                color: _chrome.withValues(alpha: onTap == null ? 0.25 : 0.85)),
          ),
        ),
      );
    }

    final transport = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        round(Icons.skip_next_rounded, c.isLast ? null : c.next, tip: 'التالي'),
        const SizedBox(width: 12),
        round(
          c.finished
              ? Icons.replay_rounded
              : (c.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          c.interrupted ? null : c.toggle,
          size: 54,
          tip: c.playing ? 'إيقاف مؤقت' : 'تشغيل',
        ),
        const SizedBox(width: 12),
        round(Icons.skip_previous_rounded, c.interrupted ? null : c.previous,
            tip: 'السابق'),
      ],
    );

    final speedChip = GestureDetector(
      onTap: () {
        const speeds = [1.0, 1.25, 1.5, 0.75];
        final i = speeds.indexOf(c.speed);
        c.setSpeed(speeds[(i + 1) % speeds.length]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: _chrome.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${c.speed == c.speed.roundToDouble() ? c.speed.toInt() : c.speed}×',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: 12,
            color: _chrome.withValues(alpha: 0.85),
          ),
        ),
      ),
    );

    final keyboard = round(Icons.keyboard_alt_outlined, () => _typeQuestion(c),
        size: 46, tip: 'اكتب سؤالك');

    final mic = _micButton(c, listening);

    if (landscape) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [speedChip, transport, keyboard, mic],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [speedChip, transport, const SizedBox(width: 52)],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              mic,
              const SizedBox(width: 22),
              keyboard,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            listening
                ? 'أسمعك... اضغط مرة ثانية للإيقاف'
                : 'اضغط على المايك واسأل الأستاذ في أي لحظة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              color: _chrome.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _micButton(LessonPlayerController c, bool listening) {
    const red = Color(0xFFFF4D4F);
    final color = listening ? red : _pal.accent;
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (listening)
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: 64 + 20 * _pulse.value,
                height: 64 + 20 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: red.withValues(alpha: 0.28 * (1 - _pulse.value)),
                ),
              ),
            ),
          GestureDetector(
            onTap: c.askPhase == AskPhase.thinking ? null : c.toggleVoiceQuestion,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.72)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Typed question (library / public place) ───────────────────────────────
  Future<void> _typeQuestion(LessonPlayerController c) async {
    final wasPlaying = c.playing;
    await c.pause();
    if (!mounted) return;
    final controller = TextEditingController();
    final q = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _dark ? const Color(0xFF16161A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اكتب سؤالك للأستاذ',
                  style: TextStyle(
                    fontFamily: 'Almarai',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _chrome,
                  )),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                maxLength: 300,
                textInputAction: TextInputAction.send,
                onSubmitted: (v) => Navigator.pop(ctx, v),
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 15, color: _chrome),
                decoration: InputDecoration(
                  hintText: 'مثلاً: ليش نستخدم القانون العام هنا؟',
                  hintStyle: TextStyle(
                      fontFamily: 'Tajawal', color: _chrome.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: _chrome.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, controller.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: _pal.accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('ارسل سؤالك',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (q != null && q.trim().isNotEmpty) {
      await c.askByText(q);
    } else if (wasPlaying) {
      await c.resume();
    }
  }
}

/// Three bouncing dots while the teacher thinks.
class _ThinkingDots extends StatefulWidget {
  final Color color;
  const _ThinkingDots({required this.color});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_a.value - i * 0.18) % 1.0);
          final up = (t < 0.5 ? t : 1 - t) * 2; // 0..1..0
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 9,
            height: 9,
            transform: Matrix4.translationValues(0, -7 * up, 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.4 + 0.6 * up),
            ),
          );
        }),
      ),
    );
  }
}
