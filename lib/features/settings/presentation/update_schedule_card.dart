/// The About screen's **Auto Update** card: how often to auto-check GitHub.
///
/// Body of the second collapsible button under the About screen's Update entry.
/// Defaults **folded**, and choosing an option unfolds it (mirroring the backup
/// schedule card the user named): *Off*, *Every Day*, *Every 3 Days*,
/// *Every 7 Days*, *Every Month*. The choice is stored in [UpdateMetadata]
/// (`update_frequency_days`, 0 = Off, default Every Day) and read by the
/// launch check to decide whether a check is due.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../data/update_metadata_store.dart';

/// One selectable Auto Update frequency.
class _Frequency {
  const _Frequency({required this.days, required this.icon, required this.label});
  final int days;
  final IconData icon;
  final String label;
}

/// The options, in the same order and wording as the backup schedule card.
List<_Frequency> _frequencies(AppLocalizations l) => <_Frequency>[
  _Frequency(days: 0, icon: Icons.block, label: l.settingsUpdate_frequencyOff),
  _Frequency(
    days: 1,
    icon: Icons.today,
    label: l.settingsUpdate_frequencyEveryday,
  ),
  _Frequency(
    days: 3,
    icon: Icons.calendar_view_week,
    label: l.settingsUpdate_frequencyEvery3Days,
  ),
  _Frequency(
    days: 7,
    icon: Icons.event_repeat,
    label: l.settingsUpdate_frequencyEvery7Days,
  ),
  _Frequency(
    days: 30,
    icon: Icons.calendar_month,
    label: l.settingsUpdate_frequencyEveryMonth,
  ),
];

/// The Auto Update card: a radio list of check intervals.
class UpdateScheduleCard extends ConsumerWidget {
  const UpdateScheduleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final days = ref.watch(updateMetadataProvider).frequencyDays;
    final frequencies = _frequencies(l);
    return Material(
      color: AppColors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        side: BorderSide(color: AppColors.outlineVariant),
      ),
      child: RadioGroup<int>(
        groupValue: days,
        onChanged: (days) {
          if (days != null) {
            unawaited(ref.read(updateMetadataProvider.notifier).setFrequencyDays(days));
          }
        },
        child: Column(
          children: [
            for (var i = 0; i < frequencies.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, color: AppColors.outlineVariant),
              RadioListTile<int>(
                value: frequencies[i].days,
                controlAffinity: ListTileControlAffinity.trailing,
                activeColor: AppColors.secondary,
                secondary: Icon(
                  frequencies[i].icon,
                  color: AppColors.onSurfaceVariant,
                ),
                title: Text(frequencies[i].label, style: AppTypography.bodyMd),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                horizontalTitleGap: AppSpacing.md,
                minTileHeight: 56,
              ),
            ],
          ],
        ),
      ),
    );
  }
}