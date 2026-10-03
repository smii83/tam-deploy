import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/app_provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_data_service.dart';
import '../../utils/app_theme.dart';
import '../student/home_screen.dart';
import '../student/payment_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

// ═══════════════════════════════════════════════════
//  TAM – 2026 Splash Screen
//  Aurora Mesh Background (Brand Purple & Teal) + Floating Particles
//  Spring Logo Reveal + Shimmer Tagline
// ═══════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Aurora (slow infinite mesh drift) ────────────────────────────────────
  late AnimationController _auroraCtrl;

  // ── Particles (infinite float upward) ────────────────────────────────────
  late AnimationController _particleCtrl;
  late List<_Particle> _particles;

  // ── Logo spring-pop ───────────────────────────────────────────────────────
  late AnimationController _logoCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoGlow;

  // ── Ring pulse around logo ────────────────────────────────────────────────
  late AnimationController _ringCtrl;
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;

  // ── Text reveal (slide + fade) ────────────────────────────────────────────
  late AnimationController _textCtrl;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlide;

  // ── Shimmer sweep on headline ─────────────────────────────────────────────
  late AnimationController _shimmerCtrl;

  // ── 3-dot breathing loader ────────────────────────────────────────────────
  late AnimationController _dotsCtrl;

  @override
  void initState() {
    super.initState();

    // Seed particles
    final rnd = math.Random(7);
    _particles = List.generate(60, (i) => _Particle(
      x: rnd.nextDouble(),
      y: rnd.nextDouble(),
      r: rnd.nextDouble() * 1.8 + 0.4,
      speed: rnd.nextDouble() * 0.18 + 0.05,
      phase: rnd.nextDouble() * math.pi * 2,
      drift: (rnd.nextDouble() - 0.5) * 0.03,
    ));

    // Aurora – 14-second slow drift
    _auroraCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 14))
      ..repeat();

    // Particles – 9-second rise cycle
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 9))
      ..repeat();

    // Logo spring (elasticOut)
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.35)));
    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.5, 1.0)));

    // Ring pulse (repeating scale + fade)
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _ringScale = Tween<double>(begin: 1.0, end: 1.7).animate(
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));
    _ringOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeIn));

    // Text slide-up
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<double>(begin: 28.0, end: 0.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Shimmer sweep (continuous)
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();

    // Breathing dots
    _dotsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    _runSequence();
    _navigate();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 750));
    if (mounted) _textCtrl.forward();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) { _push(const LoginScreen()); return; }
      final ap = context.read<AppProvider>();
      await ap.loadUserData();
      if (!mounted) return;
      if (ap.userData != null && ap.userData!['is_blocked'] == true) {
        await context.read<AuthService>().logout();
        _push(const LoginScreen(errorMsg: 'لقد تم حظر هذا الحساب من قبل الإدارة.'));
        return;
      }
      final ok = await FirestoreDataService.isSubscribed(firebaseUser.uid);
      if (!mounted) return;
      // Cache result for offline fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_subscribed_${firebaseUser.uid}', ok);
      } catch (_) {}
      _push(ok ? const HomeScreen() : const PaymentScreen());
    } catch (e) {
      debugPrint('Splash: $e');
      if (!mounted) return;
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) {
        _push(const LoginScreen());
        return;
      }
      // Network error for a logged-in user — check cached subscription status
      // to avoid sending a valid subscriber to the paywall.
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedSub = prefs.getBool('is_subscribed_${u.uid}') ?? false;
        if (!mounted) return;
        _push(cachedSub ? const HomeScreen() : const PaymentScreen());
      } catch (_) {
        if (mounted) _push(const PaymentScreen());
      }
    }
  }

  void _push(Widget w) => Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => w,
          transitionDuration: const Duration(milliseconds: 700),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
            child: child,
          ),
        ),
      );

  @override
  void dispose() {
    _auroraCtrl.dispose();
    _particleCtrl.dispose();
    _logoCtrl.dispose();
    _ringCtrl.dispose();
    _textCtrl.dispose();
    _shimmerCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primaryColor = AppTheme.primary; // Electric Violet (Brand Purple)
    final secondaryColor = AppTheme.accent; // Vivid Cyan (Brand Teal)

    return Scaffold(
      backgroundColor: const Color(0xFF090A10), // Ultra-premium deep slate black
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _auroraCtrl, _particleCtrl, _shimmerCtrl, _dotsCtrl,
          _ringCtrl, _logoCtrl, _textCtrl,
        ]),
        builder: (context, _) {
          return Stack(
            children: [
              // ── 1. Aurora mesh background (Purple & Teal drift) ───────────
              CustomPaint(
                size: size,
                painter: _AuroraPainter(_auroraCtrl.value, primaryColor, secondaryColor),
              ),

              // ── 2. Floating particle field ───────────────────────────────
              CustomPaint(
                size: size,
                painter: _ParticlePainter(_particles, _particleCtrl.value),
              ),

              // ── 3. Subtle grid overlay ───────────────────────────────────
              CustomPaint(
                size: size,
                painter: _GridPainter(),
              ),

              // ── 4. Main content ──────────────────────────────────────────
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    // ── Logo area ──────────────────────────────────────────
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [

                          // Pulsing ring
                          Transform.scale(
                            scale: _ringScale.value,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor
                                      .withValues(alpha: _ringOpacity.value),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          // Logo container with glow
                          Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Glow blur backdrop
                                  if (_logoGlow.value > 0)
                                    Container(
                                      width: 148,
                                      height: 148,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withValues(
                                                alpha: _logoGlow.value * 0.22),
                                            blurRadius: 40,
                                            spreadRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Glass circle
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.08),
                                          Colors.white.withValues(alpha: 0.02),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        width: 1,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(24),
                                    child: Image.asset(
                                      'assets/images/logo_dark.png',
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Text block ─────────────────────────────────────────
                    Opacity(
                      opacity: _textOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Column(
                          children: [
                            // "تعلم بذكاء" with shimmer sweep
                            ShaderMask(
                              shaderCallback: (bounds) {
                                final p = _shimmerCtrl.value;
                                return LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [
                                    Colors.white,
                                    primaryColor.withValues(alpha: 0.8),
                                    Colors.white,
                                    Colors.white,
                                  ],
                                  stops: [
                                    (p - 0.35).clamp(0.0, 1.0),
                                    p.clamp(0.0, 1.0),
                                    (p + 0.15).clamp(0.0, 1.0),
                                    1.0,
                                  ],
                                ).createShader(bounds);
                              },
                              child: const Text(
                                'تعلم بذكاء',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Cairo',
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // "مع منصة تَم"
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontFamily: 'Cairo'),
                                children: [
                                  const TextSpan(
                                    text: 'مع ',
                                    style: TextStyle(
                                      color: Color(0xFF8B9DB0),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'منصة تَم',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Thin separator line
                            Container(
                              width: 40,
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    primaryColor.withValues(alpha: 0.5),
                                    Colors.transparent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),

                            // Version tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.2),
                                ),
                                borderRadius: BorderRadius.circular(20),
                                color: primaryColor.withValues(alpha: 0.05),
                              ),
                              child: Text(
                                'المنصة التعليمية الذكية',
                                style: TextStyle(
                                  color: primaryColor.withValues(alpha: 0.9),
                                  fontSize: 10,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 70),

                    // ── 3 breathing dots ───────────────────────────────────
                    Opacity(
                      opacity: _textOpacity.value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final raw = (_dotsCtrl.value * 3 - i * 0.33) % 1.0;
                          final wave = math.sin(raw * math.pi);
                          final sc = 1.0 + wave * 0.6;
                          final op = 0.35 + wave * 0.55;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Transform.scale(
                              scale: sc.clamp(0.7, 1.6),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor
                                      .withValues(alpha: op.clamp(0.2, 1.0)),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 5. Bottom wordmark ───────────────────────────────────────
              Positioned(
                bottom: 32,
                left: 0, right: 0,
                child: Opacity(
                  opacity: _textOpacity.value * 0.4,
                  child: const Text(
                    'TAM · 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w300,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  Aurora Painter – 3 drifting radial blobs (Purple/Teal)
// ═══════════════════════════════════════════════════
class _AuroraPainter extends CustomPainter {
  final double t;
  final Color primaryColor;
  final Color secondaryColor;
  const _AuroraPainter(this.t, this.primaryColor, this.secondaryColor);

  @override
  void paint(Canvas canvas, Size s) {
    // Static deep-dark base
    canvas.drawRect(Offset.zero & s,
        Paint()..color = const Color(0xFF090A10));

    final tau = math.pi * 2;

    final blobs = [
      // Primary Purple - top-left drift
      _Blob(
        cx: s.width * (0.15 + math.sin(t * tau * 0.9) * 0.12),
        cy: s.height * (0.25 + math.cos(t * tau * 0.7) * 0.14),
        r: s.width * 0.7,
        color: primaryColor.withValues(alpha: 0.15),
      ),
      // Secondary Teal - right drift
      _Blob(
        cx: s.width * (0.85 + math.cos(t * tau * 0.8) * 0.10),
        cy: s.height * (0.55 + math.sin(t * tau * 0.6) * 0.18),
        r: s.width * 0.65,
        color: secondaryColor.withValues(alpha: 0.12),
      ),
      // Deep Purple/Indigo - bottom-center
      _Blob(
        cx: s.width * (0.50 + math.sin(t * tau * 1.05 + 1.2) * 0.18),
        cy: s.height * (0.82 + math.cos(t * tau * 0.85) * 0.10),
        r: s.width * 0.6,
        color: primaryColor.withValues(alpha: 0.08),
      ),
    ];

    for (final b in blobs) {
      final rect = Rect.fromCircle(
          center: Offset(b.cx, b.cy), radius: b.r);
      canvas.drawCircle(
        Offset(b.cx, b.cy),
        b.r,
        Paint()
          ..shader = RadialGradient(
              colors: [b.color, Colors.transparent]).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t || old.primaryColor != primaryColor || old.secondaryColor != secondaryColor;
}

class _Blob {
  final double cx, cy, r;
  final Color color;
  const _Blob({required this.cx, required this.cy, required this.r, required this.color});
}

// ═══════════════════════════════════════════════════
//  Particle Painter – tiny floating dots rising up
// ═══════════════════════════════════════════════════
class _Particle {
  final double x, y, r, speed, phase, drift;
  const _Particle({
    required this.x, required this.y, required this.r,
    required this.speed, required this.phase, required this.drift,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  const _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final yPos = (p.y - t * p.speed + 1.0) % 1.0;
      final xPos = p.x + math.sin(t * math.pi * 2 * p.speed + p.phase) * p.drift;
      // Fade in near bottom, fade out near top
      final fade = (math.sin(yPos * math.pi)).clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: fade * 0.12);
      canvas.drawCircle(
        Offset(xPos * s.width, yPos * s.height),
        p.r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════
//  Grid Painter – subtle dark dot-grid
// ═══════════════════════════════════════════════════
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    const step = 32.0;
    for (double x = 0; x < s.width; x += step) {
      for (double y = 0; y < s.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}
