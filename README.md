# منصة تم التعليمية — Flutter App

## خطوات التشغيل في Android Studio

### 1. المتطلبات
- Flutter SDK 3.16+
- Android Studio Hedgehog+
- Java 17
- حساب Firebase (مكوّن مسبقاً: tam-app-fd30f)

### 2. فتح المشروع
```bash
cd tam_app
flutter pub get
flutter run
```

### 3. ملفات مهمة تحتاج إضافتها
ضع هذه الملفات التي حملتها من Firebase Console:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### 4. Anthropic API Key
في `lib/services/ai_service.dart`:
```dart
static const String _apiKey = 'YOUR_ANTHROPIC_API_KEY';
```
احصل على مفتاحك من: https://console.anthropic.com

### 5. بيانات Firebase المكوّنة
- Project: tam-app-fd30f
- Package: com.tam.app
- Admin email: admin@eduspark.com
- Admin UID: iNyToqVuQwdQ6YP8dpH1sqveTw22

### 6. كيف يضيف الأدمن المحتوى
#### إضافة درس:
Firebase Console > Firestore > courses > {grade}_{subject} > lessons
```
{
  titleAr: "اسم الدرس بالعربية",
  titleEn: "Lesson Name in English",
  videoUrl: "https://youtube.com/watch?v=...",
  durationMinutes: 30,
  order: 1,
  isActive: true
}
```

#### إضافة PDF:
Firebase Console > Firestore > pdfs
```
{
  grade: 12,
  subject: "physics",
  type: "summary",         // أو "exam_answer"
  titleAr: "ملخص الفصل الأول",
  titleEn: "Chapter 1 Summary",
  url: "https://storage.googleapis.com/...",
  pages: 28,
  sizeMB: 2.4,
  isActive: true,
  createdAt: (server timestamp)
}
```

### 7. In-App Purchase
أنشئ المنتج في:
- App Store Connect: Product ID = `tam_6months_12kwd`
- Google Play Console: Product ID = `tam_6months_12kwd`

### 8. الميزات المبنية
✅ Firebase Auth (Email/Password + Google + Apple)
✅ Firestore — بيانات حقيقية
✅ تسجيل بالاسم — يُحفظ في Firestore
✅ Dark Mode (يُحفظ في SharedPreferences)
✅ AR/EN (يُحفظ في SharedPreferences)
✅ تغيير كلمة المرور — Firebase Auth
✅ حل بالكاميرا — Anthropic Vision API
✅ المدرس الذكي — Anthropic API
✅ اختبارات قصيرة — AI Generated
✅ شهادات/تقدم — Firestore
✅ In-App Purchase — Apple/Google Store
✅ حماية التصوير — FLAG_SECURE (Android)
✅ Streak + XP — Gamification
