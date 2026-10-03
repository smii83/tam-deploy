import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../../services/app_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

class AITutorScreen extends StatefulWidget {
  final Map<String,String> subject;
  final int grade;
  const AITutorScreen({super.key, required this.subject, required this.grade});
  @override
  State<AITutorScreen> createState() => _AITutorScreenState();
}

class _AITutorScreenState extends State<AITutorScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String,String>> _history = [];
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
    setState(() { _history.add({'role':'user','content':text}); _loading = true; });
    _scrollDown();
    // Send full conversation history (user + assistant) for proper context
    final reply = await AIService.chat(
      subject: _subName, grade: widget.grade,
      history: List.from(_history)..removeLast(), 
      message: text,
      userName: _firstName,
    );
    setState(() { _history.add({'role':'assistant','content':reply}); _loading = false; });
    _scrollDown();
  }


  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeOut
      );
    }
  });

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      body: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1a1035), Color(0xFF3d2b8e)]),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 16, left: 16, right: 16),
          child: Row(children: [
            IconButton(icon: Icon(p.isAr ? Icons.arrow_forward : Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context)),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
                borderRadius: BorderRadius.circular(11)),
              child: Image.asset('assets/images/logo_dark.png', filterQuality: FilterQuality.high),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.askTeacher, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              Row(children: [
                Container(width: 5, height: 5,
                  decoration: const BoxDecoration(color: Color(0xFF38ef7d), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('متاح الآن', style: TextStyle(color: Color(0xFF9b7dff), fontSize: 9)),
              ]),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
              child: Text(_subName, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ),
            if (_history.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70, size: 20),
                onPressed: () => setState(() => _history.clear()),
                tooltip: 'مسح المحادثة',
              ),
          ]),
        ),
        // Chat
        Expanded(
          child: _history.isEmpty
            ? _welcome(p)
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: _history.length + (_loading ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _history.length) return _typingIndicator();
                  final m = _history[i];
                  return _bubble(m['role']!, m['content']!);
                }),
        ),
        // Suggestions
        if (_history.isEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              'اشرح الدرس الأول', 'حل مسألة', 'لخص الفصل', 'أهم القوانين'
            ].map((q) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () { _ctrl.text = q; _send(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border)),
                  child: Text(q, style: const TextStyle(fontSize: 11, color: AppTheme.primary))),
              ))).toList())),
        // Input
        Container(
          padding: EdgeInsets.only(
            left: 12, right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 8, top: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: AppTheme.border))),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(hintText: 'اسأل عن $_subName...'),
            onSubmitted: (_) => _send(),
            )),

            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF9b7dff)]),
                  borderRadius: BorderRadius.circular(50)),
                child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _welcome(AppProvider p) => Center(
    child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🤖', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text('مرحباً! أنا مدرسك الذكي لمادة $_subName',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('اسألني أي سؤال وسأشرح لك 😊',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppTheme.textSec)),
      ])));

  Widget _bubble(String role, String content) {
    final isBot = role == 'assistant';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: isBot ? Theme.of(context).cardColor : AppTheme.primary,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15), topRight: const Radius.circular(15),
                bottomLeft: Radius.circular(isBot ? 4 : 15),
                bottomRight: Radius.circular(isBot ? 15 : 4)),
              boxShadow: isBot ? [BoxShadow(color: AppTheme.primary.withValues(alpha: .08), blurRadius: 8)] : null),
            child: SelectionArea(
              child: Column(crossAxisAlignment: isBot ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                Text(content,
                  style: TextStyle(fontSize: 13, color: isBot ? null : Colors.white, height: 1.6)),
              ]),
            ),
          )),
        ],
      ),
    );
  }

  Widget _typingIndicator() => Row(mainAxisAlignment: MainAxisAlignment.end,
    children: [Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15), topRight: Radius.circular(15),
          bottomLeft: Radius.circular(4), bottomRight: Radius.circular(15))),
      child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) =>
        Container(margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 6, height: 6,
          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: .6 - i*.15),
            borderRadius: BorderRadius.circular(3))))),
    )]);
}
