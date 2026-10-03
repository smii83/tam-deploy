import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/app_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'utils/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase — Auth + FCM + Firestore + Storage + Cloud Functions
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const TamApp(),
    ),
  );
}

class TamApp extends StatelessWidget {
  const TamApp({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final themeId = p.themeId;
    // Splash bg matches current dark theme background
    final splashBg = AppTheme.allThemes.firstWhere((t) => t.id == themeId).darkBg;
    return MaterialApp(
      title: 'منصة تم التعليمية',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightFor(themeId),
      darkTheme: AppTheme.darkFor(themeId),
      themeMode: p.isDark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(p.language),
      color: splashBg,
      builder: (context, child) => Directionality(
        textDirection: p.isAr ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          color: splashBg,
          child: child!,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
