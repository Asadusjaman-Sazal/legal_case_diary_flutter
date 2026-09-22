/// The app-wide font size step (Settings > View Settings > Font Size).
///
/// The user chooses a step in whole logical pixels, and that step is added to
/// every text size in the app. [TextScaler] is Flutter's own seam for this: it
/// travels down through `MediaQuery` to every `Text`, `TextField` and
/// `TextPainter`, so one wrap at the app root resizes the whole interface
/// without a single call site changing, and text the app did not think to
/// style is included.
///
/// The inherited scaler is *wrapped*, never replaced: the device's own font
/// size setting still applies and the step is added on top of it, so this
/// setting can only make text bigger or smaller — it can never switch the
/// platform's accessibility scaling off.
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
  /// A zero [step] is the identity and is never worth constructing; callers
  /// hand a zero step to [FontSizeScope], which drops the wrapper instead.
  const SteppedTextScaler(this.inner, this.step);

  /// The platform's own scaler, applied before the step.
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

/// Applies the user's font size step to everything below it.
///
/// Sits inside `MaterialApp.builder`, so it covers every route, dialog, sheet
/// and overlay. At the default step it adds no layer at all, which keeps the
/// tree — and every widget's `MediaQuery.of` dependency — exactly as it was
/// before this setting existed.
class FontSizeScope extends StatelessWidget {
  /// Creates the scope for [step] logical pixels, wrapping [child].
  const FontSizeScope({required this.step, required this.child, super.key});

  /// The saved step; 0 is the shipped default.
  final int step;

  /// The subtree whose text follows [step].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (step == 0) return child;
    // Fall back to the view's own metrics when there is no MediaQuery above
    // (a bare widget test, or this widget reused outside the app shell).
    final media =
        MediaQuery.maybeOf(context) ?? MediaQueryData.fromView(View.of(context));
    return MediaQuery(
      data: media.copyWith(
        textScaler: SteppedTextScaler(media.textScaler, step),
      ),
      child: child,
    );
  }
}
