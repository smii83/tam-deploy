/// Models for TAM interactive lessons (السبورة التفاعلية).
///
/// Firestore:
///   interactive_lessons/{pdfId}  → [InteractiveLessonMeta]  (cheap listing doc)
///   interactive_content/{pdfId}  → [InteractiveLesson]      (slides + audio refs)
library;

/// Lightweight record shown in the lessons list. `pdfId` == the summary PDF id,
/// so the lesson always carries the same name as the uploaded file.
class InteractiveLessonMeta {
  final String pdfId;
  final String subjectId;
  final String title;
  final String status; // processing | ready | error
  final int durationKamila; // seconds (0 if unknown)
  final int durationMukhtasar;
  final bool audioComplete;

  const InteractiveLessonMeta({
    required this.pdfId,
    required this.subjectId,
    required this.title,
    required this.status,
    this.durationKamila = 0,
    this.durationMukhtasar = 0,
    this.audioComplete = false,
  });

  bool get isReady => status == 'ready';

  factory InteractiveLessonMeta.fromMap(Map<String, dynamic> m, [String? id]) {
    return InteractiveLessonMeta(
      pdfId: id ?? (m['pdf_id'] as String? ?? ''),
      subjectId: m['subject_id'] as String? ?? '',
      title: m['title_ar'] as String? ?? '',
      status: m['status'] as String? ?? 'processing',
      durationKamila: (m['duration_kamila'] as num?)?.toInt() ?? 0,
      durationMukhtasar: (m['duration_mukhtasar'] as num?)?.toInt() ?? 0,
      audioComplete: m['audio_complete'] == true,
    );
  }
}

enum SlideKind { welcome, lessonIntro, hook, section, zubda }

/// One screen of the lesson. Everything the canvas needs to render plus the
/// narration that is spoken while the slide is visible.
class LessonSlide {
  final SlideKind kind;

  /// Sub-style for [SlideKind.section]: section | formula | example
  final String style;
  final String tag; // small mono label above the heading
  final String heading; // may contain [[concept]] markers
  final String body;
  final String narration;
  final String? audioPath; // Firebase Storage path (mp3) – null → device TTS
  final double duration; // seconds (real if audio exists, estimated otherwise)

  const LessonSlide({
    required this.kind,
    this.style = 'section',
    this.tag = '',
    this.heading = '',
    this.body = '',
    this.narration = '',
    this.audioPath,
    this.duration = 4,
  });

  /// Text used as context when the student interrupts with a question.
  String get askHeading => heading.replaceAll(RegExp(r'\[\[|\]\]'), '');
  String get askContent => body.isNotEmpty ? body : narration;
}

class InteractiveLesson {
  final String pdfId;
  final String title;
  final String subject;
  final Map<String, List<LessonSlide>> versions; // 'mukhtasar' | 'kamila'

  /// Gemini prebuilt voice the narration was generated with (`content.voice`).
  /// Spoken answers to student questions reuse it so the teacher sounds the same.
  final String voice;

  const InteractiveLesson({
    required this.pdfId,
    required this.title,
    required this.subject,
    required this.versions,
    this.voice = 'Charon',
  });

  static const String mukhtasar = 'mukhtasar';
  static const String kamila = 'kamila';

  List<LessonSlide> slides(String version) =>
      versions[version] ?? versions[kamila] ?? const [];

  // ── Parsing ────────────────────────────────────────────────────────────────
  static double _estimate(String narration) =>
      (narration.length / 13.0).clamp(3.0, 60.0).toDouble();

  static ({String? path, double duration}) _audio(
      dynamic raw, String narration) {
    if (raw is Map && (raw['path'] as String?)?.isNotEmpty == true) {
      final d = (raw['duration'] as num?)?.toDouble() ?? 0;
      return (
        path: raw['path'] as String,
        duration: d > 0 ? d : _estimate(narration)
      );
    }
    return (path: null, duration: _estimate(narration));
  }

  factory InteractiveLesson.fromMap(Map<String, dynamic> m, String pdfId) {
    final title = (m['title'] as String?)?.trim().isNotEmpty == true
        ? (m['title'] as String).trim()
        : 'درس';
    final subject = (m['subject'] as String?) ?? '';
    final common = (m['common'] as Map?)?.cast<String, dynamic>() ?? {};

    LessonSlide welcome() {
      final w = (common['welcome'] as Map?)?.cast<String, dynamic>() ?? {};
      final n = (w['narration'] as String?) ?? 'مرحباً بكم في منصة تَم التعليمية';
      final a = _audio(w['audio'], n);
      return LessonSlide(
        kind: SlideKind.welcome,
        heading: 'مرحباً بكم في منصة تَم التعليمية',
        narration: n,
        audioPath: a.path,
        duration: a.duration,
      );
    }

    LessonSlide intro() {
      final w = (common['intro'] as Map?)?.cast<String, dynamic>() ?? {};
      final n = (w['narration'] as String?) ?? 'درسنا اليوم: $title';
      final a = _audio(w['audio'], n);
      return LessonSlide(
        kind: SlideKind.lessonIntro,
        tag: subject,
        heading: title,
        narration: n,
        audioPath: a.path,
        duration: a.duration,
      );
    }

    List<LessonSlide> build(Map<String, dynamic> v) {
      final out = <LessonSlide>[welcome(), intro()];

      final hook = (v['hook'] as Map?)?.cast<String, dynamic>();
      if (hook != null &&
          hook['available'] == true &&
          (hook['text'] as String?)?.isNotEmpty == true) {
        final text = hook['text'] as String;
        final n = (hook['narration'] as String?) ?? text;
        final a = _audio(hook['audio'], n);
        out.add(LessonSlide(
          kind: SlideKind.hook,
          tag: 'سؤال امتحان حقيقي',
          body: text,
          narration: n,
          audioPath: a.path,
          duration: a.duration,
        ));
      }

      for (final s in (v['sections'] as List? ?? const [])) {
        if (s is! Map) continue;
        final sm = s.cast<String, dynamic>();
        final n = (sm['narration'] as String?) ?? (sm['content'] as String?) ?? '';
        final a = _audio(sm['audio'], n);
        out.add(LessonSlide(
          kind: SlideKind.section,
          style: (sm['type'] as String?) ?? 'section',
          heading: (sm['heading'] as String?) ?? '',
          body: (sm['content'] as String?) ?? '',
          narration: n,
          audioPath: a.path,
          duration: a.duration,
        ));
      }

      // zubda may be a plain string (legacy schema) or {text, narration, audio}
      final z = v['zubda'];
      String zText = '';
      String zNarr = '';
      dynamic zAudio;
      if (z is String) {
        zText = z;
        zNarr = z;
      } else if (z is Map) {
        zText = (z['text'] as String?) ?? '';
        zNarr = (z['narration'] as String?) ?? zText;
        zAudio = z['audio'];
      }
      if (zText.isNotEmpty) {
        final a = _audio(zAudio, zNarr);
        out.add(LessonSlide(
          kind: SlideKind.zubda,
          heading: 'زبدة الدرس',
          body: zText,
          narration: zNarr,
          audioPath: a.path,
          duration: a.duration,
        ));
      }
      return out;
    }

    final versions = (m['versions'] as Map?)?.cast<String, dynamic>() ?? {};
    final result = <String, List<LessonSlide>>{};
    for (final key in [mukhtasar, kamila]) {
      final v = (versions[key] as Map?)?.cast<String, dynamic>();
      if (v != null) result[key] = build(v);
    }
    final voice = (m['voice'] as String?)?.trim();
    return InteractiveLesson(
      pdfId: pdfId,
      title: title,
      subject: subject,
      versions: result,
      voice: (voice != null && voice.isNotEmpty) ? voice : 'Charon',
    );
  }
}
