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
    apiKey: 'AIzaSyD6Rt1pNgLMOC6ajMWSpqiBf3Z-jFZNecw',
    appId: '1:82581349835:web:018e0cd45d48a9c942824e',
    messagingSenderId: '82581349835',
    projectId: 'tam-app-fd30f',
    authDomain: 'tam-app-fd30f.firebaseapp.com',
    storageBucket: 'tam-app-fd30f.firebasestorage.app',
    measurementId: 'G-05BF2WF4GZ',
  );
  // ── Android ──────────────────────────────────────────────────────────

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDdQJvBWxCX4XmdZbH7sKPOhR68Uae7bB8',
    appId: '1:82581349835:android:e624c1c1f3b5424042824e',
    messagingSenderId: '82581349835',
    projectId: 'tam-app-fd30f',
    storageBucket: 'tam-app-fd30f.firebasestorage.app',
  );
  // ── iOS ───────────────────────────────────────────────────────────────

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCKyDGUAXBa88OElt9oc2m00OwfWBOu6zM',
    appId: '1:82581349835:ios:52bd7d922fa3bc9e42824e',
    messagingSenderId: '82581349835',
    projectId: 'tam-app-fd30f',
    storageBucket: 'tam-app-fd30f.firebasestorage.app',
    iosClientId: '82581349835-39166noa7oa449lakj80plqsgegau8rm.apps.googleusercontent.com',
    iosBundleId: 'com.tamlearn.app',
  );
}
