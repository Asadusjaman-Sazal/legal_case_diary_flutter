/// The single source of truth for the app's pop-over window frame.
///
/// Every centred window shares one corner, one action size, one action gap and
/// one width range; a window's own title, body, fields, colours and inset stay
/// its own. See `app_dialog.dart` for the `AlertDialog` wrapper and
/// `app_dialog_actions.dart` for the adaptive action row.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

/// Measurements every pop-over window shares.
abstract final class AppDialogMetrics {
  /// The window's corner: the Exit App window's 8 px.
  static const double corner = AppSpacing.sheetRadius;

  /// Width range: never narrower than 294 (the base width, 5 % above the old
  /// 280), never wider than 420. Only a screen too narrow for 294 with its
  /// insets clamps the window below the base.
  static const double minWidth = 294;
  static const double maxWidth = 420;

  /// The narrowest side margin the frame will shrink to when that is the only
  /// thing keeping a pair off one line.
  static const double minInset = AppSpacing.md;

  /// Content beyond 85 % of the available height scrolls.
  static const double maxHeightFactor = 0.85;

  /// The Exit App window's action: 112 x 48 at 16 pt.
  static const Size actionSize = Size(112, 48);
  static const double actionTextSize = 16;

  /// The gap between two actions, on a row or stacked.
  static const double actionGap = 12;

  /// The AlertDialog's own horizontal action padding (24 each side); the
  /// action area sits inside it.
  static const double actionAreaPadding = 48;

  /// The shared window shape.
  static ShapeBorder get shape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(corner));

  /// The shared text style the action labels paint at.
  static TextStyle get actionTextStyle =>
      const TextStyle(fontSize: actionTextSize);

  /// The style for a text action.
  ///
  /// The black fill and white label are stated here rather than inherited from
  /// the global button theme (user request, 0.0.736): a shared window must not
  /// depend on another surface's colours, so no theme change can repaint its
  /// actions in another colour. A window's own [foreground] still wins.
  static ButtonStyle textAction({
    double? minWidth,
    double? minHeight,
    Color? foreground,
  }) => TextButton.styleFrom(
    minimumSize: Size(
      minWidth ?? actionSize.width,
      minHeight ?? actionSize.height,
    ),
    textStyle: actionTextStyle,
    backgroundColor: AppColors.secondary,
    foregroundColor: foreground ?? AppColors.onSecondary,
  );

  /// The style for a filled action (primary or destructive).
  static ButtonStyle filledAction({
    required Color background,
    required Color foreground,
    Color? disabledBackground,
    Color? disabledForeground,
    double? minWidth,
    double? minHeight,
  }) => FilledButton.styleFrom(
    backgroundColor: background,
    foregroundColor: foreground,
    disabledBackgroundColor: disabledBackground,
    disabledForegroundColor: disabledForeground,
    minimumSize: Size(
      minWidth ?? actionSize.width,
      minHeight ?? actionSize.height,
    ),
    textStyle: actionTextStyle,
  );

  /// The style for an outlined action.
  ///
  /// As with [textAction], the black fill, white label and black edge are named
  /// here, so the one colour a shared window's light actions can wear is the
  /// app's own action black (user request, 0.0.736).
  static ButtonStyle outlinedAction({
    double? minWidth,
    double? minHeight,
    Color? foreground,
  }) => OutlinedButton.styleFrom(
    minimumSize: Size(
      minWidth ?? actionSize.width,
      minHeight ?? actionSize.height,
    ),
    textStyle: actionTextStyle,
    backgroundColor: AppColors.secondary,
    foregroundColor: foreground ?? AppColors.onSecondary,
    side: const BorderSide(color: AppColors.secondary),
  );

  /// The primary filled action: the app's action black.
  static ButtonStyle primaryAction({double? minWidth, double? minHeight}) =>
      filledAction(
        background: AppColors.secondary,
        foreground: AppColors.onSecondary,
        minWidth: minWidth,
        minHeight: minHeight,
      );

  /// The destructive filled action.
  static ButtonStyle destructiveAction({double? minWidth, double? minHeight}) =>
      filledAction(
        background: AppColors.error,
        foreground: AppColors.onError,
        minWidth: minWidth,
        minHeight: minHeight,
      );
}
