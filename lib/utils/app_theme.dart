import 'package:flutter/material.dart';

// ── Layout Enum — كل ثيم له هيكل grid مختلف كلياً ──────────────────────────
enum AppThemeLayout {
  standard, // Deep Space / TAM Indigo / Arctic Glass — 3 أعمدة عادية
  bubble,   // Sakura Dream — 2 أعمدة فقاعية كبيرة
  fluent,   // Win Flux — 2 أعمدة مستطيلات Windows 11
}

// ── Card Style Enum — كل ثيم له تصميم بطاقة مختلف كليًا ─────────────────────
enum AppCardStyle {
  vivid,   // Deep Space — الحالي بلا تغيير
  indigo,  // TAM Indigo — هوية الموقع الرسمية
  sakura,  // Sakura Dream — وردي بنفسجي بناتي
  win,     // Win Flux — Microsoft Fluent Design
  arctic,  // Arctic Glass — جليدي + شفاف
  platinum,// Platinum Minimal — بلاتينوم ناصع ورمادي فحمي (Chrome Dark)
}

// ── Theme Enum ────────────────────────────────────────────────────────────────
enum AppThemeId {
  deepSpace,   // 1 — الأصلي (لا يتغير أبداً)
  tamIndigo,   // 2 — TAM Indigo (هوية tamlearn.com)
  sakuraDream, // 3 — Sakura Dream (وردي بنفسجي بناتي)
  winFlux,     // 4 — Win Flux (Microsoft Fluent Design 2026)
  arcticGlass, // 5 — Arctic Glass (Apple visionOS)
  platinumMinimal, // 6 — Platinum Minimal (Chrome Slate Charcoal)
}

// ── Theme Meta ────────────────────────────────────────────────────────────────
class AppThemeMeta {
  final AppThemeId id;
  final String nameAr;
  final String nameEn;
  final String emoji;
  final Color primary;
  final Color darkBg;
  final Color lightBg;
  final List<Color> gradColors;

  const AppThemeMeta({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.emoji,
    required this.primary,
    required this.darkBg,
    required this.lightBg,
    required this.gradColors,
  });
}

/// TAM Visual Identity — Multi-Theme System v8 (2026 Design Trends)
class AppTheme {
  // ── Safe Hex Color Parser ──────────────────────────────────────────────────
  static Color parseColor(String? hexColor, {Color fallback = const Color(0xFF7C3AED)}) {
    if (hexColor == null || hexColor.trim().isEmpty) return fallback;
    try {
      String clean = hexColor.trim().replaceAll('#', '');
      if (clean.length == 6) {
        clean = 'FF$clean';
      }
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  THEME 1 — Deep Space (الثيم الأصلي — لا يتغير أبداً)
  // ══════════════════════════════════════════════════════════════════════════
  static const Color primary      = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFF9F67FF);
  static const Color primaryDeep  = Color(0xFF5B21B6);
  static const Color accent       = Color(0xFF06B6D4);
  static const Color accentDeep   = Color(0xFF0891B2);
  static const Color rose         = Color(0xFFEC4899);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color gold     = Color(0xFFF59E0B);
  static const Color goldDeep = Color(0xFFD97706);

  static const Color textPri   = Color(0xFF0F0F23);
  static const Color textSec   = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color surfaceLight    = Color(0xFFF5F3FF);
  static const Color surfaceCard     = Color(0xFFFFFFFF);
  static const Color border          = Color(0xFFEDE9FE);

  static const Color surfaceDark     = Color(0xFF0D0D1F);
  static const Color surfaceCardDark = Color(0xFF161629);
  static const Color surfaceElevated = Color(0xFF1E1E35);
  static const Color borderDark      = Color(0xFF2D2B52);

  static const LinearGradient primaryGrad = LinearGradient(
    colors: [primaryLight, primaryDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroBgLight = LinearGradient(
    colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE), Color(0xFFF0F9FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroBgDark = LinearGradient(
    colors: [Color(0xFF0D0D1F), Color(0xFF111126), Color(0xFF0D1A2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient welcomeGradLight = LinearGradient(
    colors: [Color(0xFFEDE9FE), Color(0xFFE0F2FE), Color(0xFFFDF4FF)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
  static const LinearGradient welcomeGradDark = LinearGradient(
    colors: [Color(0xFF1E1630), Color(0xFF0E1E30)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
  static const LinearGradient auroraGrad = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldGrad = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => [];
  static List<BoxShadow> get glowShadow => [];
  static List<BoxShadow> get accentGlowShadow => [];
  static List<BoxShadow> get goldGlowShadow => [];
  static List<BoxShadow> get premiumShadow => [];

  static BoxDecoration glass({
    required Color color,
    double opacity = 0.10,
    double blur = 12,
    double radius = 24,
    bool darkMode = false,
  }) => BoxDecoration(
    color: color.withValues(alpha: opacity),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: (darkMode ? Colors.white : color).withValues(alpha: darkMode ? 0.10 : 0.18),
      width: 1.2,
    ),
  );

  // ── Theme 1: Deep Space Light (unchanged) ────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    brightness: Brightness.light,
    scaffoldBackgroundColor: surfaceLight,
    cardColor: surfaceCard,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary, brightness: Brightness.light,
      primary: primary, secondary: accent, surface: surfaceLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceLight, foregroundColor: textPri, elevation: 0, centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: textPri),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: primary, foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0, shadowColor: primary.withValues(alpha: 0.35),
      textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w800),
    )),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: surfaceCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primary, width: 2)),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14, fontFamily: 'Cairo'),
    ),
  );

  // ── Theme 1: Deep Space Dark (unchanged) ─────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: surfaceDark,
    cardColor: surfaceCardDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary, brightness: Brightness.dark,
      primary: primaryLight, secondary: accent, surface: surfaceDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceDark, foregroundColor: Colors.white, elevation: 0, centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: primary, foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
      textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w800),
    )),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: borderDark)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: borderDark)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryLight, width: 2)),
      hintStyle: const TextStyle(color: textSec, fontSize: 14, fontFamily: 'Cairo'),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  //  THEME REGISTRY
  // ══════════════════════════════════════════════════════════════════════════
  static const List<AppThemeMeta> allThemes = [
    AppThemeMeta(
      id: AppThemeId.deepSpace,
      nameAr: 'Deep Space',  nameEn: 'Deep Space',  emoji: '🌌',
      primary: Color(0xFF7C3AED),
      darkBg: Color(0xFF0D0D1F), lightBg: Color(0xFFF5F3FF),
      gradColors: [Color(0xFF9F67FF), Color(0xFF5B21B6)],
    ),
    // ── TAM Indigo: هوية tamlearn.com الرسمية ────────────────────────────
    AppThemeMeta(
      id: AppThemeId.tamIndigo,
      nameAr: 'TAM Indigo',  nameEn: 'TAM Indigo',  emoji: '🔷',
      primary: Color(0xFF3F36E2),
      darkBg: Color(0xFF0E0C2A), lightBg: Color(0xFFFAFBFF),
      gradColors: [Color(0xFF6C63FF), Color(0xFF3F36E2)],
    ),
    // ── Sakura Dream: وردي + بنفسجي بناتي لطيف ──────────────────────────
    AppThemeMeta(
      id: AppThemeId.sakuraDream,
      nameAr: 'Sakura Dream', nameEn: 'Sakura Dream', emoji: '🌸',
      primary: Color(0xFFE91E8C),
      darkBg: Color(0xFF1A0522), lightBg: Color(0xFFFFF0F8),
      gradColors: [Color(0xFFFF6BB5), Color(0xFF9B27AF)],
    ),
    // ── Win Flux: Microsoft Fluent Design 2026 ───────────────────────────
    AppThemeMeta(
      id: AppThemeId.winFlux,
      nameAr: 'Win Flux', nameEn: 'Win Flux', emoji: '🪟',
      primary: Color(0xFF0078D4),
      darkBg: Color(0xFF202020), lightBg: Color(0xFFF3F3F3),
      gradColors: [Color(0xFF50E6FF), Color(0xFF0078D4)],
    ),
    // ── Arctic Glass: Apple visionOS جليدي ───────────────────────────────
    AppThemeMeta(
      id: AppThemeId.arcticGlass,
      nameAr: 'Arctic Glass', nameEn: 'Arctic Glass', emoji: '🧊',
      primary: Color(0xFF0EA5E9),
      darkBg: Color(0xFF050A18), lightBg: Color(0xFFF0F9FF),
      gradColors: [Color(0xFF7DD3FC), Color(0xFF0369A1)],
    ),
    // ── Platinum Minimal: Google Chrome Slate Dark ───────────────────────
    AppThemeMeta(
      id: AppThemeId.platinumMinimal,
      nameAr: 'Platinum', nameEn: 'Platinum Minimal', emoji: '🪨',
      primary: Color(0xFF5F6368),
      darkBg: Color(0xFF202124), lightBg: Color(0xFFF8F9FA),
      gradColors: [Color(0xFF80868B), Color(0xFF3C4043)],
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  //  CARD PALETTES — per theme
  // ══════════════════════════════════════════════════════════════════════════

  // ── TAM Indigo: تدرجات indigo/violet من الموقع الرسمي ──────────────────
  static const List<List<Color>> _indigoCards = [
    [Color(0xFF6C63FF), Color(0xFF3F36E2)],
    [Color(0xFF8E44E8), Color(0xFF5B21B6)],
    [Color(0xFF4F46E5), Color(0xFF3730A3)],
    [Color(0xFF7C3AED), Color(0xFF4338CA)],
    [Color(0xFF818CF8), Color(0xFF4F46E5)],
    [Color(0xFF6366F1), Color(0xFF3F36E2)],
    [Color(0xFF8B5CF6), Color(0xFF5B21B6)],
    [Color(0xFF3F36E2), Color(0xFF1D1C6E)],
    [Color(0xFF6C63FF), Color(0xFF4F46E5)],
    [Color(0xFF7C3AED), Color(0xFF3F36E2)],
  ];

  // ── Sakura Dream: وردي + بنفسجي ─────────────────────────────────────────
  static const List<List<Color>> _sakuraCards = [
    [Color(0xFFFF6BB5), Color(0xFFE91E8C)], // Hot Pink
    [Color(0xFFCE93D8), Color(0xFF9B27AF)], // Purple
    [Color(0xFFFF80AB), Color(0xFFE040FB)], // Light Pink Violet
    [Color(0xFFE040FB), Color(0xFF7B1FA2)], // Deep Violet
    [Color(0xFFF48FB1), Color(0xFFAD1457)], // Rose Deep
    [Color(0xFFEA80FC), Color(0xFF9B27AF)], // Lavender
    [Color(0xFFF06292), Color(0xFFE91E8C)], // Flamingo
    [Color(0xFFCE93D8), Color(0xFF6A1B9A)], // Dark Purple
    [Color(0xFFFF4081), Color(0xFFAD1457)], // Bright Rose
    [Color(0xFFFF80AB), Color(0xFF9B27AF)], // Pink-Purple
  ];

  // ── Win Flux: ألوان Windows 11 Fluent ────────────────────────────────────
  static const List<List<Color>> _winCards = [
    [Color(0xFF0078D4), Color(0xFF005A9E)], // Windows Blue
    [Color(0xFF6B69D6), Color(0xFF4B48B5)], // Lavender
    [Color(0xFF0063B1), Color(0xFF003D6B)], // Deep Blue
    [Color(0xFF2D7D9A), Color(0xFF1B4F72)], // Slate
    [Color(0xFF00B294), Color(0xFF007D67)], // Mint Teal
    [Color(0xFF8764B8), Color(0xFF5E3D8A)], // Purple
    [Color(0xFF0099BC), Color(0xFF006D85)], // Teal
    [Color(0xFF107C10), Color(0xFF054B05)], // Green
    [Color(0xFF0078D4), Color(0xFF003D6B)], // Primary
    [Color(0xFF4B0082), Color(0xFF320060)], // Indigo
  ];

  // ── Arctic Glass: أزرق جليدي + شفاف ────────────────────────────────────
  static const List<List<Color>> _arcticCards = [
    [Color(0xFF7DD3FC), Color(0xFF0369A1)],
    [Color(0xFFBAE6FD), Color(0xFF0284C7)],
    [Color(0xFF38BDF8), Color(0xFF0369A1)],
    [Color(0xFF93C5FD), Color(0xFF1D4ED8)],
    [Color(0xFFE0F2FE), Color(0xFF0EA5E9)],
    [Color(0xFF7DD3FC), Color(0xFF075985)],
    [Color(0xFFBAE6FD), Color(0xFF0369A1)],
    [Color(0xFF38BDF8), Color(0xFF0284C7)],
    [Color(0xFF93C5FD), Color(0xFF2563EB)],
    [Color(0xFF7DD3FC), Color(0xFF0EA5E9)],
  ];

  // ── Platinum Minimal: لوحة بطاقات Google Dark Mode (Material Dark Pastels) ──
  static const List<List<Color>> _platinumCards = [
    [Color(0xFF1E2A38), Color(0xFF171F2B)], // Google Blue Dark
    [Color(0xFF1B2B23), Color(0xFF14201A)], // Google Green Dark
    [Color(0xFF261D36), Color(0xFF1C1528)], // Google Purple Dark
    [Color(0xFF2E2618), Color(0xFF221C11)], // Google Yellow/Amber Dark
    [Color(0xFF2F1D1D), Color(0xFF231515)], // Google Coral Red Dark
    [Color(0xFF192A32), Color(0xFF121F25)], // Google Cyan Dark
    [Color(0xFF2E2016), Color(0xFF231810)], // Google Orange Dark
    [Color(0xFF202124), Color(0xFF17181A)], // Google Slate Charcoal Dark
  ];

  // ── TAM Indigo emoji overrides ─────────────────────────────────────────
  static const Map<String, String> _indigoEmojis = {
    'Mathematics': '📐', 'Physics': '⚛️', 'Chemistry': '🧬',
    'Biology': '🔬', 'Arabic': '📖', 'English': '🌐',
    'Islamic Ed.': '🌙', 'Computer': '💻', 'Quran': '📿',
    'Geography': '🗺️', 'History': '📜', 'French': '🗼',
    'Psychology': '🧠', 'Logic': '💡', 'Statistics': '📊',
    'Philosophy': '💎', 'National Ed.': '🏛️', 'Constitution': '⚖️',
    'Art': '🎨', 'Science': '🔭', 'Social': '🌍',
  };

  // ── Sakura Dream emoji overrides ───────────────────────────────────────
  static const Map<String, String> _sakuraEmojis = {
    'Mathematics': '🌸', 'Physics': '💫', 'Chemistry': '🧁',
    'Biology': '🌺', 'Arabic': '📖', 'English': '🎀',
    'Islamic Ed.': '🌙', 'Computer': '🌷', 'Quran': '🌹',
    'Geography': '🦋', 'History': '📜', 'French': '🥐',
    'Psychology': '🧠', 'Logic': '✨', 'Statistics': '🌟',
    'Philosophy': '🪷', 'National Ed.': '🌸', 'Constitution': '🌸',
    'Art': '🎨', 'Science': '🔬', 'Social': '🌍',
  };

  // ── Win Flux emoji overrides ───────────────────────────────────────────
  static const Map<String, String> _winEmojis = {
    'Mathematics': '📊', 'Physics': '⚙️', 'Chemistry': '🧪',
    'Biology': '🧬', 'Arabic': '📝', 'English': '🌐',
    'Islamic Ed.': '🕌', 'Computer': '💻', 'Quran': '📿',
    'Geography': '🗺️', 'History': '📜', 'French': '🇫🇷',
    'Psychology': '🧠', 'Logic': '💡', 'Statistics': '📈',
    'Philosophy': '💭', 'National Ed.': '🏛️', 'Constitution': '⚖️',
    'Art': '🖥️', 'Science': '🔬', 'Social': '👥',
  };

  // ── Arctic Glass emoji overrides ───────────────────────────────────────
  static const Map<String, String> _arcticEmojis = {
    'Mathematics': '❄️', 'Physics': '🔷', 'Chemistry': '💠',
    'Biology': '🫧', 'Arabic': '📘', 'English': '🌐',
    'Islamic Ed.': '🌙', 'Computer': '💎', 'Quran': '🔷',
    'Geography': '🗺️', 'History': '🏔️', 'French': '🗼',
    'Psychology': '🧊', 'Logic': '💠', 'Statistics': '📊',
    'Philosophy': '❄️', 'National Ed.': '🌊', 'Constitution': '💠',
    'Art': '🎨', 'Science': '🔬', 'Social': '🌍',
  };

  // ══════════════════════════════════════════════════════════════════════════
  //  THEME HELPER METHODS & BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  static ThemeData lightFor(AppThemeId id) {
    if (id == AppThemeId.deepSpace) return lightTheme;
    return _buildLight(allThemes.firstWhere((t) => t.id == id));
  }

  static ThemeData darkFor(AppThemeId id) {
    if (id == AppThemeId.deepSpace) return darkTheme;
    return _buildDark(allThemes.firstWhere((t) => t.id == id));
  }

  /// Border radius per theme — each completely different
  static double _radiusFor(AppThemeId id) {
    switch (id) {
      case AppThemeId.deepSpace:       return 18.0;
      case AppThemeId.tamIndigo:       return 20.0; // مدوّر وسطي
      case AppThemeId.sakuraDream:     return 32.0; // فقاعي جداً — بناتي
      case AppThemeId.winFlux:         return 8.0;  // حاد — Windows 11
      case AppThemeId.arcticGlass:     return 28.0; // دائري — Apple visionOS
      case AppThemeId.platinumMinimal: return 16.0; // ناعم راقٍ — Chrome Minimal
    }
  }

  static ThemeData _buildLight(AppThemeMeta m) {
    final radius = _radiusFor(m.id);
    final isWin = m.id == AppThemeId.winFlux;

    return ThemeData(
      useMaterial3: true,
      fontFamily: isWin ? 'Cairo' : 'Cairo',
      brightness: Brightness.light,
      scaffoldBackgroundColor: m.lightBg,
      cardColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: m.primary,
        brightness: Brightness.light,
        primary: m.primary,
        surface: m.lightBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isWin ? m.lightBg : m.lightBg,
        foregroundColor: const Color(0xFF0F0F23),
        elevation: isWin ? 1 : 0,
        centerTitle: !isWin,
        shadowColor: isWin ? Colors.black.withValues(alpha: 0.15) : Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: isWin ? const Color(0xFF202020) : const Color(0xFF0F0F23),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: m.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          elevation: isWin ? 2 : 0,
          shadowColor: m.primary.withValues(alpha: isWin ? 0.40 : 0.30),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isWin ? const Color(0xFFFFFFFF) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: BorderSide(color: m.primary.withValues(alpha: 0.20)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: BorderSide(
            color: isWin
                ? const Color(0xFFD0D0D0)
                : m.primary.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: BorderSide(color: m.primary, width: isWin ? 2.5 : 2),
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 14,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  static ThemeData _buildDark(AppThemeMeta m) {
    final radius = _radiusFor(m.id);
    final isWin = m.id == AppThemeId.winFlux;

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: m.darkBg,
      cardColor: Color.lerp(m.darkBg, Colors.white, isWin ? 0.10 : 0.07)!,
      colorScheme: ColorScheme.fromSeed(
        seedColor: m.primary,
        brightness: Brightness.dark,
        primary: m.gradColors[0],
        surface: m.darkBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: m.darkBg,
        foregroundColor: Colors.white,
        elevation: isWin ? 1 : 0,
        centerTitle: !isWin,
        shadowColor: isWin ? Colors.black.withValues(alpha: 0.40) : Colors.transparent,
        titleTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: m.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          elevation: isWin ? 4 : 0,
          shadowColor: m.primary.withValues(alpha: isWin ? 0.50 : 0.35),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isWin
            ? Color.lerp(m.darkBg, Colors.white, 0.10)!
            : Color.lerp(m.darkBg, Colors.white, 0.05)!,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: BorderSide(color: m.primary.withValues(alpha: 0.28)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: BorderSide(
            color: isWin
                ? Colors.white.withValues(alpha: 0.20)
                : m.primary.withValues(alpha: 0.22),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: BorderSide(color: m.gradColors[0], width: isWin ? 2.5 : 2),
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 14,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  /// Custom Card Decoration Builder per Theme
  static BoxDecoration buildSubjectCardDecoration({
    required AppThemeId themeId,
    required Color color,
    required Color colorLight,
    required bool isDark,
  }) {
    switch (themeId) {
      // ── Deep Space — تدرج حيوي أصلي (بدون تغيير) ───────────────────────
      case AppThemeId.deepSpace:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [colorLight.withValues(alpha: 0.85), color.withValues(alpha: 0.70)]
                : [colorLight, color],
          ),
          borderRadius: BorderRadius.circular(24),
        );

      // ── TAM Indigo — بطاقات Glow Pill، مستطيلة مع توهج Indigo ───────────
      case AppThemeId.tamIndigo:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [colorLight.withValues(alpha: 0.80), color.withValues(alpha: 0.65)]
                : [colorLight, color],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? const Color(0xFF6C63FF).withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.75),
            width: 1.8,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: colorLight.withValues(alpha: 0.30),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
        );

      // ── Sakura Dream — فقاعات وردية بنفسجية ناعمة ───────────────────────
      case AppThemeId.sakuraDream:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [colorLight.withValues(alpha: 0.85), color.withValues(alpha: 0.70)]
                : [colorLight, color],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.65),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.40 : 0.28),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: isDark ? 0.03 : 0.60),
              blurRadius: 0,
              spreadRadius: 1,
              offset: const Offset(0, 0),
            ),
          ],
        );

      // ── Win Flux — بطاقات Mica مستطيلة حادة Windows 11 ──────────────────
      case AppThemeId.winFlux:
        return BoxDecoration(
          color: isDark
              ? Color.lerp(color, Colors.white, 0.08)!.withValues(alpha: 0.90)
              : color,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    color.withValues(alpha: 0.90),
                    color.withValues(alpha: 0.70),
                  ]
                : [
                    colorLight,
                    color,
                  ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.50),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.30 : 0.25),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        );

      // ── Arctic Glass — بطاقات Glassmorphism دائرية جداً ──────────────────
      case AppThemeId.arcticGlass:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colorLight.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.12),
                  ]
                : [
                    colorLight.withValues(alpha: 0.75),
                    color.withValues(alpha: 0.55),
                  ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.85),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.20 : 0.15),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
        );

      // ── Platinum Minimal — Google Dark Mode (Material 3 Elevated Card) ──────
      case AppThemeId.platinumMinimal:
        return BoxDecoration(
          color: isDark ? const Color(0xFF202124) : Colors.white,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [color.withValues(alpha: 0.85), colorLight.withValues(alpha: 0.70)]
                : [colorLight.withValues(alpha: 0.20), Colors.white],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFDADCE0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        );
    }
  }

  /// Custom Icon Bubble Decoration per Theme
  static BoxDecoration buildIconBubbleDecoration({
    required AppThemeId themeId,
    required Color colorLight,
    required bool isDark,
  }) {
    switch (themeId) {
      // ── Deep Space — زجاج أبيض شفاف (بدون تغيير) ────────────────────────
      case AppThemeId.deepSpace:
        return BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.40),
            width: 1.2,
          ),
        );

      // ── TAM Indigo — فقاعة Indigo متدرجة مع glow خفي ──────────────────
      case AppThemeId.tamIndigo:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF3F36E2).withValues(alpha: 0.55),
                    const Color(0xFF6C63FF).withValues(alpha: 0.75),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.85),
                    const Color(0xFFE0DFFF).withValues(alpha: 0.90),
                  ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? const Color(0xFF6C63FF).withValues(alpha: 0.50)
                : Colors.white.withValues(alpha: 0.90),
            width: 1.5,
          ),
        );

      // ── Sakura Dream — فقاعة وردية مضيئة دائرية ────────────────────────
      case AppThemeId.sakuraDream:
        return BoxDecoration(
          color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.30),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.70),
            width: 1.5,
          ),
        );

      // ── Win Flux — مربع حاد Fluent ──────────────────────────────────────
      case AppThemeId.winFlux:
        return BoxDecoration(
          color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.50),
            width: 1.0,
          ),
        );

      // ── Arctic Glass — فقاعة جليدية زجاجية شفافة ────────────────────────
      case AppThemeId.arcticGlass:
        return BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE0F2FE).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.25)
                : const Color(0xFF0EA5E9).withValues(alpha: 0.30),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.15 : 0.10),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        );

      // ── Platinum Minimal — فقاعة Google Material 3 ────────────────────────
      case AppThemeId.platinumMinimal:
        return BoxDecoration(
          color: isDark
              ? const Color(0xFF303134)
              : const Color(0xFFE8EAED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? const Color(0xFF3C4043)
                : const Color(0xFFDADCE0),
            width: 1.2,
          ),
        );
    }
  }

  /// Primary color for any theme
  static Color primaryFor(AppThemeId id) => allThemes.firstWhere((t) => t.id == id).primary;

  /// Gradient for any theme
  static LinearGradient gradientFor(AppThemeId id) {
    if (id == AppThemeId.deepSpace) return primaryGrad;
    final m = allThemes.firstWhere((t) => t.id == id);
    return LinearGradient(colors: m.gradColors, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  /// Card style for each theme
  static AppCardStyle cardStyleFor(AppThemeId id) {
    switch (id) {
      case AppThemeId.deepSpace:       return AppCardStyle.vivid;
      case AppThemeId.tamIndigo:       return AppCardStyle.indigo;
      case AppThemeId.sakuraDream:     return AppCardStyle.sakura;
      case AppThemeId.winFlux:         return AppCardStyle.win;
      case AppThemeId.arcticGlass:     return AppCardStyle.arctic;
      case AppThemeId.platinumMinimal: return AppCardStyle.platinum;
    }
  }

  /// Card gradient colors — returns null for deepSpace (uses subject colors)
  static List<Color>? cardColorsFor(AppThemeId id, int index) {
    switch (id) {
      case AppThemeId.deepSpace:       return null;
      case AppThemeId.tamIndigo:       return _indigoCards[index % _indigoCards.length];
      case AppThemeId.sakuraDream:     return _sakuraCards[index % _sakuraCards.length];
      case AppThemeId.winFlux:         return _winCards[index % _winCards.length];
      case AppThemeId.arcticGlass:     return _arcticCards[index % _arcticCards.length];
      case AppThemeId.platinumMinimal: return _platinumCards[index % _platinumCards.length];
    }
  }

  /// Emoji override per theme
  static String emojiFor(AppThemeId id, String subjectEn, String defaultEmoji) {
    switch (id) {
      case AppThemeId.tamIndigo:   return _indigoEmojis[subjectEn] ?? defaultEmoji;
      case AppThemeId.sakuraDream: return _sakuraEmojis[subjectEn] ?? defaultEmoji;
      case AppThemeId.winFlux:     return _winEmojis[subjectEn] ?? defaultEmoji;
      case AppThemeId.arcticGlass: return _arcticEmojis[subjectEn] ?? defaultEmoji;
      default:                     return defaultEmoji;
    }
  }

  /// Layout type per theme — controls grid structure
  static AppThemeLayout layoutFor(AppThemeId id) {
    switch (id) {
      case AppThemeId.sakuraDream: return AppThemeLayout.bubble;
      case AppThemeId.winFlux:     return AppThemeLayout.fluent;
      default:                     return AppThemeLayout.standard;
    }
  }

  /// Grid columns per theme
  static int gridColsFor(AppThemeId id, double maxWidth) {
    switch (layoutFor(id)) {
      case AppThemeLayout.bubble:
        return maxWidth > 600 ? 3 : 2;
      case AppThemeLayout.fluent:
        return maxWidth > 700 ? 3 : 2;
      case AppThemeLayout.standard:
        return maxWidth > 800 ? 5 : (maxWidth > 500 ? 4 : 3);
    }
  }

  /// Grid aspect ratio per theme
  static double gridAspectFor(AppThemeId id) {
    switch (id) {
      case AppThemeId.tamIndigo:   return 1.0;
      case AppThemeId.sakuraDream: return 1.05;
      case AppThemeId.winFlux:     return 0.90;
      default:                     return 0.84;
    }
  }

  /// Background gradient per theme
  static LinearGradient bgGradientFor(AppThemeId id, bool isDark) {
    switch (id) {
      // ── Deep Space (unchanged) ──────────────────────────────────────────
      case AppThemeId.deepSpace:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF0D0D1F), Color(0xFF130E2A), Color(0xFF0D1828)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(
                colors: [Color(0xFFF5F3FF), Color(0xFFEFF6FF), Color(0xFFFDF4FF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight);

      // ── TAM Indigo: كحلي بنفسجي (داكن) / أبيض ناصع (فاتح) ─────────────
      case AppThemeId.tamIndigo:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF0E0C2A), Color(0xFF130F32), Color(0xFF0A0820)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(
                colors: [Color(0xFFFAFBFF), Color(0xFFF5F3FF), Color(0xFFEEF2FF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight);

      // ── Sakura Dream: وردي ناعم (فاتح) / بنفسجي داكن (داكن) ───────────
      case AppThemeId.sakuraDream:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF1A0522), Color(0xFF220830), Color(0xFF18041E)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(
                colors: [Color(0xFFFFF0F8), Color(0xFFFCE4EC), Color(0xFFF8EFF8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight);

      // ── Win Flux: رمادي فاتح (فاتح) / داكن رمادي Windows (داكن) ────────
      case AppThemeId.winFlux:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF202020), Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(
                colors: [Color(0xFFF3F3F3), Color(0xFFEFEFEF), Color(0xFFF9F9F9)],
                begin: Alignment.topLeft, end: Alignment.bottomRight);

      // ── Arctic Glass: ثلجي أبيض (فاتح) / أسود جليدي (داكن) ───────────
      case AppThemeId.arcticGlass:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF050A18), Color(0xFF070D1F), Color(0xFF040816)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(
                colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE), Color(0xFFF5FBFF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight);

      // ── Platinum Minimal: Google Dark Charcoal ────────────────────────
      case AppThemeId.platinumMinimal:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF17181A), Color(0xFF202124), Color(0xFF141517)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter)
            : const LinearGradient(
                colors: [Color(0xFFF1F3F4), Color(0xFFF8FAFC), Color(0xFFE8EAED)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter);
    }
  }

  /// Welcome card gradient per theme
  static LinearGradient welcomeGradFor(AppThemeId id, bool isDark) {
    switch (id) {
      // ── Deep Space (unchanged) ──────────────────────────────────────────
      case AppThemeId.deepSpace:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF1A1035), Color(0xFF0E1C38)],
                begin: Alignment.topRight, end: Alignment.bottomLeft)
            : const LinearGradient(
                colors: [Color(0xFFF3E8FF), Color(0xFFF3E8FF)],
                begin: Alignment.topRight, end: Alignment.bottomLeft);

      // ── TAM Indigo: Indigo glow بارد ─────────────────────────────────
      case AppThemeId.tamIndigo:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF1A1660), Color(0xFF0E0C2A)],
                begin: Alignment.topRight, end: Alignment.bottomLeft)
            : const LinearGradient(
                colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF), Color(0xFFF5F3FF)],
                begin: Alignment.topRight, end: Alignment.bottomLeft);

      // ── Sakura Dream: وردي بنفسجي ───────────────────────────────────
      case AppThemeId.sakuraDream:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF3D0A50), Color(0xFF1A0522)],
                begin: Alignment.topRight, end: Alignment.bottomLeft)
            : const LinearGradient(
                colors: [Color(0xFFFCE4EC), Color(0xFFE1BEE7), Color(0xFFFFF0F8)],
                begin: Alignment.topRight, end: Alignment.bottomLeft);

      // ── Win Flux: رمادي فاتح Windows ─────────────────────────────────
      case AppThemeId.winFlux:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF003A6B), Color(0xFF202020)],
                begin: Alignment.topRight, end: Alignment.bottomLeft)
            : const LinearGradient(
                colors: [Color(0xFFE6F2FB), Color(0xFFD0E8F6), Color(0xFFF3F3F3)],
                begin: Alignment.topRight, end: Alignment.bottomLeft);

      // ── Arctic Glass: جليدي أبيض ─────────────────────────────────────
      case AppThemeId.arcticGlass:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF0A1A30), Color(0xFF050A18)],
                begin: Alignment.topRight, end: Alignment.bottomLeft)
            : const LinearGradient(
                colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD), Color(0xFFF0F9FF)],
                begin: Alignment.topRight, end: Alignment.bottomLeft);

      // ── Platinum Minimal: Google Dark Header Gradient ─────────────────
      case AppThemeId.platinumMinimal:
        return isDark
            ? const LinearGradient(
                colors: [Color(0xFF202124), Color(0xFF17181A)],
                begin: Alignment.topRight, end: Alignment.bottomLeft)
            : const LinearGradient(
                colors: [Color(0xFFE8EAED), Color(0xFFF1F3F4), Color(0xFFFFFFFF)],
                begin: Alignment.topRight, end: Alignment.bottomLeft);
    }
  }

  /// Nav bar dark background per theme
  static Color navDarkBgFor(AppThemeId id) {
    switch (id) {
      case AppThemeId.deepSpace:       return const Color(0xFF1A1635);
      case AppThemeId.tamIndigo:       return const Color(0xFF12103A);
      case AppThemeId.sakuraDream:     return const Color(0xFF2D0A3A);
      case AppThemeId.winFlux:         return const Color(0xFF2C2C2C);
      case AppThemeId.arcticGlass:     return const Color(0xFF071525);
      case AppThemeId.platinumMinimal: return const Color(0xFF202124);
    }
  }

  // ── Kept for backward compat ───────────────────────────────────────────
  static const Color royalGold      = Color(0xFF3F36E2);
  static const Color royalGoldLight = Color(0xFF6C63FF);

  /// Neon glow helper
  static Color neonGlow(Color neon) => neon.withValues(alpha: 0.35);


  /// Desaturate a color slightly for calm, readable card backgrounds.
  /// Extracted from lessons_screen / subject_screen to avoid duplication.
  static Color toCalmColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 0.55).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 1.12).clamp(0.0, 1.0))
        .toColor();
  }
}
