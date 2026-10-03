import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AI Service v2 — Firebase Cloud Functions Proxy
///
/// 🔒 SECURITY: No API keys are stored in the client app.
/// All Gemini calls go through Firebase Cloud Functions which:
///   1. Verify the user's Firebase Auth token
///   2. Enforce server-side rate limiting (Firestore-backed, cannot be bypassed)
///   3. Keep the Gemini API key in Firebase Secrets Manager
/// ─────────────────────────────────────────────────────────────────────────────
class AIService {
  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'me-central1');

  // ── Text Chat via Cloud Function ─────────────────────────────────────────
  static Future<String> chat({
    required String subject,
    required int grade,
    required List<Map<String, String>> history,
    required String message,
    String? userName,
    String country = 'kw',
  }) async {
    try {
      final result = await _functions.httpsCallable('geminiChat').call({
        'subject': subject,
        'grade': grade,
        'history': history,
        'message': message,
        'userName': userName ?? '',
        'country': country,
      });
      return (result.data as String?) ?? '';
    } on FirebaseFunctionsException catch (e) {
      debugPrint('geminiChat error: ${e.code} — ${e.message}');
      if (e.code == 'resource-exhausted') {
        return e.message ??
            'لقد تجاوزت الحد المسموح من الأسئلة. يرجى المحاولة لاحقاً 🕐';
      }
      if (e.code == 'unauthenticated') {
        return '⚠️ يجب تسجيل الدخول لاستخدام المدرس الذكي.';
      }
      return '⚠️ تعذّر الاتصال بخدمة الذكاء الاصطناعي. يرجى التحقق من الاتصال بالإنترنت والمحاولة مجدداً.';
    } catch (e) {
      debugPrint('geminiChat exception: $e');
      return '⚠️ حدث خطأ غير متوقع. يرجى المحاولة مجدداً بعد قليل.';
    }
  }

  // ── Solve from Image via Cloud Function ─────────────────────────────────
  static Future<String> solveFromImage({
    required Uint8List imageBytes,
    required String mediaType,
    required String subject,
    int? grade,
  }) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final result = await _functions.httpsCallable('geminiSolveImage').call({
        'imageBase64': base64Image,
        'mimeType': mediaType,
        'subject': subject,
        'grade': grade,
        'mode': 'solve',
      });
      return (result.data as String?) ?? '';
    } on FirebaseFunctionsException catch (e) {
      debugPrint('geminiSolveImage error: ${e.code} — ${e.message}');
      if (e.code == 'resource-exhausted') {
        return e.message ??
            'لقد تجاوزت الحد المسموح من تحليل الصور. يرجى المحاولة لاحقاً 🕐';
      }
      return 'يرجى المحاولة مرة أخرى بعد قليل للحصول على حل السؤال 🔄';
    } catch (e) {
      debugPrint('geminiSolveImage exception: $e');
      return 'عذراً، حدث خطأ أثناء تحليل الصورة. يرجى المحاولة مجدداً.';
    }
  }

  // ── Grade Assignment via Cloud Function ──────────────────────────────────
  static Future<String> gradeAssignment({
    required Uint8List imageBytes,
    required String mediaType,
    required String subject,
    int? grade,
  }) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final result = await _functions.httpsCallable('geminiSolveImage').call({
        'imageBase64': base64Image,
        'mimeType': mediaType,
        'subject': subject,
        'grade': grade,
        'mode': 'grade',
      });
      return (result.data as String?) ?? '';
    } on FirebaseFunctionsException catch (e) {
      debugPrint('geminiGradeAssignment error: ${e.code} — ${e.message}');
      if (e.code == 'resource-exhausted') {
        return e.message ??
            'لقد تجاوزت الحد المسموح من تصحيح الواجبات. يرجى المحاولة لاحقاً 🕐';
      }
      return 'عذراً، أواجه بعض الضغط الآن 😅. يرجى إعادة المحاولة بعد قليل.';
    } catch (e) {
      debugPrint('geminiGradeAssignment exception: $e');
      return 'عذراً، حدث خطأ. يرجى المحاولة مجدداً.';
    }
  }

  // ── Generate Quiz via Cloud Function ────────────────────────────────────
  static Future<List<Map<String, dynamic>>> generateQuiz({
    required String subject,
    required int grade,
    required List<String> pdfTexts,
    int count = 5,
  }) async {
    try {
      final result = await _functions.httpsCallable('geminiGenerateQuiz').call({
        'subject': subject,
        'grade': grade,
        'pdfTexts': pdfTexts,
        'count': count,
      });
      final data = result.data as Map<String, dynamic>?;
      final questions = data?['questions'];
      if (questions is List) {
        return questions.cast<Map<String, dynamic>>();
      }
      return _fallbackQuiz(subject);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('geminiGenerateQuiz error: ${e.code} — ${e.message}');
      if (e.code == 'resource-exhausted') {
        return [
          {
            'question':
                e.message ?? 'لقد تجاوزت الحد المسموح. يرجى المحاولة لاحقاً 🕐',
            'options': ['حسناً', 'سأحاول لاحقاً', 'شكراً', 'موافق'],
            'correctIndex': 0,
            'explanation': 'يرجى الانتظار قبل إنشاء اختبار جديد.',
          }
        ];
      }
      return _fallbackQuiz(subject);
    } catch (e) {
      debugPrint('geminiGenerateQuiz exception: $e');
      return _fallbackQuiz(subject);
    }
  }

  // ── Smart Summarizer via Cloud Function ─────────────────────────────────
  static Future<String> summarizeContent({
    required String content,
    required String subject,
  }) async {
    try {
      final result = await _functions.httpsCallable('geminiSummarize').call({
        'content': content,
        'subject': subject,
      });
      return (result.data as String?) ?? '';
    } on FirebaseFunctionsException catch (e) {
      debugPrint('geminiSummarize error: ${e.code} — ${e.message}');
      if (e.code == 'resource-exhausted') {
        return e.message ?? 'لقد تجاوزت الحد المسموح. يرجى المحاولة لاحقاً 🕐';
      }
      return 'عذراً، الخوادم مشغولة حالياً 😅. يرجى المحاولة مرة أخرى بعد قليل.';
    } catch (e) {
      debugPrint('geminiSummarize exception: $e');
      return 'عذراً، حدث خطأ أثناء التلخيص. يرجى المحاولة مجدداً.';
    }
  }

  // ── Fallback Quiz ────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _fallbackQuiz(String subject) => [
        {
          'question': 'عذراً، هناك ضغط على الخوادم حالياً.',
          'options': ['أعد المحاولة', 'بعد قليل', 'شكراً', 'لتفهمك'],
          'correctIndex': 0,
          'explanation':
              'يرجى المحاولة مرة أخرى بعد لحظات للحصول على الاختبار.',
        }
      ];
}
