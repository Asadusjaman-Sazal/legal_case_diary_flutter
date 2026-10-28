/// The shared `AlertDialog` wrapper every confirmation window uses.
///
/// It applies the standard frame from [AppDialogMetrics] — 8 px corner,
/// 280–420 px elastic width, 85 % height cap with scrolling, centred 112 x 48
/// actions — while keeping the caller's title, content and action handlers
/// exactly as they were. The action plan is resolved in a `LayoutBuilder`
/// **outside** the dialog: `AlertDialog` asks its subtree for intrinsic sizes,
/// which a `LayoutBuilder` cannot answer.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_dialog_metrics.dart';
import 'app_dialog_actions.dart';

/// The default side inset of a shared window (the Exit App window's).
const EdgeInsets appDialogInset = EdgeInsets.symmetric(
  horizontal: 40,
  vertical: 24,
);

/// Shows a pop-over window with the shared frame.
///
/// [actions] build the same labels and handlers the window had; [actionMode]
/// picks the adaptive pair rule (default), the Invite Code wrap (3+) or
/// always-stacked. They receive the dialog's own context, so `pop` closes the
/// window even when the caller's screen has since been replaced.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required Widget title,
  Widget? content,
  required List<AppDialogAction> Function(BuildContext dialogContext) actions,
  AppDialogActionMode actionMode = AppDialogActionMode.pair,
  EdgeInsets? insetPadding,
  ShapeBorder? shape,
  bool barrierDismissible = true,
  bool scrollable = true,
  Key? dialogKey,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => AppDialogFrame(
      title: title,
      content: content,
      actions: actions,
      actionMode: actionMode,
      insetPadding: insetPadding,
      shape: shape,
      scrollable: scrollable,
      dialogKey: dialogKey,
    ),
  );
}

/// The shared window frame as a widget, for windows that carry their own state.
///
/// Place it at the root of a `showDialog` builder, as [showAppDialog] does, so
/// its `LayoutBuilder` sits above the `AlertDialog` and can measure the actions.
class AppDialogFrame extends StatelessWidget {
  /// Creates the frame around a caller's title, content and actions.
  const AppDialogFrame({
    required this.title,
    this.content,
    required this.actions,
    this.actionMode = AppDialogActionMode.pair,
    this.insetPadding,
    this.shape,
    this.scrollable = true,
    this.dialogKey,
    this.actionsFooter,
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
    super.key,
  });

  /// The caller's title widget.
  final Widget title;

  /// The caller's content, unchanged.
  final Widget? content;

  /// Builds the actions in this window's own context.
  final List<AppDialogAction> Function(BuildContext dialogContext) actions;

  /// How the action set is laid out.
  final AppDialogActionMode actionMode;

  /// The window's side inset; the Exit App's 40 px when null.
  final EdgeInsets? insetPadding;

  /// A shape override; the shared 8 px corner when null.
  final ShapeBorder? shape;

  /// Whether the body scrolls inside the 85 % height cap.
  final bool scrollable;

  /// A key for the dialog.
  final Key? dialogKey;

  /// An extra row under the actions, inside the action area (the client
  /// notification prompt's Remember choice).
  final Widget? actionsFooter;

  /// The window's own inner paddings, where a window keeps its own spacing.
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;

  @override
  Widget build(BuildContext context) {
    final inset = insetPadding ?? appDialogInset;
    final textStyle =
        (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).merge(
          AppDialogMetrics.actionTextStyle,
        );
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final actionsNow = actions(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.max(
          1.0,
          constraints.maxWidth - inset.horizontal,
        );
        final panelMax = math.min(available, AppDialogMetrics.maxWidth);
        final plan = resolveAppDialogActionPlan(
          actions: actionsNow,
          roomWidth: math.max(
            0.0,
            panelMax - AppDialogMetrics.actionAreaPadding,
          ),
          textStyle: textStyle,
          textScaler: textScaler,
          textDirection: direction,
          mode: actionMode,
        );
        final minPanel = plan.placement == AppDialogActionPlacement.row
            ? math.min(
                math.max(
                  AppDialogMetrics.minWidth,
                  plan.requiredWidth + AppDialogMetrics.actionAreaPadding,
                ),
                panelMax,
              )
            : math.min(AppDialogMetrics.minWidth, panelMax);
        // The route lays the window out with tight screen constraints, so the
        // 85 % cap has to ride inside AlertDialog's own constraint box.
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final availableHeight = math.max(
          0.0,
          constraints.maxHeight - inset.vertical - keyboard,
        );
        return AlertDialog(
          key: dialogKey,
          shape: shape ?? AppDialogMetrics.shape,
          insetPadding: inset,
          scrollable: scrollable,
          constraints: BoxConstraints(
            minWidth: minPanel,
            maxWidth: panelMax,
            maxHeight: availableHeight * AppDialogMetrics.maxHeightFactor,
          ),
          title: title,
          content: content,
          titlePadding: titlePadding,
          contentPadding: contentPadding,
          actionsPadding: actionsPadding,
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            if (plan.actions.isNotEmpty || actionsFooter != null)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (plan.actions.isNotEmpty) AppDialogActions(plan: plan),
                  if (actionsFooter != null) Center(child: actionsFooter!),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// A two-action confirmation on the shared frame, returning the answer.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  AppDialogActionKind confirmKind = AppDialogActionKind.destructive,
  bool barrierDismissible = true,
  EdgeInsets? insetPadding,
  AppDialogActionMode actionMode = AppDialogActionMode.pair,
  Key? confirmKey,
  Key? cancelKey,
}) async {
  final l = AppLocalizations.of(context);
  final result = await showAppDialog<bool>(
    context,
    title: Text(title),
    content: message == null ? null : Text(message),
    barrierDismissible: barrierDismissible,
    insetPadding: insetPadding,
    actionMode: actionMode,
    actions: (dialogContext) => [
      AppDialogAction(
        label: cancelLabel ?? l.sharedActions_cancel,
        key: cancelKey,
        onPressed: () => Navigator.of(dialogContext).pop(false),
      ),
      AppDialogAction(
        label: confirmLabel,
        kind: confirmKind,
        key: confirmKey,
        onPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    ],
  );
  return result ?? false;
}

/// A one-action notice on the shared frame.
Future<void> showAppNoticeDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? closeLabel,
  Key? closeKey,
}) async {
  final l = AppLocalizations.of(context);
  await showAppDialog<void>(
    context,
    title: Text(title),
    content: Text(message),
    actions: (dialogContext) => [
      AppDialogAction(
        label: closeLabel ?? l.sharedActions_close,
        key: closeKey,
        onPressed: () => Navigator.of(dialogContext).pop(),
      ),
    ],
  );
}

/// The shared frame for windows that draw their own body (Invite Code, Join a
/// Firm, the firm rename, the passphrase windows).
///
/// The caller supplies the whole body exactly as it was — title, fields, code
/// box, notes — and the actions are drawn in the shared action area beneath it.
/// The window is elastic between 280 and 420 px, capped at 85 % of the route's
/// available height, and the body scrolls beyond the cap.
class AppContentDialogFrame extends StatelessWidget {
  /// Creates the frame around a caller's body and actions.
  const AppContentDialogFrame({
    required this.body,
    required this.actions,
    this.actionMode = AppDialogActionMode.pair,
    this.insetPadding,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.backgroundColor,
    this.shape,
    this.dialogKey,
    super.key,
  });

  /// The window's own content, unchanged.
  final Widget body;

  /// Builds the actions in this window's own context.
  final List<AppDialogAction> Function(BuildContext dialogContext) actions;

  /// How the action set is laid out.
  final AppDialogActionMode actionMode;

  /// The window's side inset.
  final EdgeInsets? insetPadding;

  /// The space between the window's edge and its content.
  final EdgeInsets padding;

  /// The panel colour; the dialog theme's when null.
  final Color? backgroundColor;

  /// A shape override; the shared 8 px corner when null.
  final ShapeBorder? shape;

  /// A key for the dialog.
  final Key? dialogKey;

  @override
  Widget build(BuildContext context) {
    final inset = insetPadding ?? appDialogInset;
    final textStyle =
        (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).merge(
          AppDialogMetrics.actionTextStyle,
        );
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final actionsNow = actions(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.max(
          1.0,
          constraints.maxWidth - inset.horizontal,
        );
        final panelMax = math.min(available, AppDialogMetrics.maxWidth);
        final chrome = padding.horizontal;
        final plan = resolveAppDialogActionPlan(
          actions: actionsNow,
          roomWidth: math.max(0.0, panelMax - chrome),
          textStyle: textStyle,
          textScaler: textScaler,
          textDirection: direction,
          mode: actionMode,
        );
        final minPanel = plan.placement == AppDialogActionPlacement.row
            ? math.min(
                math.max(
                  AppDialogMetrics.minWidth,
                  plan.requiredWidth + chrome,
                ),
                panelMax,
              )
            : math.min(AppDialogMetrics.minWidth, panelMax);
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final availableHeight = math.max(
          0.0,
          constraints.maxHeight - inset.vertical - keyboard,
        );
        return Dialog(
          key: dialogKey,
          insetPadding: inset,
          backgroundColor: backgroundColor,
          clipBehavior: Clip.antiAlias,
          shape: shape ?? AppDialogMetrics.shape,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minPanel,
              maxWidth: panelMax,
              maxHeight: availableHeight * AppDialogMetrics.maxHeightFactor,
            ),
            child: IntrinsicWidth(
              child: Padding(
                padding: padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(child: SingleChildScrollView(child: body)),
                    if (plan.actions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppDialogActions(plan: plan),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
