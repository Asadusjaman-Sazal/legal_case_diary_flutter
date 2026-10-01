/// The app-wide subscription banner — the 48h grace warning and the two
/// post-grace messages.
///
/// Task 21 Phase 4 / §7. Entitlement is derived (`subscription_expiry + 48h
/// grace`), so there is no stored flag to watch: this banner recomputes the
/// state from the cached expiry and the recorded clock offset, and renders
/// nothing at all for an active subscription or an account that never subscribed
/// (a free account has no expiry and must not be nagged).
///
/// Three states, exactly the plan's wording:
///
///   * **grace** — the expiry has passed but the 48h buffer has not, so sync is
///     still fully active and the banner asks the user to renew;
///   * **expiredOwner** — past grace, the owner (and any individual) is told to
///     renew to restore sync;
///   * **expiredAssociate** — past grace, an associate is told to contact their
///     firm owner, because the entitlement they inherit is the owner's.
///
/// It is deliberately **not** dismissible: the whole point is that the user
/// learns before losing sync, and a dismissed renewal warning is a warning the
/// user did not get.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../sync/sync_metadata_dao.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../accounts_and_profile/data/profile_repository.dart'
    show AccountRole;

/// What the subscription banner should say, if anything.
enum SubscriptionBannerState {
  /// Active, or never subscribed: nothing is shown.
  none,

  /// Expired but inside the 48h grace window; sync is still active.
  grace,

  /// Past grace; the owner (or an individual) must renew.
  expiredOwner,

  /// Past grace; an associate must ask their firm owner.
  expiredAssociate,
}

/// Resolves the banner state from the one expiry and the corrected clock.
///
/// Pure, so the boundary cases are unit-testable. [clockOffsetMs] is the
/// recorded `server - device` offset (Task 18 Phase 3); applying it keeps a
/// skewed device from flipping the banner wrongly.
SubscriptionBannerState resolveSubscriptionBanner({
  required int? expiry,
  required DateTime now,
  required int clockOffsetMs,
  required bool firmMember,
  required String role,
}) {
  if (expiry == null) return SubscriptionBannerState.none;
  final serverNow = now
      .toUtc()
      .add(Duration(milliseconds: clockOffsetMs));
  final expiryAt = DateTime.fromMillisecondsSinceEpoch(expiry, isUtc: true);
  if (expiryAt.isAfter(serverNow)) return SubscriptionBannerState.none;
  if (expiryAt.add(const Duration(hours: 48)).isAfter(serverNow)) {
    return SubscriptionBannerState.grace;
  }
  if (firmMember && role != AccountRole.owner) {
    return SubscriptionBannerState.expiredAssociate;
  }
  return SubscriptionBannerState.expiredOwner;
}

/// The recorded clock offset (`server - device`), 0 before the first sync.
final clockOffsetMsProvider = FutureProvider<int>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return await SyncMetadataDao(db).getIntValue(clockOffsetMsKey) ?? 0;
});

/// The banner state for the signed-in account.
final subscriptionBannerStateProvider = Provider<SubscriptionBannerState>((
  ref,
) {
  final firmMember = ref.watch(firmModeProvider);
  final role = ref.watch(accountRoleProvider);
  final expiry = firmMember
      ? ref.watch(accountFirmProvider).value?.subscriptionExpiry
      : ref.watch(accountProfileProvider).value?.subscriptionExpiry;
  return resolveSubscriptionBanner(
    expiry: expiry,
    now: DateTime.now(),
    clockOffsetMs: ref.watch(clockOffsetMsProvider).value ?? 0,
    firmMember: firmMember,
    role: role,
  );
});

/// The persistent subscription bar. Renders nothing when all is well.
class SubscriptionBanner extends ConsumerWidget {
  /// Creates the banner.
  const SubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionBannerStateProvider);
    if (state == SubscriptionBannerState.none) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    final (message, background, foreground, icon) = switch (state) {
      SubscriptionBannerState.grace => (
        l.subscription_bannerGrace,
        AppColors.surfaceContainer,
        AppColors.onSurface,
        Icons.schedule_outlined,
      ),
      SubscriptionBannerState.expiredAssociate => (
        l.subscription_bannerExpiredAssociate,
        AppColors.error.withValues(alpha: 0.12),
        AppColors.error,
        Icons.error_outline,
      ),
      _ => (
        l.subscription_bannerExpiredOwner,
        AppColors.error.withValues(alpha: 0.12),
        AppColors.error,
        Icons.error_outline,
      ),
    };

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.edgeMargin,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
