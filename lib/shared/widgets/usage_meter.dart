/// One usage meter: what is left, how much of the limit that is, and the tally.
///
/// Shared by Manage Plan's Cases/Devices section and Manage Firm's capacity
/// card, so both screens read the same numbers in the same shape (user request:
/// the firm card must not grow a second meter).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/date_utils.dart';

/// A titled progress bar with the remaining count above it and the tally below.
class UsageMeter extends StatelessWidget {
  /// Creates one meter.
  const UsageMeter({
    required this.label,
    required this.used,
    required this.limit,
    super.key,
  });

  /// What the meter counts, e.g. *Cases* or *Seats and Devices*.
  final String label;

  /// Rows in use, or null until the device has an answer.
  final int? used;

  /// The plan's ceiling, or null when it has none.
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final known = used != null && limit != null;
    String number(int value) =>
        AppDateUtils.formatDigits(value, l.localeName, grouping: true);
    final remaining = known ? math.max(0, limit! - used!) : null;
    final fraction = known && limit! > 0
        ? (used! / limit!).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.bodyMd)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              remaining == null
                  ? '—'
                  : l.settingsSubscription_usageRemaining(number(remaining)),
              style: AppTypography.titleMd.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: AppColors.surfaceContainer,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          known
              ? l.settingsSubscription_usageOfLimit(
                  number(used!),
                  number(limit!),
                )
              : '—',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
