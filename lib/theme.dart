import 'package:flutter/material.dart';

/// Paleta y tipografia estilo terminal (inspirado en opencode).
class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0E0E0E);
  static const inputBg = Color(0xFF161616);
  static const border = Color(0xFF2A2A2A);
  static const accent = Color(0xFF5F7EA6); // acero apagado estilo One Dark
  static const textPrimary = Color(0xFFE6E6E6);
  static const textDim = Color(0xFF6B6B6B);
  static const textFaint = Color(0xFF444444);
  static const success = Color(0xFF5FB865);
  static const error = Color(0xFFE06C6C);
  static const cursor = Color(0xFFE6E6E6);
}

/// Stack de fuentes monoespaciadas del sistema, sin necesidad de assets.
const List<String> kMonoFallback = <String>[
  'Consolas',
  'SF Mono',
  'Menlo',
  'DejaVu Sans Mono',
  'Courier New',
  'monospace',
];

const String kMonoFamily = 'monospace';

TextStyle mono({
  double size = 14,
  Color color = AppColors.textPrimary,
  FontWeight weight = FontWeight.w400,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: kMonoFamily,
    fontFamilyFallback: kMonoFallback,
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.background,
      primary: AppColors.accent,
      error: AppColors.error,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.cursor,
      selectionColor: Color(0x335F7EA6),
      selectionHandleColor: AppColors.accent,
    ),
  );
}
