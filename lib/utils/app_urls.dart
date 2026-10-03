/// ══════════════════════════════════════════════════════════════
/// App URLs — جميع الروابط الخارجية في مكان واحد
/// لتغيير الدومين مستقبلاً، عدّل [_baseUrl] فقط.
/// ══════════════════════════════════════════════════════════════
class AppUrls {
  AppUrls._();

  // ── Base URL ────────────────────────────────────────────────
  /// الموقع الرسمي للمنصة
  static const String website    = 'https://www.tamlearn.com';

  /// البريد الإلكتروني للدعم الفني
  static const String supportEmail = 'support@codecore.llc';

  /// نطاق الصفحات القانونية (الموقع الرسمي)
  static const String _legalBase = 'https://www.tamlearn.com';

  // ── Legal Pages ─────────────────────────────────────────────
  static const String privacyPolicy = '$_legalBase/privacy.html';
  static const String termsOfUse    = '$_legalBase/terms.html';

  // ── Stores ──────────────────────────────────────────────────
  /// حدّث هذا بعد نشر التطبيق على App Store
  static const String appStore   = 'https://apps.apple.com/app/id0000000000';

  /// حدّث هذا بعد نشر التطبيق على Google Play
  static const String googlePlay = 'https://play.google.com/store/apps/details?id=com.tam.app';
}
