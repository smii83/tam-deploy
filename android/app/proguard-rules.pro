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

# Suppress warnings for missing classes not used at runtime
-dontwarn com.google.firebase.messaging.**

# Image Picker & FileProvider
-keep class io.flutter.plugins.imagepicker.** { *; }

# Speech to Text & Text to Speech
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.tundralabs.fluttertts.** { *; }

# Video Player (Media3 / ExoPlayer)
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# PDF Viewer (flutter_pdfview / PdfiumAndroid)
-keep class com.shockwave.pdfium.** { *; }
-keep class com.github.barteksc.pdfviewer.** { *; }
-dontwarn com.github.barteksc.pdfviewer.**

# Suppress warnings for missing classes not used at runtime
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
