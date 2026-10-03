import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_urls.dart';
import '../../widgets/animated_pressable.dart';
import '../auth/login_screen.dart';
import 'home_screen.dart';


class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  static const String _productId = 'tam_6months_12kwd';
  bool _available = false, _loading = true, _purchasing = false;
  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _initIAP();
    if (!kIsWeb) {
      _purchaseSub = InAppPurchase.instance.purchaseStream.listen(_onPurchase);
    }
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _initIAP() async {
    try {
      if (kIsWeb) {
        setState(() => _loading = false);
        return;
      }
      _available = await InAppPurchase.instance.isAvailable();
      if (_available) {
        final res =
            await InAppPurchase.instance.queryProductDetails({_productId});
        setState(() {
          _products = res.productDetails;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _onPurchase(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        await _activate(p.purchaseID ?? '');
        await InAppPurchase.instance.completePurchase(p);
      } else if (p.status == PurchaseStatus.error) {
        setState(() => _purchasing = false);
      }
    }
  }

  Future<void> _activate(String txId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // 🔒 SECURE: Subscription activation handled server-side via Cloud Function.
      // The Cloud Function verifies the transaction and writes to Firestore using
      // Firebase Admin SDK — bypassing client-side security rules entirely.
      final functions = FirebaseFunctions.instanceFor(region: 'me-central1');
      await functions.httpsCallable('activateSubscription').call({
        'productId': _productId,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'transactionId': txId,
        'userEmail': user.email ?? '',
      });
    } on FirebaseFunctionsException catch (fnEx) {
      debugPrint('activateSubscription error: ${fnEx.code} — ${fnEx.message}');
      if (mounted) {
        _snack('حدث خطأ أثناء تفعيل الاشتراك. يرجى التواصل مع الدعم.');
      }
      setState(() => _purchasing = false);
      return;
    } catch (e) {
      debugPrint('activateSubscription exception: $e');
      if (mounted) {
        _snack('حدث خطأ غير متوقع. يرجى التواصل مع الدعم.');
      }
      setState(() => _purchasing = false);
      return;
    }
    if (!mounted) return;
    setState(() => _purchasing = false);
    _showSuccess();
  }

  Future<void> _purchase() async {
    // 🔒 Security: Web platform does NOT support real payments.
    if (kIsWeb) {
      _snack('الاشتراك متاح فقط عبر تطبيق iOS أو Android');
      return;
    }
    if (_products.isEmpty) {
      _snack('المنتج غير متاح حالياً، حاول لاحقاً');
      return;
    }
    setState(() => _purchasing = true);
    // ── NOTE: use buyConsumable for non-auto-renewing (time-limited) subscriptions
    // If you convert to Auto-Renewable Subscription in App Store Connect,
    // switch this back to buyNonConsumable.
    await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: _products.first));
  }

  // ── Restore Purchases (Apple App Store Guideline 3.1.1 requirement) ───────
  Future<void> _restorePurchases() async {
    if (kIsWeb) {
      _snack('ميزة استعادة المشتريات متاحة فقط عبر تطبيق iOS أو Android');
      return;
    }
    setState(() => _purchasing = true);
    try {
      await InAppPurchase.instance.restorePurchases();
      if (mounted) {
        final isAr = context.read<AppProvider>().isAr;
        _snack(isAr
            ? 'جاري التحقق من المشتريات السابقة واستعادتها...'
            : 'Checking and restoring previous purchases...');
      }
    } catch (e) {
      if (mounted) {
        final isAr = context.read<AppProvider>().isAr;
        _snack(isAr
            ? 'تعذر استعادة المشتريات حالياً. يرجى المحاولة لاحقاً'
            : 'Could not restore purchases. Please try again later.');
      }
    } finally {
      if (mounted) {
        setState(() => _purchasing = false);
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _showSuccess() {
    final p = context.read<AppProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGrad,
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 38))),
          ),
          const SizedBox(height: 16),
          const Text('تم الاشتراك بنجاح!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('مرحباً بك في منصة تم 🎓',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSec)),
          const SizedBox(height: 24),
          AnimatedPressable(
            onTap: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (_) => false),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.gradientFor(p.themeId),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'ابدأ رحلتك التعليمية ←',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isDark = p.isDark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F111A) : const Color(0xFFEEEDFF),
      body: Column(
        children: [
          // ── Premium gradient header ───────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF6C63FF),
                  Color(0xFF4F46E5),
                  Color(0xFF00B8A9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar: back + logout
                        Row(
                          children: [
                            if (Navigator.canPop(context))
                              AnimatedPressable(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: Icon(
                                    p.isAr
                                        ? Icons.arrow_forward
                                        : Icons.arrow_back,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            AnimatedPressable(
                              onTap: () async {
                                final appProvider = context.read<AppProvider>();
                                final authService = context.read<AuthService>();
                                final nav = Navigator.of(context);
                                await appProvider.clearUserData();
                                await authService.logout();
                                nav.pushAndRemoveUntil(
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                  (_) => false,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.logout,
                                        color: Colors.white, size: 15),
                                    const SizedBox(width: 4),
                                    Text(
                                      p.logout,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Logo + Title row
                        Row(
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: Image.asset(
                                'assets/images/logo_dark.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.subscribeTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      '🏆 وصول كامل لجميع المواد',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable content ───────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Plan card with glassmorphism ────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF181A24)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.primary
                            .withValues(alpha: isDark ? 0.18 : 0.10),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary
                              .withValues(alpha: isDark ? 0.12 : 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFff6b9d), Color(0xFFff9a3c)]),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFff6b9d)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Text('🔥 العرض الوحيد',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Cairo')),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          p.subscribeTitle,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Cairo',
                            color: isDark ? Colors.white : AppTheme.textPri,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Divider with gradient
                        Container(
                          height: 1.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppTheme.primary.withValues(alpha: 0.3),
                              AppTheme.accent.withValues(alpha: 0.2),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Features list
                        for (final f in [
                          (
                            'جميع الدروس المرئية لكل المواد',
                            Icons.play_circle_outline_rounded
                          ),
                          (
                            'ملفات PDF لجميع المواد',
                            Icons.picture_as_pdf_rounded
                          ),
                          (
                            'المدرس الذكي المخصص لكل مادة',
                            Icons.smart_toy_outlined
                          ),
                          (
                            'اختبارات قصيرة مولّدة تلقائياً',
                            Icons.quiz_outlined
                          ),
                          (
                            'حل بالكاميرا — صوّر السؤال نحله',
                            Icons.camera_alt_outlined
                          ),
                          (
                            'شهادات إتمام معتمدة',
                            Icons.workspace_premium_outlined
                          ),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGrad,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child:
                                    Icon(f.$2, size: 15, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  f.$1,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : AppTheme.textPri,
                                  ),
                                ),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Security badge ──────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                AppTheme.primary.withValues(alpha: 0.10),
                                AppTheme.accent.withValues(alpha: 0.06),
                              ]
                            : [
                                AppTheme.primary.withValues(alpha: 0.05),
                                AppTheme.accent.withValues(alpha: 0.03),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.primary
                            .withValues(alpha: isDark ? 0.15 : 0.08),
                        width: 1.5,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.success.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(Icons.verified_user_rounded,
                            color: AppTheme.success, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.isAr ? 'دفع آمن ومحمي' : 'Safe & Secure',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isDark ? Colors.white : AppTheme.textPri,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.paySecure,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppTheme.textSec,
                                  fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // ── Animated bottom CTA ──────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _loading || _purchasing
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: AnimatedPressable(
                            onTap: _purchase,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGrad,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: AppTheme.glowShadow,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.workspace_premium_rounded,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      _products.isNotEmpty
                                          ? '${p.subscribe} — ${_products.first.price}'
                                          : p.subscribe,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // ── Restore Purchases Button (Apple Guideline 3.1.1) ─
                        TextButton.icon(
                          onPressed: _purchasing ? null : _restorePurchases,
                          icon: Icon(
                            Icons.restore_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : AppTheme.textSec,
                          ),
                          label: Text(
                            p.isAr ? 'استعادة المشتريات السابقة' : 'Restore Purchases',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                              color: isDark ? Colors.white70 : AppTheme.textSec,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // ── Terms & Privacy links ─────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(AppUrls.termsOfUse);
                                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                              },
                              child: Text(
                                p.isAr ? 'شروط الاستخدام' : 'Terms of Use',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primary.withValues(alpha: 0.8),
                                  decoration: TextDecoration.underline,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                            const Text('  •  ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(AppUrls.privacyPolicy);
                                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                              },
                              child: Text(
                                p.isAr ? 'سياسة الخصوصية' : 'Privacy Policy',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primary.withValues(alpha: 0.8),
                                  decoration: TextDecoration.underline,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),

        ],
      ),
    );
  }
}
