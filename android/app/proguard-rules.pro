# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep video player classes
-keep class com.yausername.angel.** { *; }
-keep class com.google.android.exoplayer2.** { *; }

# Keep HTML parser classes
-keep class org.jsoup.** { *; }

# Keep model classes
-keep class com.example.leaksextape_app.models.** { *; }

-dontwarn io.flutter.embedding.**
-dontwarn androidx.**
