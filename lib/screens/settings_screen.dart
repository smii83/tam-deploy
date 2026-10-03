import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/app_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_data_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_urls.dart';
import 'auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = '', _email = '';
  int _grade = 12;
  bool _subscribed = false;
  bool _showPwdForm = false, _savingPwd = false;
  final _opCtrl = TextEditingController();
  final _npCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load user info immediately from provider (no network call)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromProvider());
  }

  @override
  void dispose() {
    _opCtrl.dispose();
    _npCtrl.dispose();
    _cpCtrl.dispose();
    super.dispose();
  }

  /// Fill UI fields instantly from AppProvider cache, then fetch subscription in background.
  Future<void> _loadFromProvider() async {
    if (!mounted) return;
    final p = context.read<AppProvider>();
    final ud = p.userData ?? {};
    final firebaseUser = FirebaseAuth.instance.currentUser;

    // Name: prefer Firestore userData, then SharedPreferences cache, then Firebase displayName
    final pbName = (ud['name'] as String?)?.trim() ?? '';
    final cachedName = p.cachedName;
    final fbName = firebaseUser?.displayName?.trim() ?? '';
    String resolvedName = pbName.isNotEmpty
        ? pbName
        : (cachedName.isNotEmpty ? cachedName : fbName);
    if (resolvedName.isEmpty) {
      // Last resort: derive from email
      final email = (ud['email'] as String?)?.isNotEmpty == true
          ? ud['email'] as String
          : (p.cachedEmail.isNotEmpty
              ? p.cachedEmail
              : firebaseUser?.email ?? '');
      resolvedName = email.isNotEmpty ? email.split('@')[0] : 'طالب';
    }

    // Email: prefer Firestore, then cached, then Firebase
    final resolvedEmail = (ud['email'] as String?)?.isNotEmpty == true
        ? ud['email'] as String
        : (p.cachedEmail.isNotEmpty
            ? p.cachedEmail
            : firebaseUser?.email ?? '');

    final resolvedGrade = (ud['grade'] is int)
        ? ud['grade'] as int
        : ((ud['grade'] as num?)?.toInt() ?? 12);

    setState(() {
      _name = resolvedName;
      _email = resolvedEmail;
      _grade = resolvedGrade;
    });

    // Check subscription in background (network call)
    final uid = firebaseUser?.uid;
    if (uid != null) {
      final isSub = await FirestoreDataService.isSubscribed(uid);
      if (!mounted) return;
      setState(() {
        _subscribed = isSub;
      });
    }
  }

  Future<void> _changePwd() async {
    final p = context.read<AppProvider>();
    if (_npCtrl.text != _cpCtrl.text) {
      _snack(p.pwdMismatch);
      return;
    }
    if (_npCtrl.text.length < 6) {
      _snack(p.pwdTooShort);
      return;
    }
    setState(() => _savingPwd = true);
    final err = await context.read<AuthService>().changePassword(
          oldPassword: _opCtrl.text,
          newPassword: _npCtrl.text,
        );
    setState(() {
      _savingPwd = false;
      _showPwdForm = false;
    });
    _snack(err != null ? '${p.pwdError}: $err ❌' : p.pwdChanged);
    if (err == null) {
      _opCtrl.clear();
      _npCtrl.clear();
      _cpCtrl.clear();
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _openEmail() async {
    final uri = Uri.parse('mailto:${AppUrls.supportEmail}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showDeleteAccountDialog(AppProvider p) async {
    final pwdCtrl = TextEditingController();
    bool deleting = false;
    final user = FirebaseAuth.instance.currentUser;
    final isPasswordUser = user?.providerData.any((prov) => prov.providerId == 'password') ?? false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              Text(p.isAr ? 'حذف الحساب' : 'Delete Account',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Cairo', color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.isAr
                    ? '⚠️ هذا الإجراء لا يمكن التراجع عنه.\nسيتم حذف جميع بياناتك (التقدم، نتائج الاختبارات، الاشتراك) بشكل نهائي.'
                    : '⚠️ This action cannot be undone.\nAll your data (progress, quiz results, subscription) will be permanently deleted.',
                style: const TextStyle(fontSize: 12, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 8),
              // ── Subscription cancellation warning ──────────────────────
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Text(
                  p.deleteWarning,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Cairo',
                    color: Colors.orange,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (isPasswordUser) ...[
                TextField(
                  controller: pwdCtrl,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: p.isAr ? 'أدخل كلمة مرورك للتأكيد' : 'Enter your password to confirm',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.isAr
                              ? 'تم التحقق من هويتك عبر تسجيل الدخول المباشر (Apple / Google).'
                              : 'Identity verified via Apple / Google Sign-In.',
                          style: const TextStyle(fontSize: 11, fontFamily: 'Cairo', color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(p.isAr ? 'إلغاء' : 'Cancel'),
            ),
            if (deleting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (isPasswordUser && pwdCtrl.text.isEmpty) return;
                  setD(() => deleting = true);
                  // Capture all context-dependent refs BEFORE first await
                  final authService = context.read<AuthService>();
                  final appProvider = context.read<AppProvider>();
                  final nav = Navigator.of(context);
                  final err = await authService.deleteAccount(
                    password: isPasswordUser ? pwdCtrl.text : null,
                  );
                  if (!mounted) return;
                  nav.pop();
                  if (err != null) {
                    _snack('❌ $err');
                  } else {
                    await appProvider.clearUserData();
                    if (!mounted) return;
                    nav.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                },
                child: Text(p.isAr ? 'حذف نهائي' : 'Delete', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
    pwdCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(p.settings), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile Card ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.gradientFor(p.themeId),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: p.isDark ? 0.20 : 0.40),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        _email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.school_outlined,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'الصف $_grade • ${_subscribed ? p.subscribed : "غير مشترك"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Appearance ────────────────────────────────────────
          _sectionLabel(p.appearance, p),
          _settingCard([
            _settingRow(
              icon: Icons.dark_mode_outlined,
              iconBg: AppTheme.primaryFor(p.themeId).withValues(alpha: p.isDark ? 0.25 : 0.12),
              iconColor: AppTheme.primaryFor(p.themeId),
              title: p.darkMode,
              subtitle: p.isDark ? 'مفعّل' : 'غير مفعّل',
              trailing: Switch(
                value: p.isDark,
                onChanged: (_) => p.toggleDark(),
                activeThumbColor: Colors.white,
                activeTrackColor: AppTheme.primaryFor(p.themeId).withValues(alpha: 0.5),
                thumbColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? Colors.white : null,
                ),
              ),
            ),
          ], p),

          // ── Theme Picker ───────────────────────────────────────
          _sectionLabel(p.isAr ? 'الثيم' : 'Theme', p),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryFor(p.themeId).withValues(alpha: p.isDark ? 0.30 : 0.15)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.isAr ? 'اختر ثيمك المفضل' : 'Choose your theme',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryFor(p.themeId),
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: AppTheme.allThemes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final t = AppTheme.allThemes[i];
                      final selected = p.themeId == t.id;
                      return GestureDetector(
                        onTap: () => p.setTheme(t.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: 74,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: t.gradColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color:
                                  selected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(t.emoji,
                                  style: const TextStyle(fontSize: 26)),
                              const SizedBox(height: 4),
                              Text(
                                t.nameAr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Cairo',
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (selected)
                                const Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Icon(Icons.check_circle,
                                      color: Colors.white, size: 13),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Language ──────────────────────────────────────────
          _sectionLabel(p.languageLabel, p),
          _settingCard([
            _settingRow(
              icon: Icons.language_outlined,
              iconBg: AppTheme.primaryFor(p.themeId).withValues(alpha: p.isDark ? 0.25 : 0.12),
              iconColor: AppTheme.primaryFor(p.themeId),
              title: p.languageLabel,
              subtitle: p.isAr ? 'العربية' : 'English',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _langBtn('ع', 'ar', p),
                  const SizedBox(width: 6),
                  _langBtn('EN', 'en', p),
                ],
              ),
            ),
          ], p),

          // ── Account ───────────────────────────────────────────
          _sectionLabel(p.account, p),
          _settingCard([
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.primaryFor(p.themeId).withValues(alpha: p.isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: AppTheme.primaryFor(p.themeId),
                  size: 15,
                ),
              ),
              title: Text(
                p.changePwd,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'اضغط لتغيير كلمة المرور',
                style: TextStyle(fontSize: 10, color: AppTheme.textSec),
              ),
              trailing: Icon(
                _showPwdForm ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              onTap: () => setState(() => _showPwdForm = !_showPwdForm),
            ),
          ], p),
          if (_showPwdForm) _pwdForm(p),

          // ── Contact Us ────────────────────────────────────────
          _sectionLabel(p.isAr ? 'تواصل معنا' : 'Contact Us', p),
          _settingCard([
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: AppTheme.gradientFor(p.themeId),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              title: Text(
                p.isAr ? 'البريد الإلكتروني للتواصل' : 'Contact Support Email',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                AppUrls.supportEmail,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.primaryFor(p.themeId),
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.gradientFor(p.themeId),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p.isAr ? 'مراسلة' : 'Email',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              onTap: _openEmail,
            ),
          ], p),

          // ── About ─────────────────────────────────────────────
          _sectionLabel(p.about, p),
          _settingCard([
            _settingRow(
              icon: Icons.info_outline,
              iconBg: AppTheme.primaryFor(p.themeId).withValues(alpha: p.isDark ? 0.25 : 0.12),
              iconColor: AppTheme.primaryFor(p.themeId),
              title: p.version,
              subtitle: 'منصة تَم التعليمية',
              trailing: const SizedBox(),
            ),
          ], p),

          const SizedBox(height: 12),

          // ── Legal (Privacy Policy & Terms) ────────────────────
          _sectionLabel(p.isAr ? 'القانوني' : 'Legal', p),
          _settingCard([
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.primaryFor(p.themeId).withValues(alpha: p.isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.privacy_tip_outlined, color: AppTheme.primaryFor(p.themeId), size: 15),
              ),
              title: Text(p.isAr ? 'سياسة الخصوصية' : 'Privacy Policy',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
              trailing: const Icon(Icons.open_in_new_rounded, size: 16),
              onTap: () => _openUrl(AppUrls.privacyPolicy),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.primaryFor(p.themeId).withValues(alpha: p.isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.gavel_rounded, color: AppTheme.primaryFor(p.themeId), size: 15),
              ),
              title: Text(p.isAr ? 'شروط الاستخدام' : 'Terms of Use',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
              trailing: const Icon(Icons.open_in_new_rounded, size: 16),
              onTap: () => _openUrl(AppUrls.termsOfUse),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.primaryFor(p.themeId).withValues(alpha: p.isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.restore_rounded, color: AppTheme.primaryFor(p.themeId), size: 15),
              ),
              title: Text(p.isAr ? 'استعادة المشتريات السابقة' : 'Restore Purchases',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              onTap: () async {
                final isAr = p.isAr;
                _snack(isAr
                    ? 'جاري التحقق من المشتريات السابقة واستعادتها...'
                    : 'Checking and restoring previous purchases...');
                try {
                  await InAppPurchase.instance.restorePurchases();
                } catch (_) {
                  _snack(isAr
                      ? 'تعذر استعادة المشتريات حالياً'
                      : 'Could not restore purchases');
                }
              },
            ),
          ], p),

          const SizedBox(height: 12),

          // ── Logout ────────────────────────────────────────────
          ElevatedButton.icon(
            icon: const Icon(Icons.logout, size: 18),
            label: Text(p.logout),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              foregroundColor: Colors.red,
              elevation: 0,
              side: BorderSide(color: Colors.red.withValues(alpha: 0.2)),
              padding: const EdgeInsets.all(14),
            ),
            onPressed: () async {
              // Show confirmation dialog before logging out
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(p.logoutConfirmTitle,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
                    ],
                  ),
                  content: Text(
                    p.logoutConfirmMsg,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Cairo'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(p.cancel, style: TextStyle(fontFamily: 'Cairo', color: AppTheme.textSec)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(p.logout, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              if (!context.mounted) return;
              final appProvider = context.read<AppProvider>();
              final auth = context.read<AuthService>();
              final nav = Navigator.of(context);
              await appProvider.clearUserData();
              await auth.logout();
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );

            },
          ),

          const SizedBox(height: 12),

          // ── Delete Account (Apple App Store Guideline 5.1.1-v) ─
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
              label: Text(
                p.isAr ? 'حذف الحساب نهائياً' : 'Delete Account',
                style: const TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.withValues(alpha: 0.35)),
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _showDeleteAccountDialog(p),
            ),
          ),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, AppProvider p) {
    final themeId = p.themeId;
    final primary = AppTheme.primaryFor(themeId);

    // 🌸 Sakura Dream — emoji bubble header
    if (themeId == AppThemeId.sakuraDream) {
      return Padding(
        padding: const EdgeInsets.only(right: 4, left: 4, bottom: 8, top: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, const Color(0xFF9B27AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 🪟 Win Flux — UPPERCASE gray label Windows style
    if (themeId == AppThemeId.winFlux) {
      return Padding(
        padding: const EdgeInsets.only(right: 4, left: 4, bottom: 4, top: 14),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            color: p.isDark ? Colors.white60 : Colors.black45,
            fontWeight: FontWeight.w700,
            fontFamily: 'Cairo',
            letterSpacing: .6,
          ),
        ),
      );
    }

    // Default: Deep Space / TAM Indigo / Arctic Glass
    return Padding(
      padding: const EdgeInsets.only(right: 4, left: 4, bottom: 6, top: 12),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          color: primary,
          fontWeight: FontWeight.w800,
          fontFamily: 'Cairo',
          letterSpacing: .4,
        ),
      ),
    );
  }

  Widget _settingCard(List<Widget> children, AppProvider p) {
    final themeId = p.themeId;
    final primary = AppTheme.primaryFor(themeId);

    // 🌸 Sakura Dream — bubbly pink card with soft border
    if (themeId == AppThemeId.sakuraDream) {
      return Container(
        decoration: BoxDecoration(
          color: p.isDark
              ? const Color(0xFF2D0A3A).withValues(alpha: 0.80)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: primary.withValues(alpha: p.isDark ? 0.35 : 0.20),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: p.isDark ? 0.12 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(children: children),
      );
    }

    // 🪟 Win Flux — flat rectangle sharp Windows 11 style
    if (themeId == AppThemeId.winFlux) {
      return Container(
        decoration: BoxDecoration(
          color: p.isDark
              ? const Color(0xFF2C2C2C)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: p.isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFD0D0D0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.isDark ? 0.20 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 14,
                  endIndent: 14,
                  color: p.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE8E8E8),
                ),
            ],
          ],
        ),
      );
    }

    // Default: Deep Space / TAM Indigo / Arctic Glass
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primary.withValues(alpha: p.isDark ? 0.25 : 0.12),
          width: 1.2,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(children: children),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: AppTheme.textSec),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      );

  Widget _langBtn(String label, String lang, AppProvider p) {
    final themePrimary = AppTheme.primaryFor(p.themeId);
    final isSelected = p.language == lang;
    return GestureDetector(
      onTap: () => p.setLanguage(lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? themePrimary : themePrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : themePrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _pwdForm(AppProvider p) => Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryFor(p.themeId).withValues(alpha: p.isDark ? 0.25 : 0.12),
          ),
        ),
        child: Column(
          children: [
            TextField(
              controller: _opCtrl,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration:
                  const InputDecoration(hintText: 'كلمة المرور الحالية'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _npCtrl,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration:
                  const InputDecoration(hintText: 'كلمة المرور الجديدة'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cpCtrl,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                hintText: 'تأكيد كلمة المرور الجديدة',
              ),
            ),
            const SizedBox(height: 12),
            _savingPwd
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _changePwd, child: Text(p.changePwd)),
          ],
        ),
      );
}
