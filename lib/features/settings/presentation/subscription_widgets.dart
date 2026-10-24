/// Small widgets shared by Manage Plan and Subscription History.
///
/// They lived privately in the details screen until the history split (0.0.624).
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';

/// A card in the Settings surface: the shared border, radius and padding.
class SubscriptionCard extends StatelessWidget {
  /// Creates the card around [child].
  const SubscriptionCard({required this.child, super.key});

  /// Card contents.
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: child,
  );
}

/// `DD/MM/YYYY, hh:mm a` in Bangladesh civil time.
///
/// Every timestamp a Bengali lawyer reads has to be the local one, so both
/// halves go through [AppDateUtils], which shifts to Bangladesh civil time
/// before formatting: `formatDateDDMMYYYY` does that for the date, and the
/// clock time is derived from the same shifted value rather than from the raw
/// instant, which would otherwise disagree with the date beside it by six hours.
String formatSubscriptionDateTime(AppLocalizations l, int epochMs) {
  final civil = AppDateUtils.bangladeshDateTime(epochMs);
  final minutes = civil.hour * 60 + civil.minute;
  return '${AppDateUtils.formatDateDDMMYYYY(epochMs, locale: l.localeName)}, '
      '${AppDateUtils.formatClockTime(minutes, locale: l.localeName)}';
}
