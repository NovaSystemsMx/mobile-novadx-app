# Reglas ProGuard/R8 para NovaDX (release).

# Flutter engine y embedding.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# No advertir por clases opcionales que Flutter referencia.
-dontwarn io.flutter.embedding.**
