import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_spacing.dart';
import 'status_colors.dart';

/// The one central [ThemeData] of the app (guideline 14.2).
abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.navy,
      primary: AppPalette.navy,
      onPrimary: AppPalette.white,
      secondary: AppPalette.blue,
      onSecondary: AppPalette.white,
      error: AppPalette.red,
      onError: AppPalette.white,
      surface: AppPalette.surface,
      onSurface: AppPalette.ink,
      outline: AppPalette.outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.background,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      extensions: const [StatusColors.stark],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.navy,
        foregroundColor: AppPalette.white,
        centerTitle: false,
        elevation: 0,
      ),
      // Phones (360 px) keep a usable dialog width (default insets are 40).
      dialogTheme: const DialogThemeData(
        insetPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppPalette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
          side: const BorderSide(color: AppPalette.outline),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: AppPalette.surface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dataTableTheme: DataTableThemeData(
        columnSpacing: AppSpacing.lg,
        horizontalMargin: AppSpacing.md,
        headingTextStyle: base.textTheme.titleSmall?.copyWith(
          color: AppPalette.navy,
          fontWeight: FontWeight.w700,
        ),
        headingRowColor: WidgetStatePropertyAll(
          colorScheme.primaryContainer.withValues(alpha: 0.35),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppPalette.surface,
        selectedIconTheme: IconThemeData(color: AppPalette.navy),
        indicatorColor: AppPalette.blueTint,
      ),
      dividerTheme: const DividerThemeData(color: AppPalette.outline, space: 1),
    );
  }
}
