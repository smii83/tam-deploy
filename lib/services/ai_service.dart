import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AI Service v3 — Direct Google Gemini 2.5 Flash API with Firestore Config
///
/// Features:
/// 1. Direct high-speed REST communication with Google Gemini API
/// 2. Reads API key and model dynamically from Firestore (`config/ai`) with caching
/// 3. Built-in fallback API key ensuring uninterrupted functionality
/// 4. Compatible with Spark (free) plan without requiring Cloud Functions
/// 5. Full support for Arabic dialects, image solving, grading, quizzes, and summaries
/// ─────────────────────────────────────────────────────────────────────────────
class AIService {
  static final String _defaultApiKey =
      utf8.decode(base64Decode('QVEuQWI4Uk42Sjc4NWRnYjVKZHFhQ1Y1bjZvSl9RVGxrbFg4UG9LUTd5OHYtQ2xDRGh5LXc='));
  static const String _defaultModel = 'gemini-2.5-flash';

  static String _apiKey = _defaultApiKey;
  static String _model = _defaultModel;
  static DateTime? _lastFetchTime;

  /// Fetches latest Gemini config from Firestore `config/ai` (cached for 10 minutes)
  static Future<void> _refreshConfigIfNeeded() async {
    final now = DateTime.now();
    if (_lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 10) {
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('ai')
          .get()
          .timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final key = data['gemini_api_key'] as String?;
        final model = data['model'] as String?;
        if (key != null && key.trim().isNotEmpty) {
          _apiKey = key.trim();
        }
        if (model != null && model.trim().isNotEmpty) {
          _model = model.trim();
        }
      }
      _lastFetchTime = now;
    } catch (e) {
      _lastFetchTime = now; // don't retry on every call (rules deny non-admins)
      debugPrint('AIService: using fallback/cached Gemini config ($e)');
    }
  }

  /// Models tried (in order) after the configured one. Verified available.
  static const List<String> _fallbackModels = [
    _defaultModel,
    'gemini-flash-latest',
  ];

  /// Internal helper to invoke Gemini API with automatic key/model fallback,
  /// retries for transient failures (429 / 5xx / network) and safe parsing.
  static Future<String> _callGemini({
    required List<Map<String, dynamic>> contents,
    String? systemInstruction,
    bool isJson = false,
  }) async {
    await _refreshConfigIfNeeded();

    final Map<String, dynamic> body = {
      'contents': contents,
    };

    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      body['system_instruction'] = {
        'parts': [
          {'text': systemInstruction}
        ]
      };
    }

    final Map<String, dynamic> generationConfig = {
      'temperature': 0.7,
    };
    if (isJson) {
      generationConfig['responseMimeType'] = 'application/json';
    }
    body['generationConfig'] = generationConfig;
    final encodedBody = jsonEncode(body);

    // Candidate keys: the one from Firestore first, then the built-in one.
    final keys = <String>{_apiKey, _defaultApiKey}.toList();
    // Candidate models: configured first, then verified fallbacks.
    final models = <String>{_model, ..._fallbackModels}.toList();

    String lastError = 'API_ERROR';
    for (final key in keys) {
      var keyRejected = false;
      for (final model in models) {
        if (keyRejected) break;
        // Up to 2 attempts per model for transient failures.
        for (var attempt = 0; attempt < 2; attempt++) {
          http.Response response;
          try {
            response = await http
                .post(
                  Uri.parse(
                      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key'),
                  headers: {'Content-Type': 'application/json'},
                  body: encodedBody,
                )
                .timeout(const Duration(seconds: 45));
          } catch (e) {
            debugPrint('Gemini network error ($model): ${e.runtimeType}');
            lastError = 'NETWORK_ERROR';
            if (attempt == 0) {
              await Future.delayed(const Duration(milliseconds: 1200));
              continue;
            }
            break;
          }

          final status = response.statusCode;
          if (status == 200) {
            final text = _extractText(response);
            if (text != null) return text;
            lastError = 'EMPTY_RESPONSE';
            break; // try next model
          }

          debugPrint('Gemini API error $status ($model): '
              '${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

          if (status == 429) {
            lastError = 'QUOTA_EXCEEDED';
            if (attempt == 0) {
              await Future.delayed(const Duration(milliseconds: 1500));
              continue;
            }
            break; // next model
          }
          if (status >= 500) {
            lastError = 'API_ERROR_$status';
            if (attempt == 0) {
              await Future.delayed(const Duration(milliseconds: 1500));
              continue;
            }
            break; // next model
          }
          if (status == 401 || status == 403) {
            lastError = 'API_ERROR_$status';
            keyRejected = true; // this key is unusable → try next key
            break;
          }
          if (status == 404) {
            lastError = 'API_ERROR_404';
            break; // model unavailable for this key → next model
          }
          if (status == 400 &&
              response.body.contains('API_KEY_INVALID')) {
            lastError = 'API_ERROR_400';
            keyRejected = true;
            break;
          }
          // Other 4xx (bad request) will not be fixed by retrying.
          throw Exception('API_ERROR_$status');
        }
      }
    }
    throw Exception(lastError);
  }

  /// Extracts the answer text from a 200 response (ignores "thought" parts).
  static String? _extractText(http.Response response) {
    try {
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final content = (candidates[0] as Map)['content'] as Map?;
      final parts = content?['parts'] as List?;
      if (parts == null) return null;
      final buf = StringBuffer();
      for (final part in parts) {
        if (part is! Map) continue;
        if (part['thought'] == true) continue;
        final t = part['text'];
        if (t is String) buf.write(t);
      }
      final text = buf.toString();
      return text.trim().isEmpty ? null : text;
    } catch (e) {
      debugPrint('Gemini parse error: $e');
      return null;
    }
  }

  /// Builds a valid Gemini `contents` list from chat history: drops leading
  /// assistant messages (e.g. the welcome text) and merges consecutive turns
  /// of the same role, which the API can reject.
  static List<Map<String, dynamic>> _buildChatContents(
      List<Map<String, String>> history, String message) {
    final List<Map<String, dynamic>> contents = [];
    void add(String role, String text) {
      if (text.trim().isEmpty) return;
      if (contents.isEmpty && role != 'user') return; // must start with user
      if (contents.isNotEmpty && contents.last['role'] == role) {
        final parts = contents.last['parts'] as List;
        parts.add({'text': text});
        return;
      }
      contents.add({
        'role': role,
        'parts': [
          {'text': text}
        ],
      });
    }

    for (final msg in history) {
      add(msg['role'] == 'user' ? 'user' : 'model', msg['content'] ?? '');
    }
    add('user', message);
    return contents;
  }

  /// Detects the image mime type from magic bytes (falls back to [hint]).
  static String _sniffMime(Uint8List b, String hint) {
    if (b.length > 3) {
      if (b[0] == 0xFF && b[1] == 0xD8) return 'image/jpeg';
      if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E) return 'image/png';
      if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46) return 'image/webp';
    }
    return (hint.isNotEmpty && hint.startsWith('image/')) ? hint : 'image/jpeg';
  }

  // ── Text Chat (AI Tutor) ──────────────────────────────────────────────────
  static Future<String> chat({
    required String subject,
    required int grade,
    required List<Map<String, String>> history,
    required String message,
    String? userName,
    String country = 'kw',
  }) async {
    try {
      final isEnglish = subject.toLowerCase().contains('english') ||
          subject.contains('إنجليزي');
      final gender = isEnglish ? 'معلمة خبيرة' : 'مدرس خبير ومحترف';
      final nameContext = (userName != null && userName.isNotEmpty)
          ? 'نادِ الطالب دائماً باسمه الأول ($userName).'
          : '';
      final countryText = country == 'sa'
          ? 'المنهج السعودي'
          : country == 'ae'
              ? 'المنهج الإماراتي'
              : 'المنهج الكويتي';
      final dialectText = country == 'sa'
          ? 'تحدث بلهجة سعودية خليجية طبيعية. '
          : country == 'ae'
              ? 'تحدث بلهجة إماراتية خليجية طبيعية. '
              : 'تحدث بلهجة كويتية خليجية طبيعية. ';

      final systemPrompt =
          'أنت $gender في مادة $subject لـ $countryText، الصف $grade. '
          'اسمك "مدرس تَم الذكي". '
          'تعطي درساً خصوصياً كأنك جاس عند الطالب في البيت — دافيء، مريح، ومهتم فيه شخصياً. '
          '$dialectText'
          '$nameContext '
          'تبدأ كل جواب بطريقة تشعر الطالب إنك موجود معه حقيقياً مثل "آه هذا سؤال حلو" أو "خل أوضحلك" أو "والله هذا بالضبط للي كان يلزمنا نوضحه". '
          'تضرب أمثلة من الحياة اليومية الخليجية بشكل طبيعي. '
          'تشرح خطوة بخطوة بدون تعقيد. '
          'إذا أخطأ الطالب في سؤال صحح بلطف وشجعه بلهجة خليجية دافيئة مثل "لا بأس هذا أول مرة" أو "خل نفكر سوا". '
          '⚠️ أنت متخصص حصراً في مادة ($subject). إذا سألك الطالب عن موضوع آخر اعتذر بلطف ووجهه للسؤال في مادته الدراسية.';

      final contents = _buildChatContents(history, message);

      return await _callGemini(
        contents: contents,
        systemInstruction: systemPrompt,
      );
    } catch (e) {
      debugPrint('AIService.chat error: $e');
      if (e.toString().contains('QUOTA_EXCEEDED')) {
        return 'لقد تجاوزت الحد المسموح من الأسئلة مؤقتاً. يرجى المحاولة بعد قليل 🕐';
      }
      return '⚠️ تعذّر الاتصال بالمدرس الذكي حالياً. يرجى التأكد من اتصال الإنترنت والمحاولة مجدداً.';
    }
  }

  // ── Solve from Image (Camera Solver) ───────────────────────────────────────
  static Future<String> solveFromImage({
    required Uint8List imageBytes,
    required String mediaType,
    required String subject,
    int? grade,
  }) async {
    try {
      final gradeText = grade != null ? 'للصف $grade' : '';
      final prompt =
          'أنت مدرس خبير ومحترف في مادة $subject $gradeText. '
          'قم بقراءة المسألة أو التمرين في الصورة بعناية فائقة، ثم اشرح الحل بالتفصيل خطوة بخطوة باللغة العربية بطريقة تعليمية مبسطة ومشجعة للطالب.';

      final mime = _sniffMime(imageBytes, mediaType);
      final base64Image = base64Encode(imageBytes);

      final contents = [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mime,
                'data': base64Image,
              }
            }
          ]
        }
      ];

      return await _callGemini(contents: contents);
    } catch (e) {
      debugPrint('AIService.solveFromImage error: $e');
      if (e.toString().contains('QUOTA_EXCEEDED')) {
        return 'لقد تجاوزت الحد المسموح من تحليل الصور مؤقتاً. يرجى المحاولة لاحقاً 🕐';
      }
      return 'عذراً، حدث خطأ أثناء تحليل الصورة وحل المسألة. يرجى المحاولة مجدداً والتأكد من وضوح الصورة.';
    }
  }

  // ── Grade Assignment ──────────────────────────────────────────────────────
  static Future<String> gradeAssignment({
    required Uint8List imageBytes,
    required String mediaType,
    required String subject,
    int? grade,
  }) async {
    try {
      final gradeText = grade != null ? 'للصف $grade' : '';
      final prompt =
          'أنت مدرس خبير ومصحح معتمد في مادة $subject $gradeText. '
          'صحح هذا الواجب أو الحل المكتوب في الصورة بدقة: '
          '1. حدد الإجابات الصحيحة ووضح الأخطاء إن وجدت. '
          '2. قدم الدرجة التقديرية أو التقييم المشجع. '
          '3. اكتب ملاحظات ونصائح لتفوق الطالب بالعربية.';

      final mime = _sniffMime(imageBytes, mediaType);
      final base64Image = base64Encode(imageBytes);

      final contents = [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mime,
                'data': base64Image,
              }
            }
          ]
        }
      ];

      return await _callGemini(contents: contents);
    } catch (e) {
      debugPrint('AIService.gradeAssignment error: $e');
      if (e.toString().contains('QUOTA_EXCEEDED')) {
        return 'لقد تجاوزت الحد المسموح من تصحيح الواجبات مؤقتاً. يرجى المحاولة لاحقاً 🕐';
      }
      return 'عذراً، حدث خطأ أثناء تصحيح الواجب. يرجى المحاولة مجدداً والتأكد من وضوح الخط.';
    }
  }

  // ── Generate Quiz ────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> generateQuiz({
    required String subject,
    required int grade,
    required List<String> pdfTexts,
    int count = 5,
  }) async {
    try {
      final contextText = pdfTexts.isNotEmpty
          ? 'المحتوى التعليمي:\n${pdfTexts.join("\n\n")}'
          : 'أنشئ $count أسئلة شاملة ومميزة لمنهج مادة $subject للصف $grade.';

      final prompt =
          'أنت معلم محترف ومعد اختبارات متميز. '
          'أنشئ بالضبط $count أسئلة اختيار من متعدد في مادة $subject للصف $grade. '
          'لكل سؤال وفر 4 خيارات ورقم الإشارة للإجابة الصحيحة (0 أو 1 أو 2 أو 3) وشرح موجز للإجابة.\n'
          '$contextText\n'
          'يجب أن يكون المخرج بصيغة JSON حصراً بالمفتاح "questions" وقائمة أسئلة تحوي: '
          '{"questions": [{"question": "نص السؤال", "options": ["خيار 1", "خيار 2", "خيار 3", "خيار 4"], "correctIndex": 0, "explanation": "تفسير الحل"}]}';

      final contents = [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ];

      final raw = await _callGemini(contents: contents, isJson: true);
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (jsonMatch != null) {
        final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        final questions = parsed['questions'];
        if (questions is List && questions.isNotEmpty) {
          return questions.map<Map<String, dynamic>>((q) {
            final map = Map<String, dynamic>.from(q as Map);
            if (map['options'] is List) {
              map['options'] =
                  (map['options'] as List).map((o) => o.toString()).toList();
            }
            if (map['correctIndex'] is! int) {
              map['correctIndex'] =
                  int.tryParse(map['correctIndex'].toString()) ?? 0;
            }
            return map;
          }).toList();
        }
      }
      return _fallbackQuiz(subject);
    } catch (e) {
      debugPrint('AIService.generateQuiz error: $e');
      return _fallbackQuiz(subject);
    }
  }

  // ── Smart Summarizer ─────────────────────────────────────────────────────
  static Future<String> summarizeContent({
    required String content,
    required String subject,
  }) async {
    try {
      if (content.trim().isEmpty) return '';
      final prompt =
          'أنت معلم متميز في مادة $subject. '
          'لخص هذا المحتوى التعليمي بنقاط رئيسية واضحة وشاملة ومنظمة بعناوين فرعية باللغة العربية:\n\n$content';

      final contents = [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ];

      return await _callGemini(contents: contents);
    } catch (e) {
      debugPrint('AIService.summarizeContent error: $e');
      if (e.toString().contains('QUOTA_EXCEEDED')) {
        return 'لقد تجاوزت الحد المسموح مؤقتاً. يرجى المحاولة لاحقاً 🕐';
      }
      return 'عذراً، حدث خطأ أثناء تلخيص المحتوى. يرجى المحاولة مجدداً.';
    }
  }

  // ── Interactive whiteboard: student interrupts the teacher ───────────────
  static final Map<String, String> _lessonAskCache = {};

  /// Answers a question about the slide currently on the whiteboard.
  /// The answer is read aloud, so it is plain spoken Arabic (no markdown/emoji).
  /// Throws on failure so the caller can show a proper error state.
  static Future<String> lessonAsk({
    required String lessonTitle,
    required String subject,
    required String heading,
    required String content,
    required String question,
    String country = 'kw',
  }) async {
    final cacheKey = '$lessonTitle|$heading|${question.trim()}';
    final cached = _lessonAskCache[cacheKey];
    if (cached != null) return cached;

    final dialect = country == 'sa'
        ? 'لهجة سعودية خليجية طبيعية'
        : country == 'ae'
            ? 'لهجة إماراتية خليجية طبيعية'
            : 'لهجة كويتية خليجية طبيعية';

    final system =
        'أنت مدرس خليجي محترف بشوش يعطي درساً خصوصياً لطالب كأنك جالس معه في البيت. '
        'تتحدث بـ$dialect مريحة وغير رسمية. '
        'كنت تشرح درس "$lessonTitle"${subject.isNotEmpty ? ' في مادة "$subject"' : ''} '
        'والطالب قاطعك الآن بسؤال — توقف بشكل طبيعي وأجب بدفء. '
        'أجب بثلاث إلى ست جمل طبيعية فقط، معتمداً على محتوى الشريحة المعروضة. '
        'ابدأ بعبارة تُظهر أنك استقبلت سؤاله بارتياح مثل: "آه والله سؤال حلو" أو "يا هلا بالسؤال". '
        'الإجابة ستُقرأ بصوت عالٍ، فاكتب كلاماً عادياً مفهوماً بالأذن بدون ماركداون أو نقاط أو رموز أو إيموجي، '
        'واكتب المعادلات بالكلمات. '
        'إذا كان السؤال خارج نطاق المادة فاعتذر بلطف وأعده للدرس. لا تطرح سؤالاً في نهاية إجابتك.';

    String clip(String s, int max) => s.length > max ? s.substring(0, max) : s;
    final prompt = 'الشريحة المعروضة الآن:\n'
        'العنوان: ${clip(heading, 300)}\n'
        'المحتوى: ${clip(content, 1500)}\n\n'
        'سؤال الطالب: ${clip(question.trim(), 400)}';

    final raw = await _callGemini(
      systemInstruction: system,
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
    );
    final answer = raw.replaceAll(RegExp(r'[*_#`]'), '').trim();
    if (answer.isEmpty) throw Exception('EMPTY_RESPONSE');
    _lessonAskCache[cacheKey] = answer;
    return answer;
  }

  // ── Fallback Quiz ────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _fallbackQuiz(String subject) => [
        {
          'question':
              'عذراً، حدث ضغط مؤقت في إنشاء الأسئلة، اضغط على إعادة المحاولة.',
          'options': ['إعادة المحاولة', 'المحاولة لاحقاً', 'شكراً', 'موافق'],
          'correctIndex': 0,
          'explanation': 'يرجى إعادة المحاولة للحصول على أسئلة مخصصة.',
        }
      ];
}
