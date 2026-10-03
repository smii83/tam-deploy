# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# In-App Purchase (Google Billing)
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Kotlin
-keep class kotlin.** { *; }
-keepclassmembers class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Multidex
-keep class androidx.multidex.** { *; }

# Prevent stripping of annotated fields (used by many plugins)
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Camera
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Video Player (ExoPlayer)
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# PDF Viewer
-keep class com.pspdfkit.** { *; }
-dontwarn com.pspdfkit.**

# Suppress warnings for missing classes not used at runtime
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
