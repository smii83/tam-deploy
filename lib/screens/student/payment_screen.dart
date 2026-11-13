import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_provider.dart';
import '../../services/auth_service.dart';
import '../../services/iap_service.dart';
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
  static const String _productId = IapService.productId;
  bool _available = false, _loading = true, _purchasing = false;
  bool _successShown = false;
  List<ProductDetails> _products = [];
  // Last reason the store returned no product (shown to help diagnose
  // App Store Connect / Play Console configuration problems).
  String _iapIssue = '';
  StreamSubscription<IapPurchaseEvent>? _purchaseSub;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  bool get _isStoreSupported => IapService.instance.isStoreSupported;

  @override
  void initState() {
    super.initState();
    if (_isStoreSupported) {
      IapService.instance.ensureListening(
        onSubscriptionActivated: () {
          if (mounted) {
            context.read<AppProvider>().setSubscribed(true);
          }
        },
      );
      _purchaseSub = IapService.instance.events.listen(_onIapEvent);
      _initIAP();
    } else {
      _loading = false;
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
    if (!_isStoreSupported) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      _available = await InAppPurchase.instance.isAvailable();
      if (!_available) {
        debugPrint('IAP: store not available on this device');
        if (mounted) setState(() => _loading = false);
        return;
      }
      final res =
          await InAppPurchase.instance.queryProductDetails({_productId});
      _iapIssue = '';
      if (res.error != null) {
        debugPrint('IAP: product query error: ${res.error?.message}');
        _iapIssue =
            '${res.error?.code ?? ''} ${res.error?.message ?? ''}'.trim();
      }
      if (res.notFoundIDs.isNotEmpty) {
        debugPrint('IAP: product(s) not found in store: ${res.notFoundIDs}');
        if (_iapIssue.isEmpty) {
          _iapIssue =
              'Product not found in store: ${res.notFoundIDs.join(', ')}';
        }
      }
      if (!mounted) return;
      setState(() {
        _products = res.productDetails;
        _loading = false;
      });
    } catch (e) {
      debugPrint('IAP: init failed: $e');
      _iapIssue = e.toString();
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onIapEvent(IapPurchaseEvent event) {
    if (!mounted) return;
    final p = context.read<AppProvider>();
    switch (event.status) {
      case IapEventStatus.pending:
        break; // waiting for the store (e.g. Ask to Buy) — keep spinner

      case IapEventStatus.activated:
        p.setSubscribed(true);
        setState(() => _purchasing = false);
        _showSuccess();
        break;

      case IapEventStatus.activationFailed:
        setState(() => _purchasing = false);
        _snack(p.isAr
            ? 'تم الدفع لكن تعذّر تفعيل الاشتراك الآن. لا تدفع مرة أخرى — أعد فتح التطبيق أو اضغط "استعادة المشتريات".'
            : 'Payment received, but activation could not complete right now. Do not pay again — reopen the app or tap "Restore Purchases".');
        break;

      case IapEventStatus.error:
        setState(() => _purchasing = false);
        _snack(event.errorMessage?.isNotEmpty == true
            ? event.errorMessage!
            : (p.isAr
                ? 'تعذّرت عملية الدفع. يرجى المحاولة مرة أخرى.'
                : 'Payment failed. Please try again.'));
        break;

      case IapEventStatus.canceled:
        setState(() => _purchasing = false);
        break;
    }
  }

  Future<void> _purchase() async {
    final isAr = context.read<AppProvider>().isAr;
    // 🔒 Security: Only official iOS and Android stores support in-app purchases.
    if (!_isStoreSupported) {
      _snack(isAr
          ? 'الاشتراك متاح فقط عبر تطبيق iOS أو Android الرسمي'
          : 'Subscriptions are only available via the official iOS or Android app');
      return;
    }
    if (_products.isEmpty) {
      // Products may have failed to load earlier (slow network) — retry once.
      setState(() => _loading = true);
      await _initIAP();
      if (!mounted) return;
      if (_products.isEmpty) {
        final base = _available
            ? (isAr
                ? 'المنتج غير متاح حالياً، حاول لاحقاً'
                : 'Subscription product is currently unavailable. Please try again later.')
            : (isAr
                ? 'متجر التطبيقات غير متاح على هذا الجهاز حالياً'
                : 'The App Store is currently unavailable on this device.');
        _snack(_iapIssue.isEmpty ? base : '$base\n($_iapIssue)');
        return;
      }
    }
    setState(() => _purchasing = true);
    final product = _products.first;
    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      // Auto-renewable subscriptions & non-consumables use buyNonConsumable
      final started = await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: purchaseParam);
      if (!started && mounted) setState(() => _purchasing = false);
    } catch (e) {
      debugPrint('IAP: buyNonConsumable failed: $e, trying buyConsumable');
      try {
        final started = await InAppPurchase.instance
            .buyConsumable(purchaseParam: purchaseParam);
        if (!started && mounted) setState(() => _purchasing = false);
      } catch (e2) {
        debugPrint('IAP: buyConsumable failed: $e2');
        if (mounted) {
          setState(() => _purchasing = false);
          _snack(isAr
              ? 'تعذّر بدء عملية الدفع. يرجى المحاولة مرة أخرى.'
              : 'Could not start the purchase flow. Please try again.');
        }
      }
    }
  }

  // ── Restore Purchases (Apple App Store Guideline 3.1.1 requirement) ───────
  Future<void> _restorePurchases() async {
    final isAr = context.read<AppProvider>().isAr;
    if (!_isStoreSupported) {
      _snack(isAr
          ? 'ميزة استعادة المشتريات متاحة فقط عبر تطبيق iOS أو Android الرسمي'
          : 'Restore Purchases is only available on the official iOS or Android app');
      return;
    }
    setState(() => _purchasing = true);
    try {
      await InAppPurchase.instance.restorePurchases();
      // Restored purchases arrive through the purchase stream (_onPurchase),
      // which stops the spinner. If nothing arrives, tell the user.
      await Future.delayed(const Duration(seconds: 6));
      if (mounted && _purchasing && !_successShown) {
        setState(() => _purchasing = false);
        _snack(isAr
            ? 'لا توجد مشتريات سابقة لاستعادتها على هذا الحساب'
            : 'No previous purchases were found for this account');
      }
    } catch (e) {
      debugPrint('IAP: restore failed: $e');
      if (mounted) {
        setState(() => _purchasing = false);
        _snack(isAr
            ? 'تعذر استعادة المشتريات حالياً. يرجى المحاولة لاحقاً'
            : 'Could not restore purchases. Please try again later.');
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _showSuccess() {
    if (_successShown) return; // restore may deliver several records at once
    _successShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
            Text(p.isAr ? 'تم الاشتراك بنجاح!' : 'Subscription Activated!',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
                p.isAr
                    ? 'مرحباً بك في منصة تم 🎓'
                    : 'Welcome to TAM Platform 🎓',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSec)),
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
                child: Center(
                  child: Text(
                    p.isAr ? 'ابدأ رحلتك التعليمية ←' : 'Start Learning →',
                    style: const TextStyle(
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isDark = p.isDark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF070913) : const Color(0xFFEEEDFF),
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF070913),
                      Color(0xFF0D1126),
                      Color(0xFF080D1B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          if (isDark) ...[
            Positioned(
              top: -70,
              left: -50,
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF7C3AED).withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF06B6D4).withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          Column(
            children: [
              // ── Premium gradient header ───────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF18143E),
                            Color(0xFF121A36),
                            Color(0xFF0B162B),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFF6C63FF),
                            Color(0xFF4F46E5),
                            Color(0xFF00B8A9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  border: isDark
                      ? Border(
                          bottom: BorderSide(
                            color: const Color(0xFF818CF8)
                                .withValues(alpha: 0.22),
                          ),
                        )
                      : null,
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6366F1)
                                .withValues(alpha: 0.16),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: SafeArea(
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
                                    color: Colors.white
                                        .withValues(alpha: isDark ? 0.08 : 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white.withValues(
                                            alpha: isDark ? 0.14 : 0.2)),
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
                                  color: Colors.white
                                      .withValues(alpha: isDark ? 0.08 : 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white.withValues(
                                          alpha: isDark ? 0.14 : 0.2)),
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
                            Container(
                              width: 52,
                              height: 52,
                              padding: EdgeInsets.all(isDark ? 6 : 0),
                              decoration: isDark
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF8B5CF6)
                                              .withValues(alpha: 0.22),
                                          const Color(0xFF06B6D4)
                                              .withValues(alpha: 0.14),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.16),
                                      ),
                                    )
                                  : null,
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
                                      color: isDark
                                          ? const Color(0xFF38BDF8)
                                              .withValues(alpha: 0.14)
                                          : Colors.white
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: isDark
                                          ? Border.all(
                                              color: const Color(0xFF38BDF8)
                                                  .withValues(alpha: 0.30),
                                            )
                                          : null,
                                    ),
                                    child: Text(
                                      p.isAr
                                          ? '🏆 وصول كامل لجميع المواد'
                                          : '🏆 Full Access to All Subjects',
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFE0F2FE)
                                            : Colors.white,
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
              ),

          // ── Scrollable content ───────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      // ── Plan card with glassmorphism ────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: isDark
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF161A31),
                                    Color(0xFF101325),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isDark
                              ? null
                              : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF818CF8)
                                    .withValues(alpha: 0.28)
                                : AppTheme.primary.withValues(alpha: 0.10),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.16)
                                  : AppTheme.primary.withValues(alpha: 0.06),
                              blurRadius: isDark ? 28 : 24,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.45 : 0.04),
                              blurRadius: isDark ? 20 : 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Plan badge row (no price shown)
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [
                                        Color(0xFFff6b9d),
                                        Color(0xFFff9a3c),
                                      ]),
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
                                    child: Text(
                                      p.isAr
                                          ? '🔥 اشتراك الكورس (6 أشهر)'
                                          : '🔥 6-Month Course Plan',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Cairo'),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 11, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF06B6D4)
                                              .withValues(alpha: 0.14)
                                          : AppTheme.primary
                                              .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF22D3EE)
                                                .withValues(alpha: 0.34)
                                            : AppTheme.primary
                                                .withValues(alpha: 0.22),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 13,
                                          color: isDark
                                              ? const Color(0xFF67E8F9)
                                              : AppTheme.primary,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          p.isAr
                                              ? 'وصول شامل وفوري'
                                              : 'Instant Full Access',
                                          style: TextStyle(
                                            color: isDark
                                                ? const Color(0xFFE0F2FE)
                                                : AppTheme.primary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
                                  (isDark
                                          ? const Color(0xFF8B5CF6)
                                          : AppTheme.primary)
                                      .withValues(alpha: isDark ? 0.45 : 0.30),
                                  (isDark
                                          ? const Color(0xFF06B6D4)
                                          : AppTheme.accent)
                                      .withValues(alpha: isDark ? 0.32 : 0.20),
                                  Colors.transparent,
                                ]),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Features list (no certificates per product policy)
                            for (final f in [
                              (
                                p.isAr
                                    ? 'جميع الدروس المرئية والتفاعلية لكل المواد'
                                    : 'All video & interactive lessons for all subjects',
                                Icons.play_circle_outline_rounded
                              ),
                              (
                                p.isAr
                                    ? 'ملفات ومذكرات PDF لجميع المواد'
                                    : 'PDF study guides & notes for all subjects',
                                Icons.picture_as_pdf_rounded
                              ),
                              (
                                p.isAr
                                    ? 'المدرس الذكي المخصص لكل مادة'
                                    : 'Dedicated AI Tutor for every subject',
                                Icons.smart_toy_outlined
                              ),
                              (
                                p.isAr
                                    ? 'اختبارات قصيرة ومراجعات ليلة الامتحان'
                                    : 'Auto-generated quizzes & exam-night reviews',
                                Icons.quiz_outlined
                              ),
                              (
                                p.isAr
                                    ? 'حل بالكاميرا — صوّر السؤال نحله خطوة بخطوة'
                                    : 'Camera Solver — snap a question for step-by-step help',
                                Icons.camera_alt_outlined
                              ),
                            ])
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: isDark
                                    ? const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10)
                                    : EdgeInsets.zero,
                                decoration: isDark
                                    ? BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.035),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.07),
                                        ),
                                      )
                                    : null,
                                child: Row(children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      gradient: isDark
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFF8B5CF6),
                                                Color(0xFF06B6D4),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : AppTheme.primaryGrad,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isDark
                                                  ? const Color(0xFF8B5CF6)
                                                  : AppTheme.primary)
                                              .withValues(
                                                  alpha: isDark ? 0.35 : 0.25),
                                          blurRadius: isDark ? 10 : 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(f.$2,
                                        size: 16, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      f.$1,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? const Color(0xFFF1F5F9)
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

                      if (!_loading &&
                          _products.isEmpty &&
                          _isStoreSupported) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.amber
                                .withValues(alpha: isDark ? 0.14 : 0.10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.amber,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.isAr
                                      ? 'تعذّر تحميل تفاصيل الاشتراك من المتجر حالياً. تأكد من اتصالك بالإنترنت ثم أعد المحاولة.'
                                      : 'Could not load subscription details from the store right now. Please check your connection and retry.',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11.5,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textPri,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() => _loading = true);
                                  _initIAP();
                                },
                                child: Text(
                                  p.retry,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Security badge ──────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF0E2223),
                                    const Color(0xFF10182C),
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
                            color: isDark
                                ? AppTheme.success.withValues(alpha: 0.28)
                                : AppTheme.primary.withValues(alpha: 0.08),
                            width: 1.4,
                          ),
                        ),
                        child: Row(children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.success
                                  .withValues(alpha: isDark ? 0.18 : 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.success
                                    .withValues(alpha: isDark ? 0.34 : 0.25),
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
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textPri,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.paySecure,
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : AppTheme.textSec,
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
            ),
          ),
          // ── Animated bottom CTA ──────────────────────────────────────────
          Container(
            decoration: isDark
                ? BoxDecoration(
                    color: const Color(0xFF0A0E1D).withValues(alpha: 0.94),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  )
                : null,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 16),
                                    decoration: BoxDecoration(
                                      gradient: isDark
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFF8B5CF6),
                                                Color(0xFF6366F1),
                                                Color(0xFF06B6D4),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : AppTheme.primaryGrad,
                                      borderRadius: BorderRadius.circular(20),
                                      border: isDark
                                          ? Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.16),
                                            )
                                          : null,
                                      boxShadow: isDark
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF7C3AED)
                                                    .withValues(alpha: 0.36),
                                                blurRadius: 22,
                                                offset: const Offset(0, 6),
                                              ),
                                            ]
                                          : AppTheme.glowShadow,
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                              Icons.workspace_premium_rounded,
                                              color: Colors.white,
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              p.subscribe,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                fontFamily: 'Cairo',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.isAr
                                    ? 'اشتراك كورس (6 أشهر) يتجدد تلقائياً ما لم يتم إلغاؤه قبل نهاية الفترة من إعدادات الحساب.'
                                    : '6-month course subscription. Auto-renews unless canceled before the end of the period in Account Settings.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Cairo',
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : AppTheme.textSec,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // ── Restore Purchases Button (Apple Guideline 3.1.1) ─
                              TextButton.icon(
                                onPressed:
                                    _purchasing ? null : _restorePurchases,
                                icon: Icon(
                                  Icons.restore_rounded,
                                  size: 16,
                                  color: isDark
                                      ? const Color(0xFFE2E8F0)
                                      : AppTheme.textSec,
                                ),
                                label: Text(
                                  p.isAr
                                      ? 'استعادة المشتريات السابقة'
                                      : 'Restore Purchases',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Cairo',
                                    color: isDark
                                        ? const Color(0xFFE2E8F0)
                                        : AppTheme.textSec,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // ── Terms & Privacy links ─────────────────────────
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      final uri = Uri.parse(AppUrls.termsOfUse);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri,
                                            mode:
                                                LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Text(
                                      p.isAr ? 'شروط الاستخدام' : 'Terms of Use',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFFA5B4FC)
                                            : AppTheme.primary
                                                .withValues(alpha: 0.8),
                                        decoration: TextDecoration.underline,
                                        decorationColor: isDark
                                            ? const Color(0xFFA5B4FC)
                                            : null,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                  Text('•',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? const Color(0xFF64748B)
                                              : Colors.grey)),
                                  GestureDetector(
                                    onTap: () async {
                                      final uri =
                                          Uri.parse(AppUrls.privacyPolicy);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri,
                                            mode:
                                                LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Text(
                                      p.isAr
                                          ? 'سياسة الخصوصية'
                                          : 'Privacy Policy',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFFA5B4FC)
                                            : AppTheme.primary
                                                .withValues(alpha: 0.8),
                                        decoration: TextDecoration.underline,
                                        decorationColor: isDark
                                            ? const Color(0xFFA5B4FC)
                                            : null,
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
              ),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }
}
