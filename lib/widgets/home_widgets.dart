import 'package:flutter/material.dart';
import '../services/app_provider.dart';
import '../utils/app_theme.dart';
import 'animated_pressable.dart';

/// ── Search Result Tile used in HomeScreen search results ─────────────────
/// Extracted from home_screen.dart to reduce file size and improve reusability.
class SearchResultTile extends StatelessWidget {
  final String icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final bool isDark;
  final VoidCallback? onTap;

  const SearchResultTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onTap: onTap ?? () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: iconColor.withValues(alpha: isDark ? 0.25 : 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: iconColor.withValues(alpha: isDark ? 0.35 : 0.20),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: isDark ? 0.20 : 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: badgeColor.withValues(alpha: isDark ? 0.40 : 0.25),
                  width: 1,
                ),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

/// ── Section Header with color accent bar ─────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const SectionHeader({super.key, required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color ?? AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Subject card widget — renders differently per theme ────────────────────
/// Extracted from home_screen.dart _subjectCard() method.
class SubjectCard extends StatelessWidget {
  final Map<String, String> subject;
  final AppProvider p;
  final int index;
  final VoidCallback onTap;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.p,
    required this.index,
    required this.onTap,
  });

  Color _vividColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 1.15).clamp(0.72, 1.0))
        .withLightness((hsl.lightness * 0.88).clamp(0.42, 0.58))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final themeId = p.themeId;
    final themeColors = AppTheme.cardColorsFor(themeId, index);
    final Color color, colorLight;
    if (themeColors != null) {
      colorLight = themeColors[0];
      color = themeColors[1];
    } else {
      final rawColor = AppTheme.parseColor(subject['color']);
      final vivid = _vividColor(rawColor);
      color = vivid;
      colorLight = Color.lerp(vivid, Colors.white, 0.30)!;
    }
    final emoji = AppTheme.emojiFor(themeId, subject['en']!, subject['em']!);
    final name = p.isAr ? subject['ar']! : subject['en']!;
    final isDark = p.isDark;

    final decoration = AppTheme.buildSubjectCardDecoration(
      themeId: themeId,
      color: color,
      colorLight: colorLight,
      isDark: isDark,
    );

    // ── Platinum Minimal ──────────────────────────────────────────────────
    if (themeId == AppThemeId.platinumMinimal) {
      return AnimatedPressable(
        onTap: onTap,
        child: Container(
          decoration: decoration,
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorLight.withValues(alpha: 0.22)
                          : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? colorLight.withValues(alpha: 0.45)
                            : color.withValues(alpha: 0.30),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child:
                          Text(emoji, style: const TextStyle(fontSize: 19)),
                    ),
                  ),
                  Text(
                    name,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFE8EAED)
                          : const Color(0xFF202124),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Cairo',
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3.5,
                decoration: BoxDecoration(
                  color: isDark ? colorLight : color,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
            ),
          ]),
        ),
      );
    }

    // ── Win Flux ──────────────────────────────────────────────────────────
    if (themeId == AppThemeId.winFlux) {
      return AnimatedPressable(
        onTap: onTap,
        child: Container(
          decoration: decoration,
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Sakura Dream ─────────────────────────────────────────────────────
    if (themeId == AppThemeId.sakuraDream) {
      return AnimatedPressable(
        onTap: onTap,
        child: Container(
          decoration: decoration,
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned(
              right: -8,
              top: -8,
              child: Opacity(
                opacity: 0.20,
                child: Text('✨', style: const TextStyle(fontSize: 50)),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: isDark ? 0.15 : 0.30),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.60),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(emoji,
                            style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
    }

    // ── TAM Indigo ────────────────────────────────────────────────────────
    if (themeId == AppThemeId.tamIndigo) {
      return AnimatedPressable(
        onTap: onTap,
        child: Container(
          decoration: decoration,
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
    }

    // ── Deep Space + Arctic Glass (default) ──────────────────────────────
    return AnimatedPressable(
      onTap: onTap,
      child: Container(
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(
            right: -12,
            bottom: -12,
            child: Opacity(
              opacity: 0.18,
              child: Text(emoji, style: const TextStyle(fontSize: 72)),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'subject_icon_${subject['en']}',
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: AppTheme.buildIconBubbleDecoration(
                      themeId: themeId,
                      colorLight: colorLight,
                      isDark: isDark,
                    ),
                    child: Center(
                      child:
                          Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  p.isAr ? subject['en']! : subject['ar']!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
