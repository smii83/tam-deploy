import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS: return ios;
      default: return web;
    }
  }

  // ── Web (Chrome) ─────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDdQJvBWxCX4XmdZbH7sKPOhR68Uae7bB8',
    appId: '1:82581349835:web:tam_web_app',
    messagingSenderId: '82581349835',
    projectId: 'tam-app-fd30f',
    authDomain: 'tam-app-fd30f.firebaseapp.com',
    storageBucket: 'tam-app-fd30f.firebasestorage.app',
    measurementId: 'G-XXXXXXXXXX',
  );

  // ── Android ──────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDdQJvBWxCX4XmdZbH7sKPOhR68Uae7bB8',
    appId: '1:82581349835:android:58baaee66ca360fe42824e',
    messagingSenderId: '82581349835',
    projectId: 'tam-app-fd30f',
    storageBucket: 'tam-app-fd30f.firebasestorage.app',
  );

  // ── iOS ───────────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCKyDGUAXBa88OElt9oc2m00OwfWBOu6zM',
    appId: '1:82581349835:ios:29d2dfd19d02774f42824e',
    messagingSenderId: '82581349835',
    projectId: 'tam-app-fd30f',
    storageBucket: 'tam-app-fd30f.firebasestorage.app',
    iosBundleId: 'com.tamlearn.app',
  );
}
