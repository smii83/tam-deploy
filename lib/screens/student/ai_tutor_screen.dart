import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../../services/app_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_pressable.dart';

class AITutorScreen extends StatefulWidget {
  final Map<String, String> subject;
  final int grade;
  const AITutorScreen({super.key, required this.subject, required this.grade});
  @override
  State<AITutorScreen> createState() => _AITutorScreenState();
}

class _AITutorScreenState extends State<AITutorScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _history = [];
  bool _loading = false;
  String _firstName = '';

  @override
  void initState() {
    super.initState();

    // Fetch user name and send welcome
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthService>(context, listen: false);
      final fullName = await auth.getUserName();
      if (fullName.isNotEmpty) {
        setState(() => _firstName = fullName.split(' ').first);
      }
      _sendWelcomeMessage();
    });
  }

  Future<void> _sendWelcomeMessage() async {
    final p = Provider.of<AppProvider>(context, listen: false);
    final sub = widget.subject['en']?.toLowerCase() ?? '';
    final isAr = p.isAr;
    final namePart = _firstName.isNotEmpty ? ' يا $_firstName' : '';

    String welcomeText = '';
    if (sub.contains('math') || sub.contains('رياضيات')) {
      welcomeText = isAr
          ? 'هلا والله$namePart، أنا مدرس الرياضيات الخاص فيك في منصة تَم. شلون أقدر أساعدك اليوم في الأرقام والقوانين؟'
          : 'Welcome$namePart! I am your Math teacher. How can I help you today?';
    } else if (sub.contains('english') || sub.contains('إنجليزي')) {
      welcomeText = isAr
          ? 'Welcome$namePart! أنا معلمتك للغة الإنجليزية، وراح نتقن اللغة مع بعض بلهجتنا الكويتية الحلوة، شنو ودك نتعلم اليوم؟'
          : 'Welcome$namePart! I am your English teacher. Let\'s master the language together!';
    } else {
      welcomeText = isAr
          ? 'يا هلا فيك$namePart، أنا مدرسك الذكي لمادة $_subName. أنا موجود هنا عشان أسهل عليك المادة وأجاوب على كل أسئلتك.'
          : 'Hello$namePart! I am your smart tutor for $_subName. I am here to help you!';
    }

    setState(() {
      _history.add({'role': 'assistant', 'content': welcomeText});
    });
  }

  String get _subName {
    final p = Provider.of<AppProvider>(context, listen: false);
    return p.isAr ? widget.subject['ar']! : widget.subject['en']!;
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    _ctrl.clear();
    setState(() {
      _history.add({'role': 'user', 'content': text});
      _loading = true;
    });
    _scrollDown();
    // Send full conversation history (user + assistant) for proper context
    final countryCode = Provider.of<AppProvider>(context, listen: false).selectedCountry;
    final reply = await AIService.chat(
      subject: _subName,
      grade: widget.grade,
      history: List.from(_history)..removeLast(),
      message: text,
      userName: _firstName,
      country: countryCode,
    );
    setState(() {
      _history.add({'role': 'assistant', 'content': reply});
      _loading = false;
    });
    _scrollDown();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      });

  Color _toCalmColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 1.1).clamp(0.75, 0.90))
        .withLightness((hsl.lightness * 0.9).clamp(0.50, 0.60))
        .toColor();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isDark = p.isDark;
    final rawColor = AppTheme.parseColor(widget.subject["color"] ?? "6C63FF");
    final subjectColor = _toCalmColor(rawColor);
    final baseBg = Theme.of(context).scaffoldBackgroundColor;

    final cardBgStart = Color.lerp(
      baseBg,
      subjectColor,
      isDark ? 0.60 : 0.42,
    )!;
    final cardBgEnd = Color.lerp(
      baseBg,
      subjectColor,
      isDark ? 0.28 : 0.16,
    )!;

    return Scaffold(
      backgroundColor: baseBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.bgGradientFor(p.themeId, isDark),
        ),
        child: Column(
        children: [
          // Premium Floating Header Card
          SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [cardBgStart, cardBgEnd],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: subjectColor.withValues(alpha: isDark ? 0.45 : 0.30),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: subjectColor.withValues(alpha: isDark ? 0.22 : 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  AnimatedPressable(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : subjectColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: subjectColor.withValues(
                              alpha: isDark ? 0.45 : 0.26),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        p.isAr
                            ? Icons.arrow_forward_rounded
                            : Icons.arrow_back_rounded,
                        size: 20,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                          baseBg, subjectColor, isDark ? 0.42 : 0.24)!,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: subjectColor.withValues(
                            alpha: isDark ? 0.55 : 0.35),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.subject['em'] ?? '🤖',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          p.askTeacher,
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1A2E),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Cairo',
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF38ef7d),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.isAr ? 'متصل الآن' : 'Online',
                              style: const TextStyle(
                                color: Color(0xFF38ef7d),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Subject name badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                          baseBg, subjectColor, isDark ? 0.35 : 0.16)!,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: subjectColor.withValues(
                            alpha: isDark ? 0.40 : 0.22),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      _subName,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.9)
                            : subjectColor.withValues(alpha: 0.95),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                  if (_history.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    AnimatedPressable(
                      onTap: () => setState(() => _history.clear()),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.delete_sweep_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Chat View
          Expanded(
            child: _history.isEmpty
                ? _welcome(p, subjectColor)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _history.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _history.length) return _typingIndicator(p);
                      final m = _history[i];
                      return _bubble(m['role']!, m['content']!, p);
                    }),
          ),
          // Suggestions
          if (_history.isEmpty) _buildSuggestions(p, subjectColor),
          // Floating Input Panel
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            color: Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.20 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: TextField(
                        controller: _ctrl,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A2E),
                          fontFamily: 'Cairo',
                        ),
                        decoration: InputDecoration(
                          hintText: p.isAr
                              ? 'اسأل عن $_subName...'
                              : 'Ask about $_subName...',
                          hintStyle: TextStyle(
                            color: AppTheme.textSec.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontFamily: 'Cairo',
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedPressable(
                  onTap: _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          subjectColor,
                          subjectColor.withValues(alpha: 0.8)
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: subjectColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Transform.scale(
                        scaleX: p.isAr ? -1 : 1,
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildSuggestions(AppProvider p, Color subjectColor) {
    final isDark = p.isDark;

    final list = p.isAr
        ? [
            'اشرح الدرس الأول 📖',
            'حل مسألة تطبيقية ✏️',
            'لخص الفصل الأول 📝',
            'أهم القوانين والتعاريف 💡'
          ]
        : [
            'Explain the first lesson 📖',
            'Solve a practice problem ✏️',
            'Summarize chapter one 📝',
            'Key formulas and terms 💡'
          ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: list.map((q) {
          final cleanQ = q
              .replaceAll(
                  RegExp(r'[\u2000-\u32FF]|[\uD83C-\uDBFF][\uDC00-\uDFFF]'), '')
              .trim();
          return Padding(
            padding: EdgeInsets.only(
              left: p.isAr ? 0 : 8,
              right: p.isAr ? 8 : 0,
            ),
            child: AnimatedPressable(
              onTap: () {
                _ctrl.text = cleanQ;
                _send();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: subjectColor.withValues(alpha: isDark ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: subjectColor.withValues(alpha: isDark ? 0.35 : 0.15),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          subjectColor.withValues(alpha: isDark ? 0.05 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  q,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFE2E2E9) : subjectColor,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _welcome(AppProvider p, Color subjectColor) {
    final isDark = p.isDark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: subjectColor.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: subjectColor.withValues(alpha: isDark ? 0.35 : 0.18),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: subjectColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.subject['em'] ?? '🤖',
                  style: const TextStyle(fontSize: 44),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              p.isAr
                  ? 'مرحباً بك مع معلمك الذكي لمادة $_subName'
                  : 'Welcome with your smart tutor for $_subName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                fontFamily: 'Cairo',
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              p.isAr
                  ? 'اسألني أي سؤال في المادة وسأقوم بشرحه وتوضيحه لك خطوة بخطوة بكل سهولة!'
                  : 'Ask me any question in the subject and I will explain it step by step!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSec,
                fontFamily: 'Cairo',
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(String role, String content, AppProvider p) {
    final isDark = p.isDark;
    final isBot = role == 'assistant';
    final rawColor = AppTheme.parseColor(widget.subject["color"] ?? "6C63FF");
    final subjectColor = _toCalmColor(rawColor);

    final baseBotBg = isDark ? const Color(0xFF1C1C28) : Colors.white;
    final botBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBot) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  subjectColor,
                  subjectColor.withValues(alpha: 0.7)
                ]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: subjectColor.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.subject['em'] ?? '🤖',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isBot
                    ? null
                    : const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFF9B7DFF)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                color: isBot ? baseBotBg : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isBot ? 4 : 20),
                  bottomRight: Radius.circular(isBot ? 20 : 4),
                ),
                border: isBot
                    ? Border.all(color: botBorderColor, width: 1.5)
                    : Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        width: 1),
                boxShadow: [
                  BoxShadow(
                    color: (isBot ? subjectColor : AppTheme.primary)
                        .withValues(alpha: isDark ? 0.08 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SelectionArea(
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isBot
                        ? (isDark
                            ? const Color(0xFFE2E2E9)
                            : const Color(0xFF2C2C3E))
                        : Colors.white,
                    height: 1.6,
                    fontFamily: 'Cairo',
                    fontWeight: isBot ? FontWeight.w600 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3), width: 1),
              ),
              child: const Center(
                child: Text(
                  '🎓',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _typingIndicator(AppProvider p) {
    final isDark = p.isDark;
    final rawColor = AppTheme.parseColor(widget.subject["color"] ?? "6C63FF");
    final subjectColor = _toCalmColor(rawColor);

    final baseBotBg = isDark ? const Color(0xFF1C1C28) : Colors.white;
    final botBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [subjectColor, subjectColor.withValues(alpha: 0.7)]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.subject['em'] ?? '🤖',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: baseBotBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: botBorderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: subjectColor.withValues(alpha: isDark ? 0.08 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: subjectColor.withValues(alpha: 0.7 - i * 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
