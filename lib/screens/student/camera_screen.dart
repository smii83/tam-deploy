import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/ai_service.dart';
import '../../services/app_provider.dart';
import '../../utils/app_theme.dart';

class CameraScreen extends StatefulWidget {
  final Map<String, String>? subject;
  final int? grade;
  const CameraScreen({super.key, this.subject, this.grade});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  Uint8List? _imageBytes;
  String? _solution;
  bool _loading = false;
  bool _isGradingMode = false;
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _solution = null;
    });
    await _solve(bytes, xFile.mimeType ?? 'image/jpeg');
  }

  Future<void> _solve(Uint8List bytes, String mimeType) async {
    setState(() => _loading = true);
    final subjectName = widget.subject != null
        ? (context.read<AppProvider>().isAr
            ? widget.subject!['ar']!
            : widget.subject!['en']!)
        : 'الدراسة';

    final answer = _isGradingMode
        ? await AIService.gradeAssignment(
            imageBytes: bytes,
            mediaType: mimeType,
            subject: subjectName,
            grade: widget.grade,
          )
        : await AIService.solveFromImage(
            imageBytes: bytes,
            mediaType: mimeType,
            subject: subjectName,
            grade: widget.grade,
          );
    setState(() {
      _solution = answer;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(p.cameraTitle),
        leading: IconButton(
          // 🔁 RTL-aware: يتكيف تلقائياً مع اتجاه اللغة
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [AppTheme.primary, Color(0xFF9b7dff)]),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Image preview
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border, width: 1.5),
            ),
            child: _imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const Icon(Icons.camera_alt_outlined,
                            size: 48, color: AppTheme.border),
                        const SizedBox(height: 8),
                        Text(p.cameraSub,
                            style: TextStyle(
                                color: AppTheme.textSec, fontSize: 12),
                            textAlign: TextAlign.center),
                      ]),
          ),
          const SizedBox(height: 14),
          // AI Mode Selector
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _modeBtn(p.isAr ? 'حل سريع' : 'Quick Solve', !_isGradingMode,
                () => setState(() => _isGradingMode = false)),
            const SizedBox(width: 12),
            _modeBtn(p.isAr ? 'تصحيح واجب' : 'Grade', _isGradingMode,
                () => setState(() => _isGradingMode = true)),
          ]),
          const SizedBox(height: 16),
          // Buttons
          Row(children: [
            Expanded(
                child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt, size: 18),
              label: Text(p.takePhoto),
              onPressed: () => _pickImage(ImageSource.camera),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(p.uploadPhoto),
              onPressed: () => _pickImage(ImageSource.gallery),
            )),
          ]),
          const SizedBox(height: 16),
          // Loading
          if (_loading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 12),
                Text(p.solving,
                    style: TextStyle(color: AppTheme.textSec, fontSize: 13)),
              ]),
            ),
          // Solution — rendered as Markdown for proper formatting
          if (_solution != null && !_loading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [AppTheme.primary, AppTheme.accent]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.smart_toy_outlined,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(p.solved,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    // ── Markdown renderer for AI responses ────────────────
                    MarkdownBody(
                      data: _solution!,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(
                        Theme.of(context),
                      ).copyWith(
                        p: const TextStyle(fontSize: 13, height: 1.7),
                        h1: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                        h2: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                        h3: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        strong: const TextStyle(fontWeight: FontWeight.w800),
                        code: TextStyle(
                          fontSize: 12,
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ]),
            ),
        ]),
      ),
    );
  }

  Widget _modeBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : AppTheme.textSec,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
