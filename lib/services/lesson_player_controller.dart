import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:video_player/video_player.dart';
import '../models/interactive_lesson_model.dart';
import 'ai_service.dart';

/// State of the "interrupt the teacher" flow.
enum AskPhase { idle, listening, thinking, answered, error }

/// ─────────────────────────────────────────────────────────────────────────────
/// LessonPlayerController — the engine behind the interactive whiteboard.
///
/// • Plays one slide at a time. Narration = pre-generated MP3 (cheap, CDN-like);
///   if a segment has no audio it falls back to the device TTS.
/// • Pause keeps the exact position (audio) / the exact word (device TTS).
/// • Tap-to-talk: pauses the lesson, listens (silence ≥ 2 s ends the question),
///   sends ONLY the current slide + question to Gemini (via [AIService]),
///   speaks the answer, then "كمّل الدرس" resumes from the same moment.
/// ─────────────────────────────────────────────────────────────────────────────
class LessonPlayerController extends ChangeNotifier {
  LessonPlayerController({
    required this.lesson,
    required this.country,
    String version = InteractiveLesson.kamila,
    this.onFinished,
  }) : _version = version;

  final InteractiveLesson lesson;
  final String country;
  final VoidCallback? onFinished;

  // ── Public state ───────────────────────────────────────────────────────────
  final String _version;
  int _index = 0;
  bool _playing = false;
  bool _finished = false;
  double _speed = 1.0;

  String get version => _version;
  List<LessonSlide> get slides => lesson.slides(_version);
  int get index => _index;
  LessonSlide get current => slides[_index];
  bool get playing => _playing;
  bool get finished => _finished;
  double get speed => _speed;
  bool get isFirst => _index == 0;
  bool get isLast => _index >= slides.length - 1;

  /// Elapsed seconds across the whole lesson (updates ~8×/s, separate from
  /// the main notifier so only the progress bar rebuilds).
  final ValueNotifier<double> elapsed = ValueNotifier(0);
  double get totalSeconds => slides.fold(0.0, (a, s) => a + s.duration);

  // ── Ask flow state ─────────────────────────────────────────────────────────
  AskPhase askPhase = AskPhase.idle;
  String question = '';
  String answer = '';
  String askError = '';
  bool answerSpeaking = false;
  bool get interrupted => askPhase != AskPhase.idle;

  // ── Internals ──────────────────────────────────────────────────────────────
  bool _disposed = false;
  int _gen = 0; // bumps on every slide (re)start → ignores stale async work
  double _slideElapsed = 0;
  bool _slideDoneHandled = false;
  DateTime? _lastTick;
  Timer? _ticker;

  VideoPlayerController? _audio;
  VoidCallback? _audioListener;
  final Map<String, String> _urlCache = {};
  int _prefetchIndex = -1;
  Future<VideoPlayerController>? _prefetchFuture;

  final FlutterTts _tts = FlutterTts();
  bool _usingTts = false;
  int _ttsOffset = 0; // char offset where the current utterance started
  int _ttsProgress = 0; // last spoken char (absolute)
  bool _answerMode = false;

  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;
  bool _submitted = false;
  int _askToken = 0; // invalidates in-flight answers when the student resumes
  int _sttSession = 0; // ignores late callbacks from a previous listening session
  bool _sttHeard = false; // the recognizer really started listening this session
  bool _userStopped = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> start() async {
    await _initTts();
    _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) => _tick());
    _playing = true;
    await _runSlide(0);
  }

  Future<void> _initTts() async {
    try {
      for (final lang in const ['ar-SA', 'ar']) {
        final ok = await _tts.isLanguageAvailable(lang);
        if (ok == true || ok == 1) {
          await _tts.setLanguage(lang);
          break;
        }
      }
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setProgressHandler((text, start, end, word) {
        if (!_answerMode) _ttsProgress = _ttsOffset + start;
      });
      _tts.setCompletionHandler(() {
        if (_disposed) return;
        if (_answerMode) {
          answerSpeaking = false;
          _notify();
        } else if (_usingTts && _playing) {
          _onSlideDone(_gen);
        }
      });
      _tts.setErrorHandler((_) {
        if (_disposed) return;
        if (_answerMode) {
          answerSpeaking = false;
          _notify();
        }
      });
    } catch (e) {
      debugPrint('LessonPlayer TTS init: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _gen++;
    _ticker?.cancel();
    _tts.setCompletionHandler(() {});
    _tts.setProgressHandler((a, b, c, d) {});
    _tts.stop();
    _stt.cancel();
    _disposeAudio();
    _prefetchFuture?.then((c) => c.dispose()).catchError((_) {});
    elapsed.dispose();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Slide engine
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _runSlide(int i) async {
    final gen = ++_gen;
    await _stopNarration();
    if (gen != _gen || _disposed) return;
    _index = i.clamp(0, slides.length - 1);
    _slideElapsed = 0;
    _slideDoneHandled = false;
    _finished = false;
    _notify();

    final slide = current;
    _prefetch(_index + 1);

    if (slide.audioPath != null) {
      final ok = await _playAudio(slide, gen);
      if (ok || gen != _gen) return;
    }
    if (gen != _gen || _disposed) return;
    await _speakTts(slide, 0, gen);
  }

  Future<void> _stopNarration() async {
    _usingTts = false;
    try {
      await _tts.stop();
    } catch (_) {}
    await _disposeAudio();
  }

  Future<void> _disposeAudio() async {
    final c = _audio;
    _audio = null;
    if (c != null) {
      if (_audioListener != null) c.removeListener(_audioListener!);
      _audioListener = null;
      try {
        await c.dispose();
      } catch (_) {}
    }
  }

  // ── Audio (pre-generated MP3 from Firebase Storage) ────────────────────────
  Future<VideoPlayerController> _createAudio(String path) async {
    // `fs:<collection>/<doc>` → base64 MP3 stored in Firestore (no Storage needed)
    if (path.startsWith('fs:')) {
      final ref = path.substring(3);
      final cached = _urlCache[path];
      VideoPlayerController c;
      if (kIsWeb) {
        final uri = cached ??
            (_urlCache[path] =
                'data:audio/mpeg;base64,${await _loadClipB64(ref)}');
        c = VideoPlayerController.networkUrl(Uri.parse(uri));
      } else {
        var file = cached == null ? null : File(cached);
        if (file == null || !await file.exists()) {
          final dir = await getTemporaryDirectory();
          // `_v2`: clips were repaired server-side (edge noise removed) — bypass old cached copies.
          file = File('${dir.path}/${ref.replaceAll('/', '_')}_v2.mp3');
          if (!await file.exists() || await file.length() == 0) {
            await file.writeAsBytes(base64Decode(await _loadClipB64(ref)));
          }
          _urlCache[path] = file.path;
        }
        c = VideoPlayerController.file(file);
      }
      await c.initialize();
      return c;
    }
    final url = _urlCache[path] ??
        (_urlCache[path] =
            await FirebaseStorage.instance.ref(path).getDownloadURL());
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    await c.initialize();
    return c;
  }

  Future<String> _loadClipB64(String ref) async {
    final snap = await FirebaseFirestore.instance.doc(ref).get();
    final data = snap.data()?['data'] as String?;
    if (data == null || data.isEmpty) {
      throw Exception('audio clip missing: $ref');
    }
    return data;
  }

  void _prefetch(int i) {
    if (i >= slides.length || i == _prefetchIndex) return;
    final p = slides[i].audioPath;
    if (p == null) return;
    _prefetchIndex = i;
    _prefetchFuture = _createAudio(p);
    _prefetchFuture!.ignore();
  }

  Future<bool> _playAudio(LessonSlide s, int gen) async {
    try {
      VideoPlayerController c;
      if (_prefetchIndex == _index && _prefetchFuture != null) {
        final f = _prefetchFuture!;
        _prefetchFuture = null;
        _prefetchIndex = -1;
        c = await f;
      } else {
        c = await _createAudio(s.audioPath!);
      }
      if (gen != _gen || _disposed) {
        await c.dispose();
        return true;
      }
      _audio = c;
      _usingTts = false;
      await c.setPlaybackSpeed(_speed);
      _audioListener = () => _onAudioChanged(gen);
      c.addListener(_audioListener!);
      if (_playing && !interrupted) await c.play();
      return true;
    } catch (e) {
      debugPrint('LessonPlayer audio failed → device TTS: $e');
      return false;
    }
  }

  void _onAudioChanged(int gen) {
    final c = _audio;
    if (c == null || gen != _gen || _slideDoneHandled || !_playing) return;
    final v = c.value;
    if (!v.isInitialized || v.duration == Duration.zero) return;
    // Rely on the real completion event; the position check is only a safety net
    // and must not cut the end of the clip (that was audible as a click).
    if (v.isCompleted ||
        v.position >= v.duration - const Duration(milliseconds: 20)) {
      _onSlideDone(gen);
    }
  }

  // ── Device TTS fallback ────────────────────────────────────────────────────
  Future<void> _speakTts(LessonSlide s, int from, int gen) async {
    _usingTts = true;
    _ttsOffset = from.clamp(0, s.narration.length);
    _ttsProgress = _ttsOffset;
    if (!_playing || interrupted) return; // starts on resume
    final text = s.narration.substring(_ttsOffset);
    if (text.trim().isEmpty) {
      _onSlideDone(gen);
      return;
    }
    try {
      await _tts.setSpeechRate((0.5 * _speed).clamp(0.2, 1.0));
      _answerMode = false;
      await _tts.speak(text);
    } catch (e) {
      debugPrint('LessonPlayer TTS speak: $e');
      // Silent fallback: advance by reading time so the lesson never freezes.
      Future.delayed(
          Duration(milliseconds: (s.duration * 1000 / _speed).round()), () {
        if (gen == _gen && _playing && _usingTts) _onSlideDone(gen);
      });
    }
  }

  void _onSlideDone(int gen) {
    if (gen != _gen || _slideDoneHandled || _disposed) return;
    _slideDoneHandled = true;
    if (!isLast) {
      // A short, natural pause between explanation segments (also lets the
      // finished audio session release before the next one starts).
      Future.delayed(const Duration(milliseconds: 300), () {
        if (gen == _gen && !_disposed) _runSlide(_index + 1);
      });
    } else {
      _finished = true;
      _playing = false;
      _slideElapsed = current.duration;
      _tick();
      _notify();
      onFinished?.call();
    }
  }

  void _tick() {
    if (_disposed) return;
    final now = DateTime.now();
    final dt = _lastTick == null
        ? 0.0
        : now.difference(_lastTick!).inMilliseconds / 1000.0;
    _lastTick = now;

    final a = _audio;
    if (a != null && a.value.isInitialized) {
      _slideElapsed = a.value.position.inMilliseconds / 1000.0;
    } else if (_usingTts && _playing && !interrupted) {
      _slideElapsed =
          (_slideElapsed + dt * _speed).clamp(0, current.duration * 0.98);
    }
    double before = 0;
    for (var i = 0; i < _index; i++) {
      before += slides[i].duration;
    }
    elapsed.value = before + _slideElapsed.clamp(0, current.duration);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Transport controls
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> pause() async {
    if (!_playing) return;
    _playing = false;
    _notify();
    try {
      await _audio?.pause();
      if (_usingTts) await _tts.stop();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_playing) return;
    if (_finished) {
      _playing = true;
      await _runSlide(0);
      return;
    }
    _playing = true;
    _notify();
    if (_audio != null) {
      await _audio!.play();
    } else if (_usingTts) {
      await _speakTts(current, _ttsProgress, _gen);
    }
    // else: slide still initialising — it starts itself because _playing is true.
  }

  Future<void> toggle() => _playing ? pause() : resume();

  Future<void> goTo(int i) async {
    _playing = true;
    await _runSlide(i);
  }

  Future<void> next() async {
    if (!isLast) await goTo(_index + 1);
  }

  Future<void> previous() async {
    if (_slideElapsed > 2.5 || isFirst) {
      await goTo(_index);
    } else {
      await goTo(_index - 1);
    }
  }

  Future<void> seekFraction(double f) async {
    final target = totalSeconds * f.clamp(0, 1);
    double acc = 0;
    for (var i = 0; i < slides.length; i++) {
      acc += slides[i].duration;
      if (target <= acc) {
        await goTo(i);
        return;
      }
    }
    await goTo(slides.length - 1);
  }

  Future<void> setSpeed(double s) async {
    _speed = s;
    _notify();
    try {
      await _audio?.setPlaybackSpeed(s);
      if (_usingTts && _playing && !interrupted) {
        await _tts.stop();
        await _speakTts(current, _ttsProgress, _gen);
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Ask the teacher (tap-to-talk / typed question)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _enterInterrupt() async {
    await pause(); // freezes audio exactly where it is
    try {
      await _tts.stop(); // in case an answer was still being spoken
    } catch (_) {}
    answerSpeaking = false;
    _answerMode = false;
  }

  static const _micDenied =
      'لازم تسمح للتطبيق باستخدام الميكروفون من إعدادات الجهاز. تقدر تكتب سؤالك بدلاً من ذلك ⌨️';
  static const _noSpeech =
      'ما سمعتك زين. اضغط المايك وتكلّم بصوت أوضح، أو اكتب سؤالك ⌨️';

  /// Tap once to start listening, tap again to stop early.
  Future<void> toggleVoiceQuestion() async {
    if (askPhase == AskPhase.listening) {
      _userStopped = true;
      final s = _sttSession;
      try {
        await _stt.stop();
      } catch (_) {}
      // Some engines never deliver a final status after stop() → settle ourselves.
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (s == _sttSession) _finishListening();
      });
      return;
    }
    await _enterInterrupt();
    final session = ++_sttSession;
    question = '';
    answer = '';
    askError = '';
    _submitted = false;
    _sttHeard = false;
    _userStopped = false;
    askPhase = AskPhase.listening;
    _notify();

    try {
      if (!_sttReady) {
        _sttReady = await _stt.initialize(
          onError: _onSttError,
          onStatus: _onSttStatus,
        );
      }
      if (session != _sttSession || askPhase != AskPhase.listening) return;
      if (!_sttReady) {
        _fail(_micDenied);
        return;
      }
      if (_stt.isListening) await _stt.cancel();
      final locale = await _pickArabicLocale();
      if (session != _sttSession || askPhase != AskPhase.listening) return;
      await _stt.listen(
        onResult: (r) {
          if (session != _sttSession || askPhase != AskPhase.listening) return;
          _sttHeard = true;
          question = r.recognizedWords;
          _notify();
          if (r.finalResult) _submit(question);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          localeId: locale,
          listenFor: const Duration(seconds: 40),
          pauseFor: const Duration(seconds: 3), // silence detection (VAD)
        ),
      );
      // Watchdog: never leave the student staring at "listening" forever.
      Future.delayed(const Duration(seconds: 45), () {
        if (session == _sttSession) _finishListening();
      });
    } catch (e) {
      debugPrint('STT listen failed: $e');
      if (session != _sttSession) return;
      _fail('ما قدرت أشغل المايك. تقدر تكتب سؤالك بدلاً من ذلك ⌨️');
    }
  }

  void _onSttStatus(String s) {
    debugPrint('STT status: $s');
    if (s == 'listening') {
      _sttHeard = true;
      return;
    }
    // Ignore the stray 'notListening'/'done' some engines emit while starting up.
    if ((s == 'done' || s == 'notListening') && _sttHeard) {
      final session = _sttSession;
      // Give the final recognition result a moment to arrive first.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (session == _sttSession) _finishListening();
      });
    }
  }

  void _onSttError(SpeechRecognitionError e) {
    final msg = e.errorMsg.toLowerCase();
    debugPrint('STT error: $msg');
    if (askPhase != AskPhase.listening || _submitted) return;
    if (msg.contains('permission') || msg.contains('not-allowed')) {
      _fail(_micDenied);
      return;
    }
    _finishListening(fromError: true);
  }

  Future<String?> _pickArabicLocale() async {
    try {
      final locales = await _stt.locales();
      final wanted = {'kw': 'KW', 'sa': 'SA', 'ae': 'AE'}[country] ?? 'KW';
      String norm(String s) => s.replaceAll('-', '_').toLowerCase();
      for (final l in locales) {
        if (norm(l.localeId) == 'ar_${wanted.toLowerCase()}') return l.localeId;
      }
      for (final l in locales) {
        if (norm(l.localeId).startsWith('ar')) return l.localeId;
      }
    } catch (_) {}
    return null;
  }

  void _finishListening({bool fromError = false}) {
    if (askPhase != AskPhase.listening || _submitted) return;
    if (question.trim().isNotEmpty) {
      _submit(question);
    } else if (_userStopped && !fromError) {
      // The student pressed stop without saying anything → back to the paused lesson
      askPhase = AskPhase.idle;
      _notify();
    } else {
      _fail(_noSpeech);
    }
  }

  /// Keyboard fallback (library / public place).
  Future<void> askByText(String text) async {
    final q = text.trim();
    if (q.isEmpty) return;
    _sttSession++; // drop any pending voice callbacks
    try {
      await _stt.cancel();
    } catch (_) {}
    await _enterInterrupt();
    _submitted = false;
    answer = '';
    askError = '';
    await _submit(q);
  }

  Future<void> _submit(String q) async {
    final text = q.trim();
    if (text.isEmpty || _submitted) return;
    _submitted = true;
    question = text;
    askPhase = AskPhase.thinking;
    _notify();
    final token = ++_askToken;
    final slide = current;
    try {
      final a = await AIService.lessonAsk(
        lessonTitle: lesson.title,
        subject: lesson.subject,
        heading: slide.askHeading,
        content: slide.askContent,
        question: text,
        country: country,
      ).timeout(const Duration(seconds: 90));
      if (token != _askToken || _disposed) return;
      answer = a;
      askPhase = AskPhase.answered;
      _notify();
      await _speakAnswer(a);
    } catch (e) {
      debugPrint('lessonAsk failed: $e');
      if (token != _askToken || _disposed) return;
      final s = e.toString();
      if (s.contains('QUOTA_EXCEEDED')) {
        _fail('الأستاذ عليه ضغط الحين. جرّب بعد دقيقة 🕐');
      } else {
        _fail('تعذّر الوصول للأستاذ الذكي. تأكد من الإنترنت وحاول مرة ثانية.');
      }
    }
  }

  Future<void> _speakAnswer(String text) async {
    try {
      _answerMode = true;
      answerSpeaking = true;
      _notify();
      await _tts.setSpeechRate(0.5);
      await _tts.speak(text);
    } catch (_) {
      answerSpeaking = false;
      _notify();
    }
  }

  void _fail(String msg) {
    askPhase = AskPhase.error;
    askError = msg;
    answerSpeaking = false;
    _notify();
  }

  /// "كمّل الدرس" — closes the overlay and continues from the exact moment.
  Future<void> resumeAfterAsk() async {
    _askToken++;
    _sttSession++; // invalidates pending recognizer callbacks/watchdogs
    try {
      await _stt.cancel();
      await _tts.stop();
    } catch (_) {}
    _answerMode = false;
    answerSpeaking = false;
    askPhase = AskPhase.idle;
    question = '';
    answer = '';
    _notify();
    await resume();
  }
}
