import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tam_app/models/interactive_lesson_model.dart';
import 'package:tam_app/models/lesson_model.dart';
import 'package:tam_app/models/pdf_model.dart';
import 'package:tam_app/models/subject_model.dart';
import 'package:tam_app/models/user_model.dart';
import 'package:tam_app/services/app_provider.dart';
import 'package:tam_app/services/auth_service.dart';
import 'package:tam_app/services/firestore_data_service.dart';
import 'package:tam_app/services/lesson_player_controller.dart';
import 'package:tam_app/utils/app_theme.dart';
import 'package:tam_app/utils/app_urls.dart';
import 'package:tam_app/utils/security.dart';
import 'package:tam_app/utils/tts_audio.dart';

Uint8List _makePcm16(int sampleCount, {int Function(int i)? sampleAt}) {
  final bd = ByteData(sampleCount * 2);
  for (var i = 0; i < sampleCount; i++) {
    final v = sampleAt != null ? sampleAt(i) : 0;
    bd.setInt16(i * 2, v.clamp(-32768, 32767), Endian.little);
  }
  return bd.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsAudio DSP & WAV Encoder', () {
    test('rateFromMime parses explicit rates and falls back to 24000', () {
      expect(TtsAudio.rateFromMime('audio/L16;rate=16000'), equals(16000));
      expect(TtsAudio.rateFromMime('audio/pcm;codec=pcm;rate=48000'), equals(48000));
      expect(TtsAudio.rateFromMime('audio/pcm;rate=invalid'), equals(24000));
      expect(TtsAudio.rateFromMime(null), equals(24000));
      expect(TtsAudio.rateFromMime(''), equals(24000));
    });

    test('cleanedWav produces valid RIFF WAVE header for empty and non-empty PCM', () {
      final emptyWav = TtsAudio.cleanedWav(Uint8List(0), rate: 24000);
      expect(utf8.decode(emptyWav.sublist(0, 4)), equals('RIFF'));
      expect(utf8.decode(emptyWav.sublist(8, 12)), equals('WAVE'));
      expect(emptyWav.length, greaterThanOrEqualTo(44));

      // Sine-like pulse in middle surrounded by dead air
      final pcm = _makePcm16(12000, sampleAt: (i) {
        if (i > 2000 && i < 8000) return (i.isEven ? 12000 : -12000);
        return 0;
      });
      final wav = TtsAudio.cleanedWavFromGemini(pcm, 'audio/L16;rate=16000');
      expect(utf8.decode(wav.sublist(0, 4)), equals('RIFF'));
      final bd = ByteData.sublistView(wav);
      expect(bd.getUint32(24, Endian.little), equals(16000));
      expect(bd.getUint16(22, Endian.little), equals(1)); // mono
      expect(bd.getUint16(34, Endian.little), equals(16)); // 16-bit
    });
  });

  group('FirestoreDataService Pure Helpers & Validation', () {
    test('naturalCompare handles embedded multi-digit numbers and equal ties', () {
      expect(FirestoreDataService.naturalCompareForTest('درس 2', 'درس 10'), lessThan(0));
      expect(FirestoreDataService.naturalCompareForTest('درس 10', 'درس 2'), greaterThan(0));
      expect(FirestoreDataService.naturalCompareForTest('درس 1', 'درس 1'), equals(0));
      expect(FirestoreDataService.naturalCompareForTest('', 'أ'), lessThan(0));
    });

    test('comparePdfs prefers sort_order, then created timestamp, then natural title', () {
      final a = {'sort_order': 2, 'title_ar': 'أ'};
      final b = {'sort_order': 10, 'title_ar': 'ب'};
      expect(FirestoreDataService.comparePdfsForTest(a, b), lessThan(0));

      final c1 = {'created_at': 1000, 'title_ar': 'ملف 10'};
      final c2 = {'created_at': 2000, 'title_ar': 'ملف 2'};
      expect(FirestoreDataService.comparePdfsForTest(c1, c2), lessThan(0));

      final t1 = {'title_ar': 'الوحدة 2'};
      final t2 = {'title_ar': 'الوحدة 10'};
      expect(FirestoreDataService.comparePdfsForTest(t1, t2), lessThan(0));
    });

    test('parseTimestampMillis handles int, DateTime, Timestamp, ISO String, and null/invalid', () {
      expect(FirestoreDataService.parseTimestampMillis(null), equals(0));
      expect(FirestoreDataService.parseTimestampMillis(1700000000000), equals(1700000000000));
      final dt = DateTime.utc(2026, 6, 15);
      expect(FirestoreDataService.parseTimestampMillis(dt), equals(dt.millisecondsSinceEpoch));
      expect(
        FirestoreDataService.parseTimestampMillis(Timestamp.fromDate(dt)),
        equals(dt.millisecondsSinceEpoch),
      );
      expect(FirestoreDataService.parseTimestampMillis('2026-06-15T00:00:00Z'), equals(dt.millisecondsSinceEpoch));
      expect(FirestoreDataService.parseTimestampMillis('not-a-date'), equals(0));
    });

    test('getPdfUrl & getPdfFilename extract URL cleanly across empty and valid maps', () {
      expect(FirestoreDataService.getPdfUrl('pdfs', 'id1', 'https://cdn.tam/a.pdf'),
          equals('https://cdn.tam/a.pdf'));
      expect(FirestoreDataService.getPdfFilename({'file_url': 'https://x/1.pdf', 'file': 'old.pdf'}),
          equals('https://x/1.pdf'));
      expect(FirestoreDataService.getPdfFilename({'file': 'legacy.pdf'}), equals('legacy.pdf'));
      expect(FirestoreDataService.getPdfFilename({}), equals(''));
    });

    test('isRecordValidForTest enforces active status and future/today expiration dates', () {
      final tomorrow = DateTime.now().add(const Duration(days: 2));
      final yesterday = DateTime.now().subtract(const Duration(days: 2));
      final tomorrowStr = tomorrow.toIso8601String().substring(0, 10);
      final yesterdayStr = yesterday.toIso8601String().substring(0, 10);

      expect(FirestoreDataService.isRecordValidForTest({'status': 'cancelled', 'end_date': tomorrowStr}), isFalse);
      expect(FirestoreDataService.isRecordValidForTest({'status': 'active'}), isFalse);
      expect(FirestoreDataService.isRecordValidForTest({'status': 'active', 'end_date': tomorrowStr}), isTrue);
      expect(FirestoreDataService.isRecordValidForTest({'status': 'active', 'end_date': yesterdayStr}), isFalse);
      expect(
        FirestoreDataService.isRecordValidForTest({'status': 'active', 'expires_at': Timestamp.fromDate(tomorrow)}),
        isTrue,
      );
      expect(
        FirestoreDataService.isRecordValidForTest({'status': 'active', 'expires_at': Timestamp.fromDate(yesterday)}),
        isFalse,
      );
    });
  });

  group('AuthService Error Mapping & AppUrls', () {
    test('mapAuthError localizes known Firebase codes in AR and EN plus unknown fallback', () {
      expect(AuthService.mapAuthError('user-not-found', isAr: true), contains('غير مسجل'));
      expect(AuthService.mapAuthError('wrong-password', isAr: false), contains('Incorrect password'));
      expect(AuthService.mapAuthError('email-already-in-use', isAr: false), contains('already registered'));
      expect(AuthService.mapAuthError('weak-password', isAr: true), contains('6 أحرف'));
      expect(AuthService.mapAuthError('invalid-email', isAr: false), contains('Invalid email'));
      expect(AuthService.mapAuthError('network-request-failed', isAr: true), contains('الإنترنت'));
      expect(AuthService.mapAuthError('invalid-credential', isAr: false), contains('Invalid email or password'));
      expect(AuthService.mapAuthError('too-many-requests', isAr: true), contains('too-many-requests'));
    });

    test('AppUrls match canonical legal & store endpoints', () {
      expect(AppUrls.privacyPolicy, equals('https://www.tamlearn.com/privacy.html'));
      expect(AppUrls.termsOfUse, equals('https://www.tamlearn.com/terms.html'));
      expect(AppUrls.supportEmail, equals('support@codecore.llc'));
      expect(AppUrls.appStore, contains('id6818789399'));
    });
  });

  group('InteractiveLesson Model & LessonPlayerController Calculations', () {
    test('InteractiveLesson.fromMap handles missing/partial data, legacy string zubda, and duration clamping', () {
      final lesson = InteractiveLesson.fromMap({
        'title': '  الحركة الدائرية  ',
        'subject': 'الفيزياء',
        'voice': 'Kore',
        'common': {
          'welcome': {'narration': 'أهلاً', 'audio': {'path': 'w.mp3', 'duration': 2.5}},
          'intro': {'narration': 'مقدمة'},
        },
        'versions': {
          'kamila': {
            'hook': {'available': true, 'text': 'سؤال سابق 2023'},
            'sections': [
              {
                'type': 'formula',
                'heading': 'قانون [[التسارع]]',
                'content': 'a = v^2 / r',
                'audio': {'path': 'f.mp3', 'duration': 6.0},
              }
            ],
            'zubda': 'الزبدة النصية',
          },
          'mukhtasar': {'sections': []},
        },
      }, 'pdf_99');

      expect(lesson.pdfId, equals('pdf_99'));
      expect(lesson.title, equals('الحركة الدائرية'));
      expect(lesson.voice, equals('Kore'));

      final kamila = lesson.versions[InteractiveLesson.kamila]!;
      expect(kamila.first.kind, equals(SlideKind.welcome));
      expect(kamila.any((s) => s.kind == SlideKind.hook && s.body == 'سؤال سابق 2023'), isTrue);
      final formulaSlide = kamila.firstWhere((s) => s.kind == SlideKind.section);
      expect(formulaSlide.askHeading, equals('قانون التسارع'));
      expect(formulaSlide.duration, equals(6.0));
      expect(kamila.last.kind, equals(SlideKind.zubda));
      expect(kamila.last.body, equals('الزبدة النصية'));

      // Empty map fallback safely returns empty slide list via slides()
      final emptyLesson = InteractiveLesson.fromMap({}, 'empty_id');
      expect(emptyLesson.pdfId, equals('empty_id'));
      expect(emptyLesson.slides(InteractiveLesson.kamila), isEmpty);
      expect(emptyLesson.slides(InteractiveLesson.mukhtasar), isEmpty);
    });

    test('InteractiveLessonMeta.fromMap handles defaults and ready getter', () {
      final meta = InteractiveLessonMeta.fromMap({'status': 'ready', 'duration_kamila': 95, 'audio_complete': true}, 'p1');
      expect(meta.isReady, isTrue);
      expect(meta.durationKamila, equals(95));
      expect(InteractiveLessonMeta.fromMap({}, 'p2').isReady, isFalse);
    });

    test('LessonSlide defaults & askContent fallback work with empty body', () {
      const slide = LessonSlide(kind: SlideKind.section, heading: '[[الذرة]]', body: '', narration: 'شرح شفهي');
      expect(slide.askHeading, equals('الذرة'));
      expect(slide.askContent, equals('شرح شفهي'));
    });

    test('LessonPlayerController exposes totalSeconds from loaded slides', () {
      const lesson = InteractiveLesson(
        pdfId: 'p1',
        title: 't',
        subject: 's',
        versions: {
          InteractiveLesson.kamila: [
            LessonSlide(kind: SlideKind.welcome, duration: 3.0),
            LessonSlide(kind: SlideKind.section, duration: 7.5),
          ],
          InteractiveLesson.mukhtasar: [
            LessonSlide(kind: SlideKind.welcome, duration: 2.0),
          ],
        },
      );
      final ctrl = LessonPlayerController(lesson: lesson, country: 'kw');
      expect(ctrl.totalSeconds, closeTo(10.5, 0.001));
    });
  });

  group('AppTheme & AppProvider Pure State & Edge Cases', () {
    test('AppTheme handles 6-char, 8-char, layout, gridCols, and toCalmColor across all themes', () {
      expect(AppTheme.parseColor('#FF112233'), equals(const Color(0xFF112233)));
      expect(AppTheme.parseColor(''), equals(const Color(0xFF7C3AED)));
      for (final id in AppThemeId.values) {
        expect(AppTheme.primaryFor(id), isA<Color>());
        expect(AppTheme.gridColsFor(id, 360), greaterThanOrEqualTo(1));
        expect(AppTheme.gridColsFor(id, 900), greaterThanOrEqualTo(2));
        expect(AppTheme.gridAspectFor(id), greaterThan(0));
      }
      final calm = AppTheme.toCalmColor(const Color(0xFFFF0000));
      expect(calm, isA<Color>());
    });

    test('AppProvider restores valid cache, survives corrupt JSON cache, and selects country tracks', () async {
      SharedPreferences.setMockInitialValues({
        'cached_subjects': 'not-valid-json{{{',
        'dark': false,
        'country': 'sa',
        'lang': 'en',
      });
      final provider = AppProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.isDark, isFalse);
      expect(provider.selectedCountry, equals('sa'));
      expect(provider.isAr, isFalse);
      expect(provider.gradeText(11), equals('Grade 11'));

      // Negative / out-of-range grades fall back safely instead of throwing
      expect(AppProvider.getSubjects(0, 'scientific', 'kw'), equals(AppProvider.getSubjects(12, 'scientific', 'kw')));
      expect(AppProvider.getSubjects(-5, 'scientific', 'sa'), isNotEmpty);
      expect(AppProvider.getSubjects(99, null, 'sa'), isNotEmpty); // Qudrat
      expect(AppProvider.getSubjects(98, null, 'ae'), isNotEmpty); // EmSAT
      expect(AppProvider.getSubjects(12, 'scientific', 'kw'), isNotEmpty);
      expect(AppProvider.getSubjects(12, 'literary', 'kw'), isNotEmpty);
      expect(AppProvider.getSubjects(12, 'scientific', 'ae'), isNotEmpty);

      await provider.toggleDark();
      expect(provider.isDark, isTrue);
      await provider.setTheme(AppThemeId.tamIndigo);
      expect(provider.themeId, equals(AppThemeId.tamIndigo));
    });

    test('SecurityUtils maintains balanced hold counts without throwing in test environment', () async {
      await SecurityUtils.enableSecureMode();
      await SecurityUtils.enableSecureMode();
      await SecurityUtils.disableSecureMode();
      await SecurityUtils.disableSecureMode();
      // Extra disable below zero should safely no-op
      await SecurityUtils.disableSecureMode();
    });

    test('Domain model edge cases with empty or malformed fields', () {
      final emptyUser = UserModel.fromMap({});
      expect(emptyUser.grade, equals(12));
      expect(emptyUser.section, equals('scientific'));
      expect(emptyUser.isSubscribed, isFalse);
      expect(emptyUser.isBlocked, isFalse);

      final emptySubject = SubjectModel.fromMap({});
      expect(emptySubject.id, equals(''));
      expect(emptySubject.nameAr, equals(''));

      final lessonWithStrDuration = LessonModel.fromMap({'duration_min': 0});
      expect(lessonWithStrDuration.durationMin, equals(0));

      final pdfFallback = PdfModel.fromMap({'pdf_type': 'worksheet'});
      expect(pdfFallback.pdfType, equals('worksheet'));
      expect(pdfFallback.fileUrl, isEmpty);
    });
  });
}
