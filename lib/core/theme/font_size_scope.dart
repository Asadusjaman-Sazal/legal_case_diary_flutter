/// The app-wide font size step (Settings > View Settings > Font Size).
///
/// Every screen is laid out for one standard text size, and that is what the
/// app paints: the phone's own font-size setting is **deliberately dropped**, so
/// a device set to an extreme scale can no longer clip a label, push a button
/// off its row or break a card. The only thing that may change the app's text is
/// the user's own Font Size step, chosen in Settings.
///
/// [TextScaler] is Flutter's own seam for this: it travels down through
/// `MediaQuery` to every `Text`, `TextField` and `TextPainter`, so one wrap at
/// the app root fixes the whole interface without a single call site changing,
/// and text the app did not think to style is included.
///
/// Printed output is deliberately outside this: the print tree is built by the
/// `printing` package under its own `MediaQuery`, so a PDF keeps the layout its
/// own templates define.
library;

import 'package:flutter/widgets.dart';

import '../constants/app_typography.dart';

/// A [TextScaler] that adds a fixed number of logical pixels to every size.
///
/// The step is additive rather than proportional, which is what "+1 font size"
/// means: a 12 px label becomes 13 px and a 30 px headline becomes 31 px,
/// instead of each being multiplied by a factor that would grow the large text
/// far more than the small.
@immutable
class SteppedTextScaler extends TextScaler {
  /// Wraps [inner], adding [step] logical pixels to everything it scales.
  ///
  /// The app hands it [TextScaler.noScaling] as [inner], because the phone's
  /// own scale is not wanted; a zero [step] is therefore also expressed as
  /// plain [TextScaler.noScaling], which [FontSizeScope] installs directly.
  const SteppedTextScaler(this.inner, this.step);

  /// The base scaler, applied before the step.
  final TextScaler inner;

  /// Whole logical pixels added to every font size (positive or negative).
  final int step;

  @override
  double scale(double fontSize) => inner.scale(fontSize) + step;

  /// The deprecated ratio form, estimated at the app's body size.
  ///
  /// An additive step has no single ratio — it is a larger proportion of a
  /// small text than of a headline — so the framework's backwards-compatible
  /// ratio is reported for [AppTypography.bodyLg], the size most of the app's
  /// text is set in. Nothing in the app reads it.
  @override
  double get textScaleFactor {
    const reference = AppTypography.bodyLg;
    final size = reference.fontSize!;
    return (inner.scale(size) + step) / size;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SteppedTextScaler && other.inner == inner && other.step == step;

  @override
  int get hashCode => Object.hash(inner, step);

  @override
  String toString() => 'stepped (${step >= 0 ? '+' : ''}$step px) on $inner';
}

/// Fixes the app's text size and applies the user's font size step to it.
///
/// Sits inside `MaterialApp.builder`, so it covers every route, dialog, sheet
/// and overlay. It always installs its own scaler — the inherited one is
/// **replaced**, never wrapped, so the phone's font-size setting cannot reach a
/// single widget below — and adds [step] on top of that fixed base.
class FontSizeScope extends StatelessWidget {
  /// Creates the scope for [step] logical pixels, wrapping [child].
  const FontSizeScope({required this.step, required this.child, super.key});

  /// The saved step; 0 is the shipped default.
  final int step;

  /// The subtree whose text follows [step].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Fall back to the view's own metrics when there is no MediaQuery above
    // (a bare widget test, or this widget reused outside the app shell).
    final media =
        MediaQuery.maybeOf(context) ?? MediaQueryData.fromView(View.of(context));
    return MediaQuery(
      // The base is [TextScaler.noScaling], not `media.textScaler`: the device's
      // accessibility scale is dropped on purpose, so every screen renders at
      // its designed size and only the in-app step can move it.
      data: media.copyWith(
        textScaler: step == 0
            ? TextScaler.noScaling
            : SteppedTextScaler(TextScaler.noScaling, step),
      ),
      child: child,
    );
  }
}
