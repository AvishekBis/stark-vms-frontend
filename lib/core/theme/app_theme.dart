import 'package:flutter/material.dart';

import 'app_decorations.dart';
import 'app_palette.dart';
import 'app_spacing.dart';
import 'status_colors.dart';

/// The one central [ThemeData] of the app (guideline 14.2), in the "navy and gold" look
/// (ADR 0025).
abstract final class AppTheme {
  /// Bundled display face (see `pubspec.yaml`). Headings and figures only — body text stays on
  /// the default sans, which is easier to read at small sizes and in dense tables.
  static const String displayFont = 'PlayfairDisplay';

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.navy,
      primary: AppPalette.navy,
      onPrimary: AppPalette.white,
      primaryContainer: AppPalette.goldSoft,
      onPrimaryContainer: AppPalette.navyDeep,
      secondary: AppPalette.gold,
      onSecondary: AppPalette.navyDeep,
      secondaryContainer: AppPalette.goldTint,
      onSecondaryContainer: AppPalette.goldInk,
      error: AppPalette.red,
      onError: AppPalette.white,
      surface: AppPalette.surface,
      onSurface: AppPalette.ink,
      surfaceContainerHighest: AppPalette.surfaceMuted,
      onSurfaceVariant: AppPalette.inkMuted,
      outline: AppPalette.outline,
      outlineVariant: AppPalette.outlineSoft,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.background,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      extensions: const [StatusColors.stark],
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.navy,
        foregroundColor: AppPalette.white,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: displayFont,
          fontSize: 21,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: AppPalette.white,
        ),
      ),
      // Phones (360 px) keep a usable dialog width (default insets are 40).
      dialogTheme: DialogThemeData(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        backgroundColor: AppPalette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radius),
          side: const BorderSide(color: AppPalette.goldSoft),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: displayFont,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppPalette.navy,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppPalette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: const Color(0x140E2A4A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radius),
          side: const BorderSide(color: AppPalette.outlineSoft),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: _inputBorder(AppPalette.outline),
        enabledBorder: _inputBorder(AppPalette.outline),
        focusedBorder: _inputBorder(AppPalette.navy, width: 2),
        errorBorder: _inputBorder(AppPalette.red),
        focusedErrorBorder: _inputBorder(AppPalette.red, width: 2),
        filled: true,
        fillColor: AppPalette.surface,
        labelStyle: const TextStyle(color: AppPalette.inkMuted),
        floatingLabelStyle: const TextStyle(color: AppPalette.navy),
        prefixIconColor: AppPalette.inkMuted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          backgroundColor: AppPalette.navy,
          foregroundColor: AppPalette.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          foregroundColor: AppPalette.navy,
          side: const BorderSide(color: AppPalette.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppPalette.navy),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.surfaceMuted,
        side: const BorderSide(color: AppPalette.outlineSoft),
        shape: const StadiumBorder(),
        labelStyle: base.textTheme.labelLarge?.copyWith(color: AppPalette.ink),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.navyDeep,
        contentTextStyle: const TextStyle(color: AppPalette.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppPalette.navy,
        unselectedLabelColor: AppPalette.inkMuted,
        indicatorColor: AppPalette.gold,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppPalette.outlineSoft,
      ),
      dataTableTheme: const DataTableThemeData(
        columnSpacing: AppSpacing.lg,
        horizontalMargin: AppSpacing.md,
        dividerThickness: 1,
        headingTextStyle: TextStyle(
          color: AppPalette.navy,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
        headingRowColor: WidgetStatePropertyAll(AppPalette.surfaceMuted),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppPalette.surface,
        selectedIconTheme: const IconThemeData(color: AppPalette.navy),
        unselectedIconTheme: const IconThemeData(color: AppPalette.inkMuted),
        indicatorColor: AppPalette.goldTint,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        selectedLabelTextStyle: const TextStyle(
          color: AppPalette.navy,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(color: AppPalette.inkMuted),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.outlineSoft,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.navy,
      ),
      iconTheme: const IconThemeData(color: AppPalette.inkMuted),
    );
  }

  /// Serif for the display sizes and headlines, the default sans everywhere else.
  static TextTheme _textTheme(TextTheme base) {
    TextStyle display(TextStyle? style, {double? size, FontWeight? weight}) {
      return (style ?? const TextStyle()).copyWith(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: weight ?? FontWeight.w600,
        color: AppPalette.navy,
        letterSpacing: 0.2,
        height: 1.2,
      );
    }

    return base.copyWith(
      displayLarge: display(base.displayLarge),
      displayMedium: display(base.displayMedium),
      displaySmall: display(base.displaySmall),
      headlineLarge: display(base.headlineLarge, size: 32),
      headlineMedium: display(base.headlineMedium, size: 26),
      headlineSmall: display(base.headlineSmall, size: 22),
      titleLarge: display(base.titleLarge, size: 20),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppPalette.ink,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppPalette.ink,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: AppPalette.ink,
        height: 1.45,
      ),
      bodySmall: base.bodySmall?.copyWith(color: AppPalette.inkMuted),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: base.labelSmall?.copyWith(
        color: AppPalette.inkMuted,
        letterSpacing: 0.6,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
