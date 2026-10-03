import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_provider.dart';
import '../../utils/app_theme.dart';
import 'subject_screen.dart';
import '../settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final userData = p.userData ?? {};
    final name = userData['name'] ?? 'طالب';
    final grade = userData['grade'] ?? 12;
    final section = userData['section'] ?? 'scientific';

    final subjects =
        p.curriculumSubjects ?? AppProvider.getSubjects(grade, section);

    return Scaffold(
      extendBody: true,
      body: _tab == 0 ? _buildHome(p, subjects, name, grade) : const SettingsScreen(),
      bottomNavigationBar: _buildNav(p),
    );
  }

  Widget _buildHome(
    AppProvider p,
    List<Map<String, String>> subjects,
    String name,
    int grade,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _buildWelcomeCard(p, name),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        p.subjects,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        p.isDark ? const Color(0xFF1E1E2C) : Colors.white,
                        AppTheme.primary,
                        p.isDark ? 0.25 : 0.10,
                      )!,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: p.isDark ? 0.35 : 0.18),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🎓',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          p.isAr ? 'الصف $grade' : 'Grade $grade',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  int cols = constraints.maxWidth > 800
                      ? 5
                      : (constraints.maxWidth > 500 ? 4 : 3);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: 0.84,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: subjects.length,
                    itemBuilder: (_, i) => _subjectCard(subjects[i], p),
                  );
                },
              ),
              const SizedBox(height: 120),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(AppProvider p, String name) {
    final isDark = p.isDark;
    final baseBg = Theme.of(context).scaffoldBackgroundColor;
    
    final cardBgStart = Color.lerp(
      baseBg,
      AppTheme.primary,
      isDark ? 0.22 : 0.08,
    )!;
    final cardBgEnd = Color.lerp(
      baseBg,
      AppTheme.primary,
      isDark ? 0.06 : 0.02,
    )!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [cardBgStart, cardBgEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: isDark ? 0.22 : 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                name.isEmpty
                    ? Container(
                        width: 120,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.textSec.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : Text(
                        p.isAr ? 'مرحباً $name 👋' : 'Welcome $name 👋',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          height: 1.1,
                        ),
                      ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      p.isAr ? 'تعلّم بذكاء مع تَم' : 'Learn Smarter with TAM',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color.lerp(
                          isDark ? Colors.white : const Color(0xFF1A1A2E),
                          AppTheme.primary,
                          0.7,
                        )!,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '✨',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => setState(() => _tab = 1),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.05) 
                    : AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                  width: 1,
                ),
              ),
              child: Hero(
                tag: 'logo',
                child: Image.asset(
                  p.isDark
                      ? 'assets/images/logo_dark.png'
                      : 'assets/images/logo_light.png',
                  height: 46,
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

  Color _toCalmColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 0.65).clamp(0.38, 0.52))
        .withLightness((hsl.lightness * 1.12).clamp(0.62, 0.72))
        .toColor();
  }

  Widget _subjectCard(Map<String, String> subject, AppProvider p) {
    final rawColor = Color(int.parse('FF${subject['color']!}', radix: 16));
    final color = _toCalmColor(rawColor);
    final name = p.isAr ? subject['ar']! : subject['en']!;
    final isDark = p.isDark;

    final baseBg = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final gradientStart = Color.lerp(
      baseBg,
      color,
      isDark ? 0.45 : 0.35,
    )!;
    final gradientEnd = Color.lerp(
      baseBg,
      color,
      isDark ? 0.20 : 0.12,
    )!;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween(begin: 1.0, end: 1.0),
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubjectScreen(
                subject: subject,
                grade: (p.userData?['grade'] ?? 12),
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [gradientStart, gradientEnd],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.24),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : color.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -15,
                top: -15,
                child: Opacity(
                  opacity: isDark ? 0.08 : 0.05,
                  child: Text(
                    subject['em']!,
                    style: const TextStyle(fontSize: 70),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'subject_icon_${subject['en']}',
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            baseBg,
                            color,
                            isDark ? 0.30 : 0.18,
                          )!,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: color.withValues(alpha: isDark ? 0.45 : 0.30),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            subject['em']!,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      p.isAr ? subject['en']! : subject['ar']!,
                      style: TextStyle(
                        color: Color.lerp(
                          isDark ? Colors.white : const Color(0xFF1A1A2E),
                          color,
                          0.75,
                        )!,
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
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNav(AppProvider p) {
    return SizedBox(
      height: 82,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 58,
          width: 206,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: p.isDark 
              ? const Color(0xFF1C1C1E).withValues(alpha: 0.8) 
              : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                children: [
                  Expanded(
                    child: _navItem(
                      0,
                      Icons.auto_awesome_mosaic_rounded,
                      Icons.auto_awesome_mosaic_outlined,
                      p.home,
                      p,
                    ),
                  ),
                  Expanded(
                    child: _navItem(
                      1,
                      Icons.person_rounded,
                      Icons.person_outline_rounded,
                      p.settings,
                      p,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    int i,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    AppProvider p,
  ) {
    final active = _tab == i;
    final icon = active ? activeIcon : inactiveIcon;

    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      behavior: HitTestBehavior.opaque,
      child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                key: ValueKey(active),
                color: active ? AppTheme.primary : AppTheme.textSec.withValues(alpha: 0.4),
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppTheme.primary : AppTheme.textSec.withValues(alpha: 0.4),
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 10,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
    );
  }

}
