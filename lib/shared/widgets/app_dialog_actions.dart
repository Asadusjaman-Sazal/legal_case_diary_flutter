/// The adaptive action row shared by every pop-over window.
///
/// A pair sits on one centred line while both labels fit; when they do not, the
/// pair becomes two full-width buttons, one after another. Three or more
/// actions keep their own grouping in a centred `Wrap`, and windows designed
/// with stacked actions stay stacked. The sizes come from [AppDialogMetrics].
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_dialog_metrics.dart';

/// The visual role of one window action.
enum AppDialogActionKind {
  /// Plain text action: Cancel, Close, Go Back.
  text,

  /// Filled ink action: the app's black/primary button.
  primary,

  /// Filled error action: approve/delete.
  destructive,

  /// Outlined action, used by the Invite Code window.
  outlined,
}

/// How a window's action set is laid out.
enum AppDialogActionMode {
  /// 1–2 actions: one line while they fit, full-width stacked when they do not.
  pair,

  /// 3 or more actions: a centred Wrap, never stretched (Invite Code).
  wrap,

  /// Always full width, one after another (Cancel Subscription, paywall).
  stack,
}

/// One action of a pop-over window.
class AppDialogAction {
  /// Creates an action.
  const AppDialogAction({
    required this.label,
    this.onPressed,
    this.kind = AppDialogActionKind.text,
    this.key,
    this.minWidth,
    this.minHeight,
    this.foreground,
    this.background,
    this.disabledBackground,
    this.disabledForeground,
  });

  /// The visible label.
  final String label;

  /// The tap handler; null draws the action disabled.
  final VoidCallback? onPressed;

  /// The action's visual role.
  final AppDialogActionKind kind;

  /// An optional key for tests.
  final Key? key;

  /// An optional floor replacing the shared 112 px.
  final double? minWidth;

  /// An optional height replacing the shared 48 px.
  final double? minHeight;

  /// A colour override, for windows whose text action is red.
  final Color? foreground;

  /// A colour override for a filled action.
  final Color? background;

  /// A colour override for a filled action that is disabled.
  final Color? disabledBackground;

  /// A foreground override for a filled action that is disabled.
  final Color? disabledForeground;
}

/// Where an action set landed.
enum AppDialogActionPlacement { row, stacked, wrap }

/// The resolved layout for one action set.
class AppDialogActionPlan {
  /// Creates a plan.
  const AppDialogActionPlan({
    required this.actions,
    required this.placement,
    this.requiredWidth = 0,
  });

  /// The actions, in their original order.
  final List<AppDialogAction> actions;

  /// How they are drawn.
  final AppDialogActionPlacement placement;

  /// The action-area width a one-line row needs; 0 when the set does not need
  /// the window widened.
  final double requiredWidth;

  /// Whether the set is stretched full width.
  bool get stretched => placement == AppDialogActionPlacement.stacked;
}

/// Resolves how [actions] fit in an action area [roomWidth] px wide.
///
/// Measurement happens outside the `AlertDialog`; a `LayoutBuilder` inside it
/// cannot answer the intrinsic pass. A mis-measured row still falls back to a
/// `Wrap`, so it wraps rather than painting an overflow stripe.
AppDialogActionPlan resolveAppDialogActionPlan({
  required List<AppDialogAction> actions,
  required double roomWidth,
  required TextStyle textStyle,
  required TextScaler textScaler,
  required TextDirection textDirection,
  AppDialogActionMode mode = AppDialogActionMode.pair,
}) {
  final room = roomWidth;
  final widths = [
    for (final action in actions)
      _naturalWidth(action, textStyle, textScaler, textDirection),
  ];

  if (mode == AppDialogActionMode.stack) {
    return AppDialogActionPlan(
      actions: actions,
      placement: AppDialogActionPlacement.stacked,
    );
  }
  if (mode == AppDialogActionMode.wrap || actions.length > 2) {
    return AppDialogActionPlan(
      actions: actions,
      placement: AppDialogActionPlacement.wrap,
    );
  }
  if (actions.length == 1) {
    return AppDialogActionPlan(
      actions: actions,
      placement: widths.single <= room
          ? AppDialogActionPlacement.row
          : AppDialogActionPlacement.stacked,
    );
  }
  if (actions.isEmpty) {
    return const AppDialogActionPlan(
      actions: <AppDialogAction>[],
      placement: AppDialogActionPlacement.row,
    );
  }
  final rowWidth = widths[0] + widths[1] + AppDialogMetrics.actionGap;
  if (rowWidth <= room) {
    return AppDialogActionPlan(
      actions: actions,
      placement: AppDialogActionPlacement.row,
      requiredWidth: rowWidth,
    );
  }
  return AppDialogActionPlan(
    actions: actions,
    placement: AppDialogActionPlacement.stacked,
  );
}

double _naturalWidth(
  AppDialogAction action,
  TextStyle textStyle,
  TextScaler textScaler,
  TextDirection textDirection,
) {
  final text = TextPainter.computeWidth(
    text: TextSpan(text: action.label, style: textStyle),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  );
  final padded = text + AppDialogMetrics.actionAreaPadding;
  final width = padded < (action.minWidth ?? AppDialogMetrics.actionSize.width)
      ? (action.minWidth ?? AppDialogMetrics.actionSize.width)
      : padded;
  return width;
}

/// Draws a resolved action plan inside a window.
class AppDialogActions extends StatelessWidget {
  /// Creates the action area.
  const AppDialogActions({required this.plan, super.key});

  /// The resolved plan.
  final AppDialogActionPlan plan;

  @override
  Widget build(BuildContext context) {
    if (plan.actions.isEmpty) return const SizedBox.shrink();
    final buttons = [
      for (final action in plan.actions) _button(context, action),
    ];
    switch (plan.placement) {
      case AppDialogActionPlacement.stacked:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(height: AppDialogMetrics.actionGap),
              buttons[i],
            ],
          ],
        );
      case AppDialogActionPlacement.row:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: AppDialogMetrics.actionGap,
          runSpacing: AppDialogMetrics.actionGap,
          children: buttons,
        );
      case AppDialogActionPlacement.wrap:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: AppDialogMetrics.actionGap,
          runSpacing: AppSpacing.lg,
          children: buttons,
        );
    }
  }

  Widget _button(BuildContext context, AppDialogAction action) {
    final minWidth = action.minWidth;
    final minHeight = action.minHeight;
    final child = Text(action.label, textAlign: TextAlign.center);
    switch (action.kind) {
      case AppDialogActionKind.text:
        return TextButton(
          key: action.key,
          onPressed: action.onPressed,
          style: AppDialogMetrics.textAction(
            minWidth: minWidth,
            minHeight: minHeight,
            foreground: action.foreground,
          ),
          child: child,
        );
      case AppDialogActionKind.outlined:
        return OutlinedButton(
          key: action.key,
          onPressed: action.onPressed,
          style: AppDialogMetrics.outlinedAction(
            minWidth: minWidth,
            minHeight: minHeight,
            foreground: action.foreground,
          ),
          child: child,
        );
      case AppDialogActionKind.primary:
        return FilledButton(
          key: action.key,
          onPressed: action.onPressed,
          style: AppDialogMetrics.filledAction(
            background: action.background ?? AppColors.primary,
            foreground: action.foreground ?? AppColors.onPrimary,
            disabledBackground: action.disabledBackground,
            disabledForeground: action.disabledForeground,
            minWidth: minWidth,
            minHeight: minHeight,
          ),
          child: child,
        );
      case AppDialogActionKind.destructive:
        return FilledButton(
          key: action.key,
          onPressed: action.onPressed,
          style: AppDialogMetrics.filledAction(
            background: action.background ?? AppColors.error,
            foreground: action.foreground ?? AppColors.onError,
            disabledBackground: action.disabledBackground,
            disabledForeground: action.disabledForeground,
            minWidth: minWidth,
            minHeight: minHeight,
          ),
          child: child,
        );
    }
  }
}
