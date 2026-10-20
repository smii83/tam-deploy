import 'dart:async';
import 'package:flutter/material.dart';
import '../models/interactive_lesson_model.dart';

/// Colour tokens of the cinematic slide canvas (independent from the app theme
/// so the lesson always looks like the approved design).
class SlidePalette {
  final Color bg;
  final Color text;
  final Color textSec;
  final Color accent;
  final Color card;
  final Color border;
  final bool dark;

  const SlidePalette({
    required this.bg,
    required this.text,
    required this.textSec,
    required this.accent,
    required this.card,
    required this.border,
    required this.dark,
  });

  static const SlidePalette darkMode = SlidePalette(
    bg: Color(0xFF0A0A0C),
    text: Color(0xFFF2F2F0),
    textSec: Color(0xFFA7A7AC),
    accent: Color(0xFF5EA1FF),
    card: Color(0x0FFFFFFF),
    border: Color(0x1FFFFFFF),
    dark: true,
  );

  static const SlidePalette lightMode = SlidePalette(
    bg: Color(0xFFFBFBFD),
    text: Color(0xFF1D1D1F),
    textSec: Color(0xFF6E6E73),
    accent: Color(0xFF0071E3),
    card: Color(0x0A000000),
    border: Color(0x1A000000),
    dark: false,
  );

  static SlidePalette of(bool dark) => dark ? darkMode : lightMode;
}

/// The "Kinetic Slide Canvas": renders one [LessonSlide] with a staggered
/// rise-and-fade reveal. Typography: Almarai (headings), Tajawal (body),
/// IBM Plex Mono (tags / formulas).
class SlideCanvas extends StatelessWidget {
  final LessonSlide slide;
  final SlidePalette palette;

  const SlideCanvas({super.key, required this.slide, required this.palette});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final scale = (c.maxWidth / 360).clamp(0.85, 2.4).toDouble();
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          color: palette.bg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // soft accent glow
              Positioned(
                top: -c.maxHeight * 0.35,
                right: -c.maxWidth * 0.2,
                child: Container(
                  width: c.maxWidth * 0.9,
                  height: c.maxWidth * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      palette.accent.withValues(alpha: palette.dark ? 0.16 : 0.10),
                      palette.accent.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _SlideBody(
                  key: ValueKey(identityHashCode(slide)),
                  slide: slide,
                  palette: palette,
                  scale: scale,
                ),
              ),
              if (slide.kind != SlideKind.welcome)
                Positioned(
                  left: 14 * scale,
                  bottom: 10 * scale,
                  child: Opacity(
                    opacity: 0.55,
                    child: Image.asset(
                      palette.dark
                          ? 'assets/images/logo_dark.png'
                          : 'assets/images/logo_light.png',
                      height: 22 * scale,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _SlideBody extends StatefulWidget {
  final LessonSlide slide;
  final SlidePalette palette;
  final double scale;

  const _SlideBody({
    super.key,
    required this.slide,
    required this.palette,
    required this.scale,
  });

  @override
  State<_SlideBody> createState() => _SlideBodyState();
}

class _SlideBodyState extends State<_SlideBody> {
  int _shown = 0;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    // Staggered reveal: element 1 → 2 → 3 …
    const gaps = [120, 620, 1150, 1650];
    for (var i = 0; i < gaps.length; i++) {
      _timers.add(Timer(Duration(milliseconds: gaps[i]), () {
        if (mounted) setState(() => _shown = i + 1);
      }));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  SlidePalette get p => widget.palette;
  double get s => widget.scale;

  TextStyle _heading(double size) => TextStyle(
        fontFamily: 'Almarai',
        fontWeight: FontWeight.w800,
        fontSize: size * s,
        height: 1.35,
        color: p.text,
      );

  TextStyle _body(double size) => TextStyle(
        fontFamily: 'Tajawal',
        fontWeight: FontWeight.w500,
        fontSize: size * s,
        height: 1.7,
        color: p.textSec,
      );

  TextStyle _mono(double size, {Color? color}) => TextStyle(
        fontFamily: 'IBMPlexMono',
        fontSize: size * s,
        letterSpacing: 0.8,
        height: 1.5,
        color: color ?? p.accent,
      );

  Widget _reveal(int step, Widget child) {
    final on = _shown >= step;
    return AnimatedSlide(
      offset: on ? Offset.zero : const Offset(0, 0.22),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: on ? 1 : 0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }

  /// Turns "شنو هي [[المعادلة]]؟" into spans where the marked words use the
  /// accent colour (accent-word).
  List<InlineSpan> _accentSpans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\[\[(.+?)\]\]');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: base.copyWith(color: p.accent),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    return LayoutBuilder(builder: (context, c) {
      final padX = 26.0 * s;
      final contentW = (c.maxWidth - padX * 2).clamp(120.0, 2000.0);
      Widget content;
      switch (slide.kind) {
        case SlideKind.welcome:
          content = _welcome();
        case SlideKind.lessonIntro:
          content = _intro();
        case SlideKind.hook:
          content = _hook();
        case SlideKind.section:
          content = _section();
        case SlideKind.zubda:
          content = _zubda();
      }
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(padX, 18 * s, padX, 34 * s),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: contentW, child: content),
          ),
        ),
      );
    });
  }

  // ── welcome ────────────────────────────────────────────────────────────────
  Widget _welcome() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _reveal(
          1,
          Image.asset(
            p.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png',
            height: 92 * s,
            filterQuality: FilterQuality.high,
          ),
        ),
        SizedBox(height: 22 * s),
        _reveal(
          2,
          Text(
            widget.slide.heading,
            textAlign: TextAlign.center,
            style: _heading(24),
          ),
        ),
      ],
    );
  }

  // ── lessonIntro ────────────────────────────────────────────────────────────
  Widget _intro() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.slide.tag.isNotEmpty)
          _reveal(
            1,
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 5 * s),
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: p.accent.withValues(alpha: 0.35)),
              ),
              child: Text(widget.slide.tag, style: _mono(12)),
            ),
          ),
        SizedBox(height: 18 * s),
        _reveal(
          2,
          Text(
            widget.slide.heading,
            textAlign: TextAlign.center,
            style: _heading(30),
          ),
        ),
      ],
    );
  }

  // ── hook ───────────────────────────────────────────────────────────────────
  Widget _hook() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reveal(
          1,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8 * s,
              height: 8 * s,
              decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
            ),
            SizedBox(width: 8 * s),
            Text(widget.slide.tag, style: _mono(12)),
          ]),
        ),
        SizedBox(height: 16 * s),
        _reveal(
          2,
          Container(
            padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 14 * s),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(14 * s),
              border: Border(
                right: BorderSide(color: p.accent, width: 3.5 * s),
              ),
            ),
            child: Text(widget.slide.body, style: _heading(18).copyWith(height: 1.65)),
          ),
        ),
      ],
    );
  }

  // ── section (section | formula | example) ─────────────────────────────────
  Widget _section() {
    final slide = widget.slide;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (slide.style != 'section')
          _reveal(
            1,
            Padding(
              padding: EdgeInsets.only(bottom: 8 * s),
              child: Text(
                slide.style == 'formula' ? 'القانون' : 'مثال',
                style: _mono(11),
              ),
            ),
          ),
        _reveal(
          1,
          RichText(
            textDirection: TextDirection.rtl,
            text: TextSpan(children: _accentSpans(slide.heading, _heading(21))),
          ),
        ),
        SizedBox(height: 14 * s),
        if (slide.style == 'formula')
          _reveal(2, _formulaBox(slide.body))
        else if (slide.style == 'example')
          _reveal(2, _exampleSteps(slide.body))
        else
          _reveal(2, Text(slide.body, style: _body(15.5))),
      ],
    );
  }

  Widget _formulaBox(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 16 * s),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: p.accent.withValues(alpha: 0.30)),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: _mono(17, color: p.text).copyWith(height: 1.7),
        ),
      ),
    );
  }

  Widget _exampleSteps(String text) {
    final lines =
        text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 8 * s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20 * s,
                  height: 20 * s,
                  margin: EdgeInsets.only(top: 3 * s, left: 10 * s),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${i + 1}', style: _mono(10)),
                ),
                Expanded(child: Text(lines[i], style: _body(15))),
              ],
            ),
          ),
      ],
    );
  }

  // ── zubda ──────────────────────────────────────────────────────────────────
  Widget _zubda() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _reveal(
          1,
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: _shown >= 1 ? 1.0 : 0.4),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 58 * s,
              height: 58 * s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [p.accent, p.accent.withValues(alpha: 0.65)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                boxShadow: [
                  BoxShadow(
                    color: p.accent.withValues(alpha: 0.40),
                    blurRadius: 22 * s,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(Icons.check_rounded, color: Colors.white, size: 34 * s),
            ),
          ),
        ),
        SizedBox(height: 14 * s),
        _reveal(2, Text(widget.slide.heading, style: _heading(22))),
        SizedBox(height: 10 * s),
        _reveal(
          3,
          Text(
            widget.slide.body,
            textAlign: TextAlign.center,
            style: _body(16),
          ),
        ),
      ],
    );
  }
}
