import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TAM Firestore Data Service  v1.0
///
/// Firestore Data Service — replaces legacy PocketBaseService.
/// All content & user-data operations (lessons, PDFs, progress, quiz_results,
/// subscriptions, users) — powered by Firebase Firestore + Cloud Storage.
///
/// User documents use Firebase Auth UID as the document ID for fast lookups.
/// Progress and quiz_results are subcollections under each user document.
/// ─────────────────────────────────────────────────────────────────────────────
class FirestoreDataService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  // ══════════════════════════════════════════════════════════════════════════
  // COUNTRIES & GRADES — GCC Multi-Country Dynamic Config
  // ══════════════════════════════════════════════════════════════════════════

  /// List of supported countries with their configuration & visibility flag.
  // ignore: constant_identifier_names
  static const List<Map<String, dynamic>> GCC_COUNTRIES = [
    {
      'code': 'kw',
      'name_ar': 'الكويت',
      'name_en': 'Kuwait',
      'flag': '🇰🇼',
      'currency_ar': 'د.ك',
      'currency_en': 'KWD',
      'price': 12,
      'is_visible': true, // 🟢 نشط الآن — مرحلة الثانوية
      'show_lessons': true, // إظهار مربع الدروس المرئية
    },
    {
      'code': 'sa',
      'name_ar': 'السعودية',
      'name_en': 'Saudi Arabia',
      'flag': '🇸🇦',
      'currency_ar': 'ر.س',
      'currency_en': 'SAR',
      'price': 150,
      'is_visible': false,
      'show_lessons': true,
    },
    {
      'code': 'ae',
      'name_ar': 'الإمارات',
      'name_en': 'UAE',
      'flag': '🇦🇪',
      'currency_ar': 'د.إ',
      'currency_en': 'AED',
      'price': 150,
      'is_visible': false,
      'show_lessons': true,
    },
  ];

  /// Get visible countries for app user
  static Future<List<Map<String, dynamic>>> getCountries() async {
    try {
      final snap = await _db
          .collection('countries')
          .where('is_visible', isEqualTo: true)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }
    } catch (_) {}
    return GCC_COUNTRIES.where((c) => c['is_visible'] == true).toList();
  }

  /// Fetch all visible grades for a specific country (default: 'kw')
  static Future<List<Map<String, dynamic>>> getGrades([String countryCode = 'kw']) async {
    try {
      final snap = await _db
          .collection('grades')
          .where('country', isEqualTo: countryCode)
          .where('is_visible', isEqualTo: true)
          .orderBy('grade_number')
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }
    } catch (_) {}
    return getStaticGradesForCountry(countryCode).where((g) => g['is_visible'] == true).toList();
  }

  /// Official Curricula Static Fallbacks for Kuwait, Saudi Arabia, and UAE (Middle & High School Phases)
  static List<Map<String, dynamic>> getStaticGradesForCountry(String countryCode) {
    if (countryCode == 'sa') {
      return [
        {'grade_number': 7, 'name_ar': 'أول متوسط', 'name_en': 'Grade 7 (Middle)', 'section': 'middle', 'country': 'sa', 'is_visible': true},
        {'grade_number': 8, 'name_ar': 'ثاني متوسط', 'name_en': 'Grade 8 (Middle)', 'section': 'middle', 'country': 'sa', 'is_visible': true},
        {'grade_number': 9, 'name_ar': 'ثالث متوسط', 'name_en': 'Grade 9 (Middle)', 'section': 'middle', 'country': 'sa', 'is_visible': true},
        {'grade_number': 10, 'name_ar': 'أول ثانوي — سنة مشتركة', 'name_en': 'Grade 10 (High)', 'section': 'common', 'country': 'sa', 'is_visible': true},
        {'grade_number': 11, 'name_ar': 'ثاني ثانوي — مسارات', 'name_en': 'Grade 11 (Tracks)', 'section': 'tracks', 'country': 'sa', 'is_visible': true},
        {'grade_number': 12, 'name_ar': 'ثالث ثانوي — مسارات', 'name_en': 'Grade 12 (Tracks)', 'section': 'tracks', 'country': 'sa', 'is_visible': true},
        {'grade_number': 99, 'name_ar': '🎯 تدريبات اختبارات القدرات والتحصيلي', 'name_en': 'Qudrat & Tahsili', 'section': 'qudrat', 'country': 'sa', 'is_visible': true},
      ];
    } else if (countryCode == 'ae') {
      return [
        {'grade_number': 6, 'name_ar': 'الصف السادس', 'name_en': 'Grade 6', 'section': 'middle', 'country': 'ae', 'is_visible': true},
        {'grade_number': 7, 'name_ar': 'الصف السابع', 'name_en': 'Grade 7', 'section': 'middle', 'country': 'ae', 'is_visible': true},
        {'grade_number': 8, 'name_ar': 'الصف الثامن', 'name_en': 'Grade 8', 'section': 'middle', 'country': 'ae', 'is_visible': true},
        {'grade_number': 9, 'name_ar': 'الصف التاسع', 'name_en': 'Grade 9', 'section': 'middle', 'country': 'ae', 'is_visible': true},
        {'grade_number': 10, 'name_ar': 'الصف العاشر — مسار عام / متقدم', 'name_en': 'Grade 10', 'section': 'general', 'country': 'ae', 'is_visible': true},
        {'grade_number': 11, 'name_ar': 'الصف الحادي عشر — مسار عام / متقدم', 'name_en': 'Grade 11', 'section': 'advanced', 'country': 'ae', 'is_visible': true},
        {'grade_number': 12, 'name_ar': 'الصف الثاني عشر — مسار عام / متقدم', 'name_en': 'Grade 12', 'section': 'advanced', 'country': 'ae', 'is_visible': true},
        {'grade_number': 98, 'name_ar': '🇦🇪 تدريبات اختبارات EmSAT الوطنية', 'name_en': 'EmSAT Exam Prep', 'section': 'emsat', 'country': 'ae', 'is_visible': true},
      ];
    } else {
      // Kuwait Curriculum — High School Active, Middle School ready (hidden by default)
      return [
        {'grade_number': 6, 'name_ar': 'الصف السادس', 'name_en': 'Grade 6', 'section': '', 'country': 'kw', 'is_visible': false},
        {'grade_number': 7, 'name_ar': 'الصف السابع', 'name_en': 'Grade 7', 'section': '', 'country': 'kw', 'is_visible': false},
        {'grade_number': 8, 'name_ar': 'الصف الثامن', 'name_en': 'Grade 8', 'section': '', 'country': 'kw', 'is_visible': false},
        {'grade_number': 9, 'name_ar': 'الصف التاسع', 'name_en': 'Grade 9', 'section': '', 'country': 'kw', 'is_visible': false},
        {'grade_number': 10, 'name_ar': 'الصف العاشر (عام)', 'name_en': 'Grade 10 (General)', 'section': '', 'country': 'kw', 'is_visible': true},
        {'grade_number': 10, 'name_ar': 'الصف العاشر — نظام المسارات (2026)', 'name_en': 'Grade 10 (Tracks)', 'section': 'tracks', 'country': 'kw', 'is_visible': true},
        {'grade_number': 11, 'name_ar': 'الصف الحادي عشر — علمي', 'name_en': 'Grade 11 (Science)', 'section': 'scientific', 'country': 'kw', 'is_visible': true},
        {'grade_number': 11, 'name_ar': 'الصف الحادي عشر — أدبي', 'name_en': 'Grade 11 (Literary)', 'section': 'literary', 'country': 'kw', 'is_visible': true},
        {'grade_number': 12, 'name_ar': 'الصف الثاني عشر — علمي', 'name_en': 'Grade 12 (Science)', 'section': 'scientific', 'country': 'kw', 'is_visible': true},
        {'grade_number': 12, 'name_ar': 'الصف الثاني عشر — أدبي', 'name_en': 'Grade 12 (Literary)', 'section': 'literary', 'country': 'kw', 'is_visible': true},
      ];
    }
  }

  /// Fetch all grades (admin use)
  static Future<List<Map<String, dynamic>>> getAllGrades() async {
    final snap =
        await _db.collection('grades').orderBy('grade_number').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Find a grade record by its grade_number and optional country & section
  static Future<Map<String, dynamic>?> getGradeByNumber(int number,
      [String country = 'kw', String section = '']) async {
    Query<Map<String, dynamic>> q = _db
        .collection('grades')
        .where('country', isEqualTo: country)
        .where('grade_number', isEqualTo: number);
    if (section.isNotEmpty) {
      q = q.where('section', isEqualTo: section);
    }
    final snap = await q.limit(1).get();
    if (snap.docs.isEmpty) return null;
    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUBJECTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch visible subjects for a grade record id
  static Future<List<Map<String, dynamic>>> getSubjectsByGradeId(
      String gradeId) async {
    final snap = await _db
        .collection('subjects')
        .where('grade_id', isEqualTo: gradeId)
        .where('is_visible', isEqualTo: true)
        .orderBy('sort_order')
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Fetch subjects for a grade number (looks up grade first)
  static Future<List<Map<String, dynamic>>> getSubjectsByGradeNumber(
      int gradeNumber, [String section = '', String country = 'kw']) async {
    final grade = await getGradeByNumber(gradeNumber, country, section);
    if (grade == null) return [];
    return getSubjectsByGradeId(grade['id'] as String);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LESSONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Active lessons for a subject, ordered by sort_order
  static Future<List<Map<String, dynamic>>> getLessons(
      String subjectId) async {
    final snap = await _db
        .collection('lessons')
        .where('subject_id', isEqualTo: subjectId)
        .where('is_active', isEqualTo: true)
        .orderBy('sort_order')
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PDFs
  // ══════════════════════════════════════════════════════════════════════════

  /// Active PDFs for a subject; optionally filter by type.
  /// type: 'summary' | 'exam_answer' | 'worksheet' | '' (all)
  static Future<List<Map<String, dynamic>>> getPDFs(String subjectId,
      [String type = '']) async {
    Query<Map<String, dynamic>> q = _db
        .collection('pdfs')
        .where('subject_id', isEqualTo: subjectId)
        .where('is_active', isEqualTo: true);
    if (type.isNotEmpty) {
      q = q.where('pdf_type', isEqualTo: type);
    }
    final snap = await q.orderBy('created', descending: true).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Get the download URL for a PDF file stored in Firebase Storage.
  /// [storagePath] is the path inside the storage bucket, e.g. 'pdfs/file.pdf'
  static Future<String> getPdfDownloadUrl(String storagePath) async {
    try {
      return await _storage.ref(storagePath).getDownloadURL();
    } catch (_) {
      return '';
    }
  }

  /// Build the file URL for a PDF record.
  /// For Firestore, PDFs store their download URL directly in `file_url` field.
  static String getPdfUrl(
      String collectionId, String recordId, String filename) {
    // In Firestore model, PDFs have a direct `file_url` field
    // This method is kept for backward compatibility during migration
    return filename; // filename IS the full URL in Firestore model
  }

  /// Extract the filename/URL from a PDF record
  static String getPdfFilename(Map<String, dynamic> record) {
    // In Firestore, we store the full download URL in 'file_url'
    final fileUrl = record['file_url'];
    if (fileUrl != null && fileUrl.toString().isNotEmpty) {
      return fileUrl.toString();
    }
    // Fallback: check legacy fields
    final fileData = record['file_data'];
    if (fileData != null && fileData.toString().isNotEmpty) {
      return fileData.toString();
    }
    final file = record['file'];
    if (file != null && file.toString().isNotEmpty) {
      return file.toString();
    }
    return '';
  }

  // ════════════════════════════════════════════════════════════════════════════
  // GLOBAL SEARCH
  // ════════════════════════════════════════════════════════════════════════════

  /// Search active lessons by name or description across all subjects.
  /// Returns up to 40 matching records.
  /// Note: Firestore doesn't support full-text search natively.
  /// We fetch active lessons and filter client-side.
  static Future<List<Map<String, dynamic>>> searchLessons(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final snap = await _db
        .collection('lessons')
        .where('is_active', isEqualTo: true)
        .orderBy('sort_order')
        .limit(200)
        .get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .where((lesson) {
          final name = (lesson['name'] as String? ?? '').toLowerCase();
          final desc = (lesson['description'] as String? ?? '').toLowerCase();
          return name.contains(q) || desc.contains(q);
        })
        .take(40)
        .toList();
  }

  /// Search active PDFs by name or description across all subjects.
  static Future<List<Map<String, dynamic>>> searchPDFs(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final snap = await _db
        .collection('pdfs')
        .where('is_active', isEqualTo: true)
        .limit(200)
        .get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .where((pdf) {
          final name = (pdf['name'] as String? ?? '').toLowerCase();
          final desc = (pdf['description'] as String? ?? '').toLowerCase();
          final type = (pdf['pdf_type'] as String? ?? '').toLowerCase();
          return name.contains(q) || desc.contains(q) || type.contains(q);
        })
        .take(40)
        .toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USERS — Firebase Auth UID is the document ID
  // ══════════════════════════════════════════════════════════════════════════

  /// Find a user record by Firebase UID. Returns null if not found.
  static Future<Map<String, dynamic>?> getUserByUid(
      String firebaseUid) async {
    final doc = await _db.collection('users').doc(firebaseUid).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  /// Create or update user record in Firestore (called on login / register).
  /// IMPORTANT: For existing users, only `name` and `lang` are updated to
  /// preserve any grade/section/country the user has already set.
  static Future<Map<String, dynamic>?> upsertUser({
    required String firebaseUid,
    required String name,
    required String email,
    int grade = 12,
    String section = 'scientific',
    String country = 'kw',
    String lang = 'ar',
  }) async {
    final ref = _db.collection('users').doc(firebaseUid);
    final doc = await ref.get();

    if (doc.exists) {
      // 🔒 Fix: Only update name and lang for EXISTING users.
      // Do NOT overwrite grade/section/country — user may have changed them.
      await ref.update({
        'name': name,
        'lang': lang,
      });
      // Return merged data with fresh name/lang
      final existing = doc.data()!;
      return {
        'id': firebaseUid,
        ...existing,
        'name': name,
        'lang': lang,
      };
    } else {
      // NEW user: set all fields including grade/section/country defaults
      final data = {
        'firebase_uid': firebaseUid,
        'name': name,
        'email': email,
        'grade': grade,
        'section': section,
        'country': country,
        'lang': lang,
        'is_subscribed': false,
        'is_blocked': false,
        'created': FieldValue.serverTimestamp(),
      };
      await ref.set(data);
      return {'id': firebaseUid, ...data};
    }
  }

  /// Update language preference
  static Future<void> updateUserLang(
      String firebaseUid, String lang) async {
    await _db.collection('users').doc(firebaseUid).update({'lang': lang});
  }

  /// Update grade (and optionally section & country)
  static Future<void> updateUserGrade(String firebaseUid, int grade,
      [String? section, String? country]) async {
    final body = <String, dynamic>{'grade': grade};
    if (section != null) body['section'] = section;
    if (country != null) body['country'] = country;
    await _db.collection('users').doc(firebaseUid).update(body);
  }

  /// Update user name
  static Future<void> updateUserName(
      String firebaseUid, String name) async {
    await _db.collection('users').doc(firebaseUid).update({'name': name});
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUBSCRIPTIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Check if user has an active subscription.
  static Future<bool> isSubscribed(String firebaseUid) async {
    try {
      final now = DateTime.now().toIso8601String().substring(0, 10);

      // 1. Check subscriptions collection
      final snap = await _db
          .collection('subscriptions')
          .where('firebase_uid', isEqualTo: firebaseUid)
          .where('status', isEqualTo: 'active')
          .where('end_date', isGreaterThanOrEqualTo: now)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return true;

      // 2. Fallback: check is_subscribed flag on the user record
      final user = await getUserByUid(firebaseUid);
      return user?['is_subscribed'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Get the active subscription record for a user (null if none).
  static Future<Map<String, dynamic>?> getActiveSubscription(
      String firebaseUid) async {
    try {
      final now = DateTime.now().toIso8601String().substring(0, 10);
      final snap = await _db
          .collection('subscriptions')
          .where('firebase_uid', isEqualTo: firebaseUid)
          .where('status', isEqualTo: 'active')
          .where('end_date', isGreaterThanOrEqualTo: now)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return {'id': snap.docs.first.id, ...snap.docs.first.data()};
    } catch (_) {
      return null;
    }
  }

  /// Activate a subscription after successful payment.
  static Future<bool> activateSubscription({
    required String firebaseUid,
    required String userEmail,
    required String plan,
    int durationDays = 180,
  }) async {
    final start = DateTime.now();
    final end = start.add(Duration(days: durationDays));
    try {
      await _db.collection('subscriptions').add({
        'user_email': userEmail,
        'firebase_uid': firebaseUid,
        'plan': plan,
        'status': 'active',
        'start_date': start.toIso8601String().substring(0, 10),
        'end_date': end.toIso8601String().substring(0, 10),
        'created': FieldValue.serverTimestamp(),
      });
      // Also set is_subscribed flag on the user record
      await _db
          .collection('users')
          .doc(firebaseUid)
          .update({'is_subscribed': true});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROGRESS — subcollection under users/{uid}/progress
  // ══════════════════════════════════════════════════════════════════════════

  /// Mark a lesson as completed (idempotent).
  static Future<void> markLessonComplete(
      String firebaseUid, String lessonId) async {
    await _db
        .collection('users')
        .doc(firebaseUid)
        .collection('progress')
        .doc(lessonId)
        .set({
      'completed': true,
      'completed_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get set of completed lesson IDs for the user.
  static Future<Set<String>> getCompletedLessons(
      String firebaseUid) async {
    final snap = await _db
        .collection('users')
        .doc(firebaseUid)
        .collection('progress')
        .where('completed', isEqualTo: true)
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  /// Get progress stats: completed count and total lessons for a subject.
  static Future<Map<String, int>> getSubjectProgress(
      String firebaseUid, String subjectId) async {
    final lessons = await getLessons(subjectId);
    final total = lessons.length;
    if (total == 0) return {'completed': 0, 'total': 0};

    final lessonIds = lessons.map((l) => l['id'] as String).toSet();
    final completed = await getCompletedLessons(firebaseUid);
    final doneCount = completed.intersection(lessonIds).length;
    return {'completed': doneCount, 'total': total};
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUIZ RESULTS — subcollection under users/{uid}/quiz_results
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> saveQuizResult({
    required String firebaseUid,
    required String subjectId,
    required String subjectName,
    required int grade,
    required int score,
    required int total,
  }) async {
    await _db
        .collection('users')
        .doc(firebaseUid)
        .collection('quiz_results')
        .add({
      'subject_id': subjectId,
      'subject_name': subjectName,
      'grade': grade,
      'score': score,
      'total': total,
      'percentage': total > 0 ? (score / total * 100).round() : 0,
      'completed_at': FieldValue.serverTimestamp(),
    });
  }

  /// Get quiz results for a user, newest first.
  static Future<List<Map<String, dynamic>>> getQuizResults(
      String firebaseUid) async {
    final snap = await _db
        .collection('users')
        .doc(firebaseUid)
        .collection('quiz_results')
        .orderBy('completed_at', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEALTH CHECK
  // ══════════════════════════════════════════════════════════════════════════

  /// Check if Firestore is reachable (always true when Firebase is initialized)
  static Future<bool> isReachable() async {
    try {
      // Simple check: try to access Firestore
      await _db.collection('grades').limit(1).get();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACCOUNT DELETION — Apple App Store Guideline 5.1.1-v
  // Deletes ALL user data: profile, progress, quiz results, subscriptions.
  // ══════════════════════════════════════════════════════════════════════════

  /// Permanently delete all data for a user from Firestore.
  /// Uses WriteBatch for atomic subcollection deletion.
  /// Called before deleting the Firebase Auth account.
  static Future<void> deleteUserData(String firebaseUid) async {
    try {
      final userRef = _db.collection('users').doc(firebaseUid);

      // 1. Delete progress subcollection in batches
      await _deleteSubcollection(userRef.collection('progress'));

      // 2. Delete quiz_results subcollection in batches
      await _deleteSubcollection(userRef.collection('quiz_results'));

      // 3. Delete subscriptions linked to this user
      final subSnap = await _db
          .collection('subscriptions')
          .where('firebase_uid', isEqualTo: firebaseUid)
          .get();
      if (subSnap.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final doc in subSnap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // 4. Delete the user document itself
      await userRef.delete();
    } catch (e) {
      // Rethrow so the caller can surface the error to the user
      rethrow;
    }
  }

  /// Helper: delete all documents in a collection using WriteBatch (Firestore limit: 500/batch)
  static Future<void> _deleteSubcollection(
      CollectionReference<Map<String, dynamic>> colRef) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    do {
      snap = await colRef.limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length == 400);
  }
}

