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
import '../../services/firestore_data_service.dart';
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
  bool _successShown = false;
  List<ProductDetails> _products = [];
  // Last reason the store returned no product (shown to help diagnose
  // App Store Connect / Play Console configuration problems).
  String _iapIssue = '';
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  bool get _isStoreSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_isStoreSupported) {
      try {
        _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
          _onPurchase,
          onDone: () => _purchaseSub?.cancel(),
          onError: (error) {
            debugPrint('IAP purchaseStream error: $error');
          },
        );
      } catch (e) {
        debugPrint('IAP purchaseStream setup error: $e');
      }
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
          _iapIssue = 'Product not found in store: ${res.notFoundIDs.join(', ')}';
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

  Future<void> _onPurchase(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      try {
        await _handlePurchase(p);
      } catch (e, st) {
        // Never let a store event crash the app.
        debugPrint('IAP: failed handling purchase ${p.productID}: $e\n$st');
        if (mounted) setState(() => _purchasing = false);
      }
    }
  }

  Future<void> _handlePurchase(PurchaseDetails p) async {
    switch (p.status) {
      case PurchaseStatus.pending:
        break; // waiting for the store (e.g. Ask to Buy) — keep spinner

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final ok = await _activate(p);
        // Only finish the transaction once activation succeeded. If it
        // failed we leave it open so the store re-delivers it on the next
        // launch instead of silently losing a paid purchase.
        if (ok && p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
        if (!mounted) return;
        setState(() => _purchasing = false);
        if (ok) _showSuccess();
        break;

      case PurchaseStatus.error:
        if (p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
        if (!mounted) return;
        final isAr = context.read<AppProvider>().isAr;
        setState(() => _purchasing = false);
        _snack(p.error?.message.isNotEmpty == true
            ? p.error!.message
            : (isAr
                ? 'تعذّرت عملية الدفع. يرجى المحاولة مرة أخرى.'
                : 'Payment failed. Please try again.'));
        break;

      case PurchaseStatus.canceled:
        if (p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
        if (!mounted) return;
        setState(() => _purchasing = false); // user closed the payment sheet
        break;
    }
  }

  /// Activates the subscription after a store purchase. Returns true only when
  /// the user ended up with an active subscription.
  ///
  /// 1. Tries the `activateSubscription` Cloud Function (server-side).
  /// 2. If the function is unavailable (not deployed, no network to it, …)
  ///    falls back to writing the subscription record directly to Firestore
  ///    (allowed by firestore.rules for the user's own validated record).
  Future<bool> _activate(PurchaseDetails p) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final txId = p.purchaseID?.trim() ?? '';
    final receipt = p.verificationData.serverVerificationData;
    final productId = p.productID.isNotEmpty ? p.productID : _productId;
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    final txDateMs = int.tryParse(p.transactionDate ?? '');
    // Some store events (e.g. restored) can lack a purchaseID — derive a
    // stable fallback so the same purchase can't be activated twice.
    final effectiveTxId = txId.isNotEmpty
        ? txId
        : (p.transactionDate != null
            ? 'tx_${user.uid}_${p.transactionDate}'
            : '');

    // ── 1) Cloud Function ───────────────────────────────────────────────
    if (effectiveTxId.isNotEmpty) {
      try {
        final functions = FirebaseFunctions.instanceFor(region: 'me-central1');
        await functions
            .httpsCallable('activateSubscription')
            .call({
              'productId': productId,
              'platform': platform,
              'transactionId': effectiveTxId,
              'receiptData': receipt,
              'userEmail': user.email ?? '',
              if (txDateMs != null) 'transactionDateMs': txDateMs,
            })
            .timeout(const Duration(seconds: 12));
        return true;
      } on FirebaseFunctionsException catch (fnEx) {
        debugPrint(
            'activateSubscription CF error: ${fnEx.code} — ${fnEx.message}');
      } catch (e) {
        debugPrint('activateSubscription CF exception: $e');
      }
    }

    // ── 2) Direct Firestore fallback ────────────────────────────────────
    try {
      final ok = await FirestoreDataService.activateSubscription(
        firebaseUid: user.uid,
        userEmail: user.email ?? '',
        plan: productId,
        transactionId: effectiveTxId,
        platform: platform,
      );
      if (ok) return true;
    } catch (e) {
      debugPrint('activateSubscription fallback exception: $e');
    }

    if (mounted) {
      final isAr = context.read<AppProvider>().isAr;
      _snack(isAr
          ? 'تم الدفع لكن تعذّر تفعيل الاشتراك الآن. لا تدفع مرة أخرى — أعد فتح التطبيق أو اضغط "استعادة المشتريات".'
          : 'Payment received, but activation could not complete right now. Do not pay again — reopen the app or tap "Restore Purchases".');
    }
    return false;
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
      final started = await InAppPurchase.instance.buyNonConsumable(
          purchaseParam: purchaseParam);
      if (!started && mounted) setState(() => _purchasing = false);
    } catch (e) {
      debugPrint('IAP: buyNonConsumable failed: $e, trying buyConsumable');
      try {
        final started = await InAppPurchase.instance.buyConsumable(
            purchaseParam: purchaseParam);
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
          Text(
              p.isAr ? 'تم الاشتراك بنجاح!' : 'Subscription Activated!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
              p.isAr ? 'مرحباً بك في منصة تم 🎓' : 'Welcome to TAM Platform 🎓',
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
    final priceText = _products.isNotEmpty
        ? _products.first.price
        : (p.isAr ? '\$49 (12 د.ك)' : '\$49 (12 KWD)');

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
                                    child: Text(
                                      p.isAr
                                          ? '🏆 وصول كامل لجميع المواد'
                                          : '🏆 Full Access to All Subjects',
                                      style: const TextStyle(
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
                            // Badge + Price row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [
                                      Color(0xFFff6b9d),
                                      Color(0xFFff9a3c)
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
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    priceText,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ],
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
                                    child: Icon(f.$2,
                                        size: 15, color: Colors.white),
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
                                            ? Colors.white
                                                .withValues(alpha: 0.9)
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
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textPri,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.paySecure,
                                  style: const TextStyle(
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
            ),
          ),
          // ── Animated bottom CTA ──────────────────────────────────────────
          SafeArea(
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGrad,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: AppTheme.glowShadow,
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.workspace_premium_rounded,
                                            color: Colors.white,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${p.subscribe} — $priceText',
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
                            Text(
                              p.isAr
                                  ? 'اشتراك كورس (6 أشهر) يتجدد تلقائياً ما لم يتم إلغاؤه قبل نهاية الفترة من إعدادات الحساب.'
                                  : '6-month course subscription. Auto-renews unless canceled before the end of the period in Account Settings.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Cairo',
                                color: isDark
                                    ? Colors.white54
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
                                color:
                                    isDark ? Colors.white70 : AppTheme.textSec,
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
                                      ? Colors.white70
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.parse(AppUrls.termsOfUse);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  child: Text(
                                    p.isAr ? 'شروط الاستخدام' : 'Terms of Use',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.8),
                                      decoration: TextDecoration.underline,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                                const Text('  •  ',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                                GestureDetector(
                                  onTap: () async {
                                    final uri =
                                        Uri.parse(AppUrls.privacyPolicy);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  child: Text(
                                    p.isAr
                                        ? 'سياسة الخصوصية'
                                        : 'Privacy Policy',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.8),
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
            ),
          ),
        ],
      ),
    );
  }
}
