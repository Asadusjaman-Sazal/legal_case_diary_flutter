import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography tokens for the Justice Ledger design system.
///
/// English roles:
///   - Manrope for headlines
///   - Inter for body text
///   - IBM Plex Sans for labels and data (case numbers, dates)
///
/// Bengali text uses Tiro Bangla with line-height 1.5 for paragraphs.
///
/// Font families must be declared in `pubspec.yaml` under `flutter/fonts`.
class AppTypography {
  AppTypography._();

  // ----------------------------------------------------------------------
  // Font family names (must match pubspec.yaml declarations).
  // ----------------------------------------------------------------------

  static const String _manrope = 'Manrope';
  static const String _inter = 'Inter';
  static const String _ibmPlexSans = 'IBMPlexSans';
  static const String _tiroBangla = 'TiroBangla';

  // ----------------------------------------------------------------------
  // English text styles
  // ----------------------------------------------------------------------

  /// Large headline — Manrope, 30 / 38, bold.
  /// Letter spacing is `-0.02em` converted to Flutter logical pixels
  /// (`-0.02 * 30.0`).
  static const TextStyle headlineLg = TextStyle(
    fontFamily: _manrope,
    fontSize: 30.0,
    fontWeight: FontWeight.w700,
    height: 38.0 / 30.0,
    letterSpacing: -0.02 * 30.0,
    color: AppColors.primary,
  );

  /// Medium headline — Manrope, 24 / 32, semi-bold.
  static const TextStyle headlineMd = TextStyle(
    fontFamily: _manrope,
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    height: 32.0 / 24.0,
    color: AppColors.primary,
  );

  /// Large title — Manrope, 20 / 28, semi-bold.
  static const TextStyle titleLg = TextStyle(
    fontFamily: _manrope,
    fontSize: 20.0,
    fontWeight: FontWeight.w600,
    height: 28.0 / 20.0,
    color: AppColors.primary,
  );

  /// Medium title — Inter, 16 / 24, semi-bold.
  static const TextStyle titleMd = TextStyle(
    fontFamily: _inter,
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    height: 24.0 / 16.0,
    color: AppColors.onBackground,
  );

  /// Large body — Inter, 16 / 24, regular.
  static const TextStyle bodyLg = TextStyle(
    fontFamily: _inter,
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    height: 24.0 / 16.0,
    color: AppColors.onBackground,
  );

  /// Medium body — Inter, 14 / 20, regular.
  static const TextStyle bodyMd = TextStyle(
    fontFamily: _inter,
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 20.0 / 14.0,
    color: AppColors.onBackground,
  );

  /// Small body — Inter, 12 / 16, regular.
  static const TextStyle bodySm = TextStyle(
    fontFamily: _inter,
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    height: 16.0 / 12.0,
    color: AppColors.onSurfaceVariant,
  );

  /// Large label — IBM Plex Sans, 14 / 20, medium.
  static const TextStyle labelLg = TextStyle(
    fontFamily: _ibmPlexSans,
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    height: 20.0 / 14.0,
    letterSpacing: 0.1,
    color: AppColors.onSurfaceVariant,
  );

  /// Medium label — IBM Plex Sans, 12 / 16, medium.
  static const TextStyle labelMd = TextStyle(
    fontFamily: _ibmPlexSans,
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    height: 16.0 / 12.0,
    letterSpacing: 0.5,
    color: AppColors.onSurfaceVariant,
  );

  /// Case number — IBM Plex Sans, 14 / 20, bold.
  static const TextStyle caseNumber = TextStyle(
    fontFamily: _ibmPlexSans,
    fontSize: 14.0,
    fontWeight: FontWeight.w700,
    height: 20.0 / 14.0,
    letterSpacing: 0.2,
    color: AppColors.primary,
  );

  // ----------------------------------------------------------------------
  // Bengali text styles
  // ----------------------------------------------------------------------

  /// Bengali large body — Tiro Bangla, 16 / 24, regular, line-height 1.5.
  static const TextStyle bengaliBodyLg = TextStyle(
    fontFamily: _tiroBangla,
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.onBackground,
  );

  /// Bengali medium body — Tiro Bangla, 14 / 20, regular, line-height 1.5.
  static const TextStyle bengaliBodyMd = TextStyle(
    fontFamily: _tiroBangla,
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.onBackground,
  );

  /// Bengali small body — Tiro Bangla, 12 / 16, regular, line-height 1.5.
  static const TextStyle bengaliBodySm = TextStyle(
    fontFamily: _tiroBangla,
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.onSurfaceVariant,
  );

  // ----------------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------------

  /// Returns a copy of [style] with the given [color].
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Returns a copy of [style] with the given [fontWeight].
  static TextStyle withWeight(TextStyle style, FontWeight fontWeight) {
    return style.copyWith(fontWeight: fontWeight);
  }
}
