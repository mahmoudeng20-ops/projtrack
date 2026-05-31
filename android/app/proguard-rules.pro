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