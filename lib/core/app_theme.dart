import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const pageWidth = 640.0;
  static const fabClearance = 110.0;
}

abstract final class AppSize {
  static const metaIcon = 13.0;
  static const chipIcon = 18.0;
  static const smallIcon = 20.0;
  static const emptyIcon = 42.0;
  static const progressHeight = 5.0;
}

abstract final class AppTheme {
  static const seed = Color(0xFF326451);
  static const paper = Color(0xFFF7F8F3);

  static ThemeData create(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? paper
          : scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpace.lg),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.xl),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
