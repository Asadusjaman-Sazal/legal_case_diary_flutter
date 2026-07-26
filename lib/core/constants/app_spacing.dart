import 'package:flutter/material.dart';

/// Semantic spacing tokens for the Justice Ledger design system.
///
/// Derived from `mockup_html_screens/justiceLedger/DESIGN.md`.
/// The base grid unit is 4 px; all values are multiples of 4 to maintain the
/// 4 px baseline rhythm. Where a mockup differs, the mockup measurement is
/// used and noted here.
///
/// Tokens below that are not in DESIGN.md's YAML block are approximations made
/// on the 4 px baseline grid, as permitted by the Alignment Addendum. Each
/// approximation is documented on the constant it applies to.
class AppSpacing {
  AppSpacing._();

  /// Base grid unit — 4 logical pixels.
  static const double unit = 4.0;

  /// Extra small — 4 px (tight inline gaps, icon-to-text distance).
  static const double xs = 4.0;

  /// Small — 8 px (compact padding, small gaps).
  static const double sm = 8.0;

  /// Medium — 16 px (standard padding, section gaps).
  static const double md = 16.0;

  /// Large — 24 px (larger section separation).
  static const double lg = 24.0;

  /// Extra large — 32 px (major section breaks).
  static const double xl = 32.0;

  /// 2× extra large — 48 px (screen-level vertical spacing).
  /// Approximation: not present in DESIGN.md YAML; derived from the 4 px
  /// baseline grid for large gaps between major screen sections.
  static const double xxl = 48.0;

  /// 3× extra large — 64 px (rare, large empty states).
  /// Approximation: not present in DESIGN.md YAML; derived from the 4 px
  /// baseline grid for very large gaps such as empty states.
  static const double xxxl = 64.0;

  /// Horizontal screen edge margin — 16 px.
  static const double edgeMargin = 16.0;

  /// Gutter between columns / list item internal spacing — 12 px.
  static const double gutter = 12.0;

  /// Condensed vertical padding inside dense list items — 12 px.
  /// Derived from DESIGN.md "Layout & Spacing": case list items use 12 px
  /// vertical padding to maximize visible rows.
  static const double listItemVertical = 12.0;

  /// Standard card internal padding — 16 px.
  /// Approximation: not present in DESIGN.md YAML; chosen as the standard
  /// 16 px padding for card content, consistent with the edge margin.
  static const double cardPadding = 16.0;

  /// Standard card border radius — 4 px.
  /// Derived from DESIGN.md "Shapes": base `rounded` token is 4 px.
  static const double cardRadius = 4.0;

  /// Bottom sheet / dialog top corner radius — 8 px.
  /// Derived from DESIGN.md "Shapes": large components use `rounded-lg` 8 px.
  static const double sheetRadius = 8.0;

  /// Small button / chip radius — 2 px.
  /// Derived from DESIGN.md "Shapes": small components use `rounded-sm` 2 px.
  static const double radiusSm = 2.0;

  /// Full pill radius.
  /// Derived from DESIGN.md "Shapes": `rounded-full` token (9999 px), used for
  /// status chips and pill-shaped elements.
  static const double radiusFull = 9999.0;

  // ----------------------------------------------------------------------
  // Helper methods to keep widget code terse and explicit.
  // ----------------------------------------------------------------------

  /// Returns a symmetric EdgeInsets from horizontal and vertical tokens.
  static EdgeInsets symmetric({
    double horizontal = 0.0,
    double vertical = 0.0,
  }) =>
      EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);

  /// Returns an EdgeInsets with only the given sides.
  static EdgeInsets only({
    double left = 0.0,
    double top = 0.0,
    double right = 0.0,
    double bottom = 0.0,
  }) =>
      EdgeInsets.only(left: left, top: top, right: right, bottom: bottom);
}
