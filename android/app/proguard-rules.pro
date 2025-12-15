# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Patrol / Testing
-keep class pl.leancode.patrol.** { *; }
-keep class androidx.test.** { *; }

# Keep Flutter entry points
-keep class com.pharmascan.app.MainActivity { *; }

# Avoid obfuscating models if they are used in reflection (Drift/json_serializable usually handles this via generated code, but safe to watch)
# -keep class com.pharmascan.app.models.** { *; }

# General Android
-dontwarn android.support.**
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
