import 'package:flutter/material.dart';

/// Peak의 라이딩 점수 색상 체계.
/// 초록(80+) · 노랑(50~79) · 빨강(~49) — docs/ia.md 홈 화면 컨셉 노트 참조.
abstract final class ScoreColors {
  static const good = Color(0xFF4ADE80);
  static const fair = Color(0xFFFACC15);
  static const poor = Color(0xFFF87171);

  static Color forScore(int score) {
    if (score >= 80) return good;
    if (score >= 50) return fair;
    return poor;
  }
}

abstract final class AppTheme {
  static const _seed = Color(0xFF60A5FA);
  static const _surface = Color(0xFF111318);
  static const _surfaceContainer = Color(0xFF1B1E25);

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
      surface: _surface,
      surfaceContainerHighest: _surfaceContainer,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _surface,
      appBarTheme: AppBarTheme(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceContainer,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: _surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
