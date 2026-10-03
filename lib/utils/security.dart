import 'package:screen_protector/screen_protector.dart';
import 'package:flutter/foundation.dart';

class SecurityUtils {
  /// Enable FLAG_SECURE on Android + screenshot prevention on iOS
  static Future<void> enableSecureMode() async {
    if (kIsWeb) return;
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (_) {}
  }

  /// Disable screen protection
  static Future<void> disableSecureMode() async {
    if (kIsWeb) return;
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (_) {}
  }
}
