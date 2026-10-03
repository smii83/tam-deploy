import 'package:flutter/material.dart';
import '../services/app_provider.dart';
import '../utils/app_theme.dart';
import 'animated_pressable.dart';

/// ── Welcome Card shown at the top of HomeScreen ────────────────────────────
/// Extracted from home_screen.dart to reduce file size and improve reusability.
class HomeWelcomeCard extends StatelessWidget {
  final AppProvider p;
  final String name;
  final VoidCallback onAvatarTap;

  const HomeWelcomeCard({
    super.key,
    required this.p,
    required this.name,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = p.isDark;
    final themePrimary = AppTheme.primaryFor(p.themeId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: AppTheme.welcomeGradFor(p.themeId, isDark),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? themePrimary.withValues(alpha: 0.35)
              : themePrimary.withValues(alpha: 0.20),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Platform chip ──────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: themePrimary.withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: themePrimary
                          .withValues(alpha: isDark ? 0.40 : 0.22),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: themePrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        p.isAr ? 'منصة تَم التعليمية' : 'TAM Platform',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                          color: themePrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // ── Name greeting ──────────────────────────────────────
                name.isEmpty
                    ? Container(
                        width: 130,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.textSec.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
                    : Text(
                        p.isAr ? 'أهلاً، $name 👋' : 'Hello, $name 👋',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                          color: isDark ? Colors.white : const Color(0xFF0F0F23),
                          height: 1.2,
                        ),
                      ),
                const SizedBox(height: 5),
                // ── Tagline ───────────────────────────────────────────
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.gradientFor(p.themeId).createShader(bounds),
                  child: Text(
                    p.isAr
                        ? 'تعلّم بذكاء • ابدأ الآن ✨'
                        : 'Learn Smart • Start Now ✨',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Cairo',
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ── Logo avatar ────────────────────────────────────────────
          AnimatedPressable(
            onTap: onAvatarTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          Color.lerp(
                              AppTheme.allThemes
                                  .firstWhere((t) => t.id == p.themeId)
                                  .darkBg,
                              themePrimary,
                              0.35)!,
                          Color.lerp(
                              AppTheme.allThemes
                                  .firstWhere((t) => t.id == p.themeId)
                                  .darkBg,
                              themePrimary,
                              0.15)!,
                        ]
                      : [
                          Color.lerp(Colors.white, themePrimary, 0.08)!,
                          Color.lerp(Colors.white, themePrimary, 0.16)!,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: themePrimary.withValues(alpha: isDark ? 0.40 : 0.22),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themePrimary.withValues(alpha: 0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Hero(
                tag: 'logo',
                child: Image.asset(
                  p.isDark
                      ? 'assets/images/logo_dark.png'
                      : 'assets/images/logo_light.png',
                  height: 48,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
