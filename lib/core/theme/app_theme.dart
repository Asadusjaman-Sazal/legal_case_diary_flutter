import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';

/// Justice Ledger light theme configuration.
///
/// Implements Phase 2 of Task 02: builds a [ThemeData] from the constants in
/// `core/constants/` and enforces the flat, stationery, high-density visual
/// style described in `mockup_html_screens/justiceLedger/DESIGN.md`.
///
/// Hard rule: no `BackdropFilter` is used anywhere.
class AppTheme {
  AppTheme._();

  /// The single light theme used by the app.
  ///
  /// When [locale] is Bengali (`bn`), the default font family and every text
  /// style are overridden to use `TiroBangla` so that Bengali text renders
  /// with the correct font. For all other locales the Justice Ledger English
  /// typography tokens are used as-is.
  static ThemeData lightTheme([Locale locale = const Locale('bn')]) {
    return _buildLightTheme(locale);
  }

  static ThemeData _buildLightTheme(Locale locale) {
    final isBengali = locale.languageCode == 'bn';
    final textTheme = isBengali
        ? _textTheme.apply(fontFamily: 'TiroBangla')
        : _textTheme;

    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: isBengali ? 'TiroBangla' : 'Inter',
      textTheme: textTheme,
      appBarTheme: _appBarTheme,
      cardTheme: _cardTheme,
      filledButtonTheme: _filledButtonTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      dividerTheme: _dividerTheme,
      iconTheme: _iconTheme,
      popupMenuTheme: _popupMenuTheme,
    );
  }

  /// Menu windows opened by [PopupMenuButton] share the app's 8 px window
  /// corner, the same shape the dropdowns and the Next Date calendar use.
  static PopupMenuThemeData get _popupMenuTheme => PopupMenuThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
    ),
  );

  // ----------------------------------------------------------------------
  // Color scheme
  // ----------------------------------------------------------------------

  static ColorScheme get _colorScheme => ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    tertiary: AppColors.tertiary,
    onTertiary: AppColors.onTertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: AppColors.onTertiaryContainer,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    surfaceContainerHighest: AppColors.surfaceContainerHighest,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainerLowest: AppColors.surfaceContainerLowest,
    surfaceBright: AppColors.surfaceBright,
    surfaceDim: AppColors.surfaceDim,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    inverseSurface: AppColors.inverseSurface,
    onInverseSurface: AppColors.inverseOnSurface,
    inversePrimary: AppColors.primaryFixedDim,
    shadow: AppColors.primary.withValues(alpha: 0.08),
    scrim: AppColors.overlay54,
    surfaceTint: Colors.transparent,
  );

  // ----------------------------------------------------------------------
  // Text theme — wires English font roles into Material text styles.
  // ----------------------------------------------------------------------

  static TextTheme get _textTheme => const TextTheme(
    displayLarge: AppTypography.headlineLg,
    displayMedium: AppTypography.headlineMd,
    displaySmall: AppTypography.titleLg,
    headlineLarge: AppTypography.headlineLg,
    headlineMedium: AppTypography.headlineMd,
    headlineSmall: AppTypography.titleLg,
    titleLarge: AppTypography.titleLg,
    titleMedium: AppTypography.titleMd,
    titleSmall: AppTypography.labelLg,
    bodyLarge: AppTypography.bodyLg,
    bodyMedium: AppTypography.bodyMd,
    bodySmall: AppTypography.bodySm,
    labelLarge: AppTypography.labelLg,
    labelMedium: AppTypography.labelMd,
    labelSmall: AppTypography.caseNumber,
  );

  // ----------------------------------------------------------------------
  // App bar
  // ----------------------------------------------------------------------

  static AppBarTheme get _appBarTheme => AppBarTheme(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.primary,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: AppTypography.headlineMd,
    iconTheme: IconThemeData(color: AppColors.primary),
    actionsIconTheme: IconThemeData(color: AppColors.primary),
    surfaceTintColor: Colors.transparent,
    shape: const Border(
      bottom: BorderSide(color: AppColors.outlineVariant, width: 1.0),
    ),
  );

  // ----------------------------------------------------------------------
  // Card — white surface + 1px cardBorder, flat / stationery aesthetic.
  // ----------------------------------------------------------------------

  static CardThemeData get _cardTheme => CardThemeData(
    color: AppColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      side: const BorderSide(color: AppColors.cardBorder, width: 1.0),
    ),
    clipBehavior: Clip.none,
  );

  // ----------------------------------------------------------------------
  // Buttons
  // ----------------------------------------------------------------------

  static FilledButtonThemeData get _filledButtonTheme => FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.surfaceContainer,
      disabledForegroundColor: AppColors.onSurfaceVariant,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      textStyle: AppTypography.labelLg,
    ),
  );

  static ElevatedButtonThemeData get _elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceContainer,
          disabledForegroundColor: AppColors.onSurfaceVariant,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          textStyle: AppTypography.labelLg,
        ),
      );

  static OutlinedButtonThemeData get _outlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.black),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          textStyle: AppTypography.labelLg,
        ),
      );

  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      textStyle: AppTypography.labelLg,
    ),
  );

  // ----------------------------------------------------------------------
  // Inputs — filled style with a bottom border that thickens on focus.
  // ----------------------------------------------------------------------

  static InputDecorationTheme get _inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceVariant,
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    border: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    ),
    enabledBorder: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    ),
    focusedBorder: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      borderSide: const BorderSide(color: AppColors.secondary, width: 2.0),
    ),
    labelStyle: AppTypography.labelLg,
    hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.tertiary),
  );

  // ----------------------------------------------------------------------
  // Dividers and icons
  // ----------------------------------------------------------------------

  static DividerThemeData get _dividerTheme => DividerThemeData(
    color: AppColors.cardBorder,
    thickness: 1.0,
    space: AppSpacing.sm,
  );

  static IconThemeData get _iconTheme =>
      IconThemeData(color: AppColors.onSurfaceVariant, size: 24.0);
}
