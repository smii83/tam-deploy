import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../utils/security.dart';
import '../../utils/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final Color themeColor;

  const VideoPlayerScreen({
    super.key,
    required this.url,
    required this.title,
    required this.themeColor,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    SecurityUtils.enableSecureMode();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _videoPlayerController.initialize();

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: widget.themeColor,
          handleColor: widget.themeColor,
          backgroundColor: Colors.grey,
          bufferedColor: widget.themeColor.withValues(alpha: .3),
        ),
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
        errorBuilder: (context, errorMessage) => _errorWidget(errorMessage),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'تعذّر تحميل الفيديو. يرجى التحقق من الاتصال والمحاولة مرة أخرى.';
      });
    }
  }

  /// Retry loading after an error
  Future<void> _retry() async {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    _chewieController?.dispose();
    _chewieController = null;
    try {
      await _videoPlayerController.dispose();
    } catch (_) {}
    await _initializePlayer();
  }

  Widget _errorWidget([String? msg]) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 64),
            const SizedBox(height: 16),
            Text(
              msg ?? _errorMessage,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, fontFamily: 'Cairo'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    SecurityUtils.disableSecureMode();
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        title: Text(widget.title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo')),
      ),
      body: Center(
        child: _hasError
            ? _errorWidget()
            : (_chewieController != null &&
                    _chewieController!
                        .videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: widget.themeColor),
                      const SizedBox(height: 16),
                      const Text('جاري تجهيز الدرس...',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontFamily: 'Cairo')),
                    ],
                  )),
      ),
    );
  }
}
