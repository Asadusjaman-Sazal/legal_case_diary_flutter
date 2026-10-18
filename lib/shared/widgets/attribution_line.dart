/// The app's one attribution row: a small `person_outline` beside the finished
/// sentence saying who wrote a record (firm-mode §9.9).
///
/// Shared by a case History entry's *Added By* and the Review Conflict screen's
/// *Edited By*, so the app has a single attribution style and a change to it
/// lands in one place. It draws only what it is handed: the **wording and its
/// fallback stay at each call site**, because they genuinely differ — the
/// History line is drawn only inside a chamber and names a colleague *A Chamber
/// Member*, while a conflict outside a chamber still reads *Another Device*.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

/// Icon plus label, on one line.
class AttributionLine extends StatelessWidget {
  /// Creates the row from an already-localized sentence.
  const AttributionLine({required this.label, super.key});

  /// The sentence already built by the caller, e.g. *Added By Adv. Kalam*.
  ///
  /// Built there rather than here so the two screens can keep their own
  /// fallback: this widget never decides who someone is.
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.person_outline, size: 14, color: AppColors.tertiary),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Text(
          label,
          style: AppTypography.bodySm.copyWith(color: AppColors.tertiary),
          textAlign: TextAlign.left,
        ),
      ),
    ],
  );
}
