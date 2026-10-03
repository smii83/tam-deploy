import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tam_app/models/user_model.dart';
import 'package:tam_app/models/subject_model.dart';
import 'package:tam_app/models/lesson_model.dart';
import 'package:tam_app/models/pdf_model.dart';
import 'package:tam_app/utils/app_theme.dart';
import 'package:tam_app/services/firestore_data_service.dart';
import 'package:tam_app/services/app_provider.dart';

void main() {
  group('Domain Models & Color Utility Unit Tests', () {
    test('AppTheme.parseColor handles valid, hash, invalid, and null hex strings', () {
      expect(AppTheme.parseColor('7C3AED'), equals(const Color(0xFF7C3AED)));
      expect(AppTheme.parseColor('#059669'), equals(const Color(0xFF059669)));
      expect(AppTheme.parseColor('invalid'), equals(const Color(0xFF7C3AED)));
      expect(AppTheme.parseColor(null), equals(const Color(0xFF7C3AED)));
    });

    test('UserModel.fromMap initializes correctly', () {
      final map = {
        'id': 'uid_123',
        'firebase_uid': 'uid_123',
        'name': 'أحمد علي',
        'email': 'ahmed@example.com',
        'grade': 12,
        'section': 'scientific',
        'is_subscribed': true,
      };
      final user = UserModel.fromMap(map);
      expect(user.id, equals('uid_123'));
      expect(user.name, equals('أحمد علي'));
      expect(user.isSubscribed, isTrue);
    });

    test('SubjectModel.fromMap converts color safely', () {
      final map = {
        'id': 'sub_01',
        'name_ar': 'الرياضيات',
        'name_en': 'Mathematics',
        'icon': '🔢',
        'color': '#F97316',
      };
      final subject = SubjectModel.fromMap(map);
      expect(subject.nameAr, equals('الرياضيات'));
      expect(subject.color, equals(const Color(0xFFF97316)));
      expect(subject.toAppMap()['color'], equals('F97316'));
    });

    test('LessonModel.fromMap parses duration and title correctly', () {
      final map = {
        'id': 'les_01',
        'subject_id': 'sub_01',
        'title_ar': 'الاشتقاق',
        'video_url': 'https://youtube.com/watch?v=123',
        'duration_min': 45,
      };
      final lesson = LessonModel.fromMap(map);
      expect(lesson.titleAr, equals('الاشتقاق'));
      expect(lesson.durationMin, equals(45));
      expect(lesson.videoUrl, equals('https://youtube.com/watch?v=123'));
    });

    test('PdfModel.fromMap extracts download url fallback correctly', () {
      final map = {
        'id': 'pdf_01',
        'subject_id': 'sub_01',
        'title_ar': 'ملخص التفاضل',
        'pdf_type': 'summary',
        'file_url': 'https://storage.firebase.com/pdf.pdf',
      };
      final pdf = PdfModel.fromMap(map);
      expect(pdf.titleAr, equals('ملخص التفاضل'));
      expect(pdf.fileUrl, equals('https://storage.firebase.com/pdf.pdf'));
    });

    test('AppThemeId.platinumMinimal is correctly registered with Slate Dark colors', () {
      final meta = AppTheme.allThemes.firstWhere((t) => t.id == AppThemeId.platinumMinimal);
      expect(meta.nameAr, equals('Platinum'));
      expect(meta.nameEn, equals('Platinum Minimal'));
      expect(meta.darkBg, equals(const Color(0xFF202124)));
      expect(meta.lightBg, equals(const Color(0xFFF8F9FA)));
      expect(AppTheme.navDarkBgFor(AppThemeId.platinumMinimal), equals(const Color(0xFF202124)));
    });

    test('Kuwait Grade 10 Tracks curriculum is correctly configured', () {
      final grades = FirestoreDataService.getStaticGradesForCountry('kw');
      final tracksGrade = grades.firstWhere(
        (g) => g['grade_number'] == 10 && g['section'] == 'tracks',
      );
      expect(tracksGrade['name_ar'], contains('المسارات'));
      expect(tracksGrade['is_visible'], isTrue);

      final subjects = AppProvider.getSubjects(10, 'tracks', 'kw');
      expect(subjects.length, equals(9));
      expect(subjects.any((s) => s['ar'] == 'العلوم المتكاملة'), isTrue);
      expect(subjects.any((s) => s['ar'] == 'مقرر الاستكشاف (1 و 2)'), isTrue);
      expect(subjects.any((s) => s['ar'] == 'الحوسبة والذكاء الاصطناعي'), isTrue);
    });
  });
}
