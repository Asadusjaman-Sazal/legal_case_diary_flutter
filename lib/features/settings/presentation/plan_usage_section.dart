/// Plan Usage: how much of a premium plan's case and device allowance is left.
///
/// The numbers mirror the server's own limits. Cases are counted in the diary
/// the tier covers — the chamber's for a chamber account, the account's own
/// otherwise — against the tier in force, and devices are the active rows of
/// the device gate against its cap. A value the device cannot answer yet reads
/// a dash rather than a guess.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/device_providers.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../shared/widgets/usage_meter.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../accounts_and_profile/data/firm_capacity.dart';
import '../../auth/data/device_registration.dart';
import '../../cases/data/local/cases_dao.dart';
import '../../payments/data/payment_plans.dart';
import 'subscription_widgets.dart';

/// Live devices against the plan's cap; [used] is null until the gate answers.
typedef _DeviceUsage = ({int? used, int cap});

/// The live case count of the diary the tier limits.
final _planCaseCountProvider = StreamProvider<int>((ref) async* {
  final firmId = ref.watch(accountProfileProvider).value?.firmId;
  final db = await ref.watch(databaseProvider.future);
  yield* CasesDao(db).watchNonDeletedCaseCount(firmId: firmId);
});

/// The device meter, from the app-wide gate.
///
/// The gate's cap is the server's answer, which is 1 for every chamber account
/// whatever its tier; the tier's own cap is the fallback for a build or a
/// moment with no gate answer.
final _planDeviceUsageProvider = Provider<_DeviceUsage>((ref) {
  final tier = ref.watch(allowanceTierProvider);
  final chamber = ref.watch(firmModeProvider);
  final state = ref.watch(deviceGateProvider).value;
  if (state != null && state.status == DeviceGateStatus.active) {
    return (used: state.devices.length, cap: state.cap);
  }
  return (used: null, cap: chamber ? 1 : (tier.deviceCap ?? 1));
});

/// The Cases and Devices meters for a live paid plan.
class PlanUsageSection extends ConsumerWidget {
  /// Creates the section.
  const PlanUsageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tier = ref.watch(allowanceTierProvider);
    // A granted premium whose stored tier is still `free` holds no wall at the
    // server (a period granted outside the ladder), so the free 50 is not its
    // ceiling and the meter states a dash.
    final caseLimit = tier == SubscriptionTier.free ? null : tier.caseCeiling;
    final caseUsed = ref.watch(_planCaseCountProvider).value;
    final devices = ref.watch(_planDeviceUsageProvider);
    // A chamber owner's seats are shared with associates, so the owner's meter
    // is the whole chamber's committed usage. An associate keeps the device meter
    // (the owner manages the shared slots).
    final chamber = ref.watch(firmModeProvider);
    final showSeats = chamber && !ref.watch(firmMemberProvider);
    final capacity = ref.watch(firmCapacityViewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.settingsSubscription_planUsage, style: AppTypography.titleMd),
        const SizedBox(height: AppSpacing.sm),
        SubscriptionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UsageMeter(
                label: l.settingsSubscription_usageCases,
                used: caseUsed,
                limit: caseLimit,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1, color: AppColors.outlineVariant),
              ),
              UsageMeter(
                label: showSeats
                    ? l.settingsSubscription_usageSeats
                    : l.devices_title,
                used: showSeats ? capacity?.used : devices.used,
                limit: showSeats ? capacity?.slots : devices.cap,
              ),
            ],
          ),
        ),
        // A chamber's cases share one ceiling, so the count can be high without
        // this account's own diary being large.
        if (chamber) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.settingsSubscription_usageFirmNote,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
        if (showSeats) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.settingsSubscription_usageSeatsNote,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if ((capacity?.signedOut ?? 0) > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.settingsSubscription_usageSignedOut(capacity!.signedOut),
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
          if (capacity?.overRoster ?? false) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.settingsSubscription_capacityOverBody,
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
            ),
          ],
          if (capacity?.overDevices ?? false) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.settingsSubscription_capacityDevicesOverBody,
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
            ),
          ],
          if (capacity?.frozen ?? false) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.settingsSubscription_capacityFrozenBody,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
