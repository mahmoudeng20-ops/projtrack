# حماية أكواد فلاتر الأساسية من التلف أثناء التشفير
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# حماية خدمات Firebase (FlutterFire) لمنع توقف التطبيق (Crash)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# حل مشكلة الكلاسات المفقودة الخاصة بـ Google Play Core في محرك فلاتر
-dontwarn com.google.android.play.core.**