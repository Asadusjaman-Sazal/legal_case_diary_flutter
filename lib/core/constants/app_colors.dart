import 'package:flutter/material.dart';

/// Justice Ledger design system color tokens.
///
/// Source: Task 02 Phase 1 and `mockup_html_screens/justiceLedger/DESIGN.md`.
class AppColors {
  AppColors._();

  // ----------------------------------------------------------------------
  // Brand / Ink palette
  // ----------------------------------------------------------------------

  /// Ink dark — primary text, app bars, headers, brand surfaces.
  static const Color primary = Color(0xFF0F172A);

  /// On-primary color.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Primary container / tinted surface for pressed/hover states.
  static const Color primaryContainer = Color(0xFF131B2E);

  /// On-primary container.
  static const Color onPrimaryContainer = Color(0xFF7C839B);

  // ----------------------------------------------------------------------
  // Action / secondary palette
  // ----------------------------------------------------------------------

  /// Active / selected black — CTAs, active states, key highlights.
  ///
  /// Was the action blue. Every active or selected state now uses the one
  /// black that the buttons, the side menu and the Language picker already
  /// share, so no screen marks a choice in blue.
  static const Color secondary = Color(0xFF000000);

  /// On-secondary color.
  static const Color onSecondary = Color(0xFFFFFFFF);

  /// Secondary container — also the unified active black (e.g. the Case Detail
  /// Next Date highlight card).
  static const Color secondaryContainer = Color(0xFF000000);

  /// On-secondary container.
  static const Color onSecondaryContainer = Color(0xFFFEFCFF);

  // ----------------------------------------------------------------------
  // Tertiary / muted palette
  // ----------------------------------------------------------------------

  /// Muted gray — secondary text, icons, borders.
  static const Color tertiary = Color(0xFF64748B);

  /// On-tertiary color.
  static const Color onTertiary = Color(0xFFFFFFFF);

  /// Tertiary container.
  static const Color tertiaryContainer = Color(0xFF0B1C30);

  /// On-tertiary container.
  static const Color onTertiaryContainer = Color(0xFF75859D);

  // ----------------------------------------------------------------------
  // Background / surface palette
  // ----------------------------------------------------------------------

  /// Parchment white — screen background.
  static const Color background = Color(0xFFF8FAFC);

  /// On-background color.
  static const Color onBackground = Color(0xFF191C1E);

  /// Pure white surface — cards, sheets.
  static const Color surface = Color(0xFFFFFFFF);

  /// Surface dim.
  static const Color surfaceDim = Color(0xFFD8DADC);

  /// Surface bright.
  static const Color surfaceBright = Color(0xFFF7F9FB);

  /// Lowest surface level.
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);

  /// Low surface level.
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);

  /// Default surface container.
  static const Color surfaceContainer = Color(0xFFECEEF0);

  /// High surface container.
  static const Color surfaceContainerHigh = Color(0xFFE6E8EA);

  /// Highest surface container.
  static const Color surfaceContainerHighest = Color(0xFFE0E3E5);

  /// Surface variant / subtle card background.
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  /// On-surface color.
  static const Color onSurface = Color(0xFF191C1E);

  /// On-surface variant — secondary text on surfaces.
  static const Color onSurfaceVariant = Color(0xFF45464D);

  /// Inverse surface.
  static const Color inverseSurface = Color(0xFF2D3133);

  /// Inverse on-surface.
  static const Color inverseOnSurface = Color(0xFFEFF1F3);

  /// 1px card border.
  static const Color cardBorder = Color(0xFFE2E8F0);

  /// Outline color.
  static const Color outline = Color(0xFF76777D);

  /// Outline variant.
  static const Color outlineVariant = Color(0xFFC6C6CD);

  // ----------------------------------------------------------------------
  // Semantic colors
  // ----------------------------------------------------------------------

  /// Urgent / overdue indicator.
  static const Color error = Color(0xFFDC2626);

  /// On-error color.
  static const Color onError = Color(0xFFFFFFFF);

  /// Error container.
  static const Color errorContainer = Color(0xFFFFDAD6);

  /// On-error container.
  static const Color onErrorContainer = Color(0xFF93000A);

  /// Active / disposed / success status.
  static const Color success = Color(0xFF059669);

  /// Success container — the pale twin of [success], pairing the way
  /// [errorContainer] pairs with [error]. Used as a field's own background when
  /// what it holds is right (the Confirm Password box once the two match).
  static const Color successContainer = Color(0xFFD1FAE5);

  /// Court notice red (used in mockup palette).
  static const Color courtNotice = Color(0xFFDC2626);

  // ----------------------------------------------------------------------
  // Fixed / tonal palette (for chips, badges, hover states)
  //
  // The pale tints below were the last blue in the palette. They now carry a
  // neutral grey instead, so nothing tints a surface blue; the tint names are
  // kept so existing call sites keep compiling.
  // ----------------------------------------------------------------------

  /// Neutral tonal tint (was the pale primary blue).
  static const Color primaryFixed = Color(0xFFE6E8EA);

  /// Neutral tonal tint, dim (was the pale primary blue).
  static const Color primaryFixedDim = Color(0xFFC6C6CD);

  /// On-primary fixed.
  static const Color onPrimaryFixed = Color(0xFF131B2E);

  /// Neutral chip / badge fill (was the pale action-blue tint).
  static const Color secondaryFixed = Color(0xFFE6E8EA);

  /// Neutral chip / card border (was the pale action-blue tint).
  static const Color secondaryFixedDim = Color(0xFFC6C6CD);

  /// Neutral card fill (was the pale blue tint).
  static const Color tertiaryFixed = Color(0xFFECEEF0);

  /// Tertiary fixed dim.
  static const Color tertiaryFixedDim = Color(0xFFC6C6CD);

  /// Subtle overlay used in place of BackdropFilter.
  static const Color overlay54 = Color(0x8A000000);

  /// Subtle neutral tint overlay for selected/hover rows (was a blue tint).
  static const Color secondaryHover = Color(0x0D000000);
}
