import 'package:screen_protector/screen_protector.dart';
import 'package:flutter/foundation.dart';

class SecurityUtils {
  /// Number of screens currently asking for protection (video, lessons, PDFs…).
  /// Without counting, the first screen to close used to switch protection off for
  /// everyone — and on Android the app-wide FLAG_SECURE set in MainActivity was
  /// cleared too, which is what made the summaries (PDF) screen capturable.
  static int _holds = 0;

  /// Enable FLAG_SECURE on Android + screenshot prevention on iOS
  static Future<void> enableSecureMode() async {
    if (kIsWeb) return;
    _holds++;
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (_) {}
  }

  /// Release one protection hold. Android keeps FLAG_SECURE for the whole app
  /// (MainActivity.kt sets it on purpose), so only iOS is switched off, and only
  /// when no other protected screen is still open.
  static Future<void> disableSecureMode() async {
    if (kIsWeb) return;
    if (_holds > 0) _holds--;
    if (_holds > 0) return;
    if (defaultTargetPlatform == TargetPlatform.android) return;
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (_) {}
  }
}
