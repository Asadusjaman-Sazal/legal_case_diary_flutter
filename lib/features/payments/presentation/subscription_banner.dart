/// The app-wide subscription banner — the pre-expiry notice, the 48h grace
/// warning and the two post-grace messages.
///
/// Task 21 Phase 4 / §7. Entitlement is derived (`subscription_expiry + 48h
/// grace`), so there is no stored flag to watch: this banner recomputes the
/// state from the cached expiry and the recorded clock offset, and renders
/// nothing at all for an account that never subscribed (a free account has no
/// expiry and must not be nagged).
///
/// Five states, the plan's wording plus the pre-expiry warning:
///
///   * **endingSoon** — the plan is still active and ends within a week, so the
///     owner (or an individual) is told the date, with the days left, and asked
///     to renew. This is the warning the monthly Firm plan needed: without it
///     the first sign of an ending plan was a banner after sync had stopped;
///   * **endingSoonAssociate** — the same week, as a member sees it: the plan is
///     the chamber's, so they are told to ask the owner to renew;
///   * **grace** — the expiry has passed but the 48h buffer has not, so sync is
///     still fully active; the banner asks the user to renew and shows the live
///     `HH:MM:SS` remaining in the grace;
///   * **expiredOwner** — past grace, the owner (and any individual) is told to
///     renew to restore sync;
///   * **expiredAssociate** — past grace, an associate is told to contact their
///     firm owner, because the entitlement they inherit is the owner's.
///
/// It is deliberately **not** dismissible: the whole point is that the user
/// learns before losing sync, and a dismissed renewal warning is a warning the
/// user did not get.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/notifications/notification_plan.dart'
    show subscriptionDaysLeft, subscriptionReminderDays;
import '../../../core/utils/date_utils.dart';
import '../../../shared/providers/database_provider.dart';
import '../../../sync/sync_metadata_dao.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../../accounts_and_profile/data/profile_repository.dart'
    show AccountRole;

/// How many days before the end date the banner starts warning.
///
/// The same window the phone reminders use, read from the one list that defines
/// them, so the banner and the notification can never disagree about "a week
/// before".
final int subscriptionBannerDays = subscriptionReminderDays.reduce(
  (a, b) => a > b ? a : b,
);

/// What the subscription banner should say, if anything.
enum SubscriptionBannerState {
  /// Active and not ending soon, or never subscribed: nothing is shown.
  none,

  /// Active but ending within [subscriptionBannerDays]; the owner (or an
  /// individual) must renew.
  endingSoon,

  /// Active but ending within [subscriptionBannerDays]; a firm member should ask
  /// their owner to renew.
  endingSoonAssociate,

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
  final associate = firmMember && role != AccountRole.owner;
  if (expiryAt.isAfter(serverNow)) {
    // Still active: the notice starts a week out and runs to the end date.
    final daysLeft = subscriptionDaysLeft(
      expiryEpochMs: expiry,
      nowEpochMs: serverNow.millisecondsSinceEpoch,
    );
    if (daysLeft > subscriptionBannerDays) return SubscriptionBannerState.none;
    return associate
        ? SubscriptionBannerState.endingSoonAssociate
        : SubscriptionBannerState.endingSoon;
  }
  if (expiryAt.add(const Duration(hours: 48)).isAfter(serverNow)) {
    return SubscriptionBannerState.grace;
  }
  if (associate) return SubscriptionBannerState.expiredAssociate;
  return SubscriptionBannerState.expiredOwner;
}

/// Everything the banner needs to word itself, from one expiry.
class SubscriptionBannerInfo {
  /// Which message to show.
  final SubscriptionBannerState state;

  /// Whole days left, 0 on the plan's last day; null unless [state] is one of
  /// the two ending-soon states.
  final int? daysLeft;

  /// The cached end date, so the message can name it; set for the two
  /// ending-soon states and for the grace countdown.
  final int? expiry;

  /// The recorded `server - device` offset, so the countdown runs on the same
  /// corrected clock as the banner state.
  final int clockOffsetMs;

  /// Creates the info.
  const SubscriptionBannerInfo({
    required this.state,
    this.daysLeft,
    this.expiry,
    this.clockOffsetMs = 0,
  });

  /// The unbounded state, used when nothing is shown.
  static const SubscriptionBannerInfo none = SubscriptionBannerInfo(
    state: SubscriptionBannerState.none,
  );
}

/// Resolves the state and the wording facts together.
///
/// Pure, so the day counting is testable without a device clock.
SubscriptionBannerInfo resolveSubscriptionBannerInfo({
  required int? expiry,
  required DateTime now,
  required int clockOffsetMs,
  required bool firmMember,
  required String role,
}) {
  final state = resolveSubscriptionBanner(
    expiry: expiry,
    now: now,
    clockOffsetMs: clockOffsetMs,
    firmMember: firmMember,
    role: role,
  );
  if (expiry == null) {
    return SubscriptionBannerInfo(
      state: state,
      clockOffsetMs: clockOffsetMs,
    );
  }
  if (state != SubscriptionBannerState.endingSoon &&
      state != SubscriptionBannerState.endingSoonAssociate) {
    return SubscriptionBannerInfo(
      state: state,
      expiry: state == SubscriptionBannerState.grace ? expiry : null,
      clockOffsetMs: clockOffsetMs,
    );
  }
  final serverNow = now.toUtc().add(Duration(milliseconds: clockOffsetMs));
  return SubscriptionBannerInfo(
    state: state,
    daysLeft: subscriptionDaysLeft(
      expiryEpochMs: expiry,
      nowEpochMs: serverNow.millisecondsSinceEpoch,
    ),
    expiry: expiry,
    clockOffsetMs: clockOffsetMs,
  );
}

/// Formats the remaining grace as `HH:MM:SS` in the locale's own digits.
///
/// The countdown is capped at the full 48-hour window, so a stale cached expiry
/// can never print a longer window than the grace actually has.
String formatGraceCountdown(Duration remaining, String locale) {
  final raw = remaining.isNegative ? 0 : remaining.inSeconds;
  final seconds = raw > 48 * 60 * 60 ? 48 * 60 * 60 : raw;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final second = seconds % 60;
  final zero = AppDateUtils.formatDigits(0, locale, grouping: false);

  String two(int value) {
    final text = AppDateUtils.formatDigits(value, locale, grouping: false);
    return value < 10 ? '$zero$text' : text;
  }

  return '${two(hours)}:${two(minutes)}:${two(second)}';
}

/// The recorded clock offset (`server - device`), 0 before the first sync.
final clockOffsetMsProvider = FutureProvider<int>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return await SyncMetadataDao(db).getIntValue(clockOffsetMsKey) ?? 0;
});

/// The banner for the signed-in account.
final subscriptionBannerInfoProvider = Provider<SubscriptionBannerInfo>((ref) {
  final firmMember = ref.watch(firmModeProvider);
  final role = ref.watch(accountRoleProvider);
  final expiry = firmMember
      ? ref.watch(accountFirmProvider).value?.subscriptionExpiry
      : ref.watch(accountProfileProvider).value?.subscriptionExpiry;
  return resolveSubscriptionBannerInfo(
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
    final info = ref.watch(subscriptionBannerInfoProvider);
    if (info.state == SubscriptionBannerState.none) {
      return const SizedBox.shrink();
    }

    final l = AppLocalizations.of(context);
    final (message, background, foreground, icon) = switch (info.state) {
      SubscriptionBannerState.endingSoon => (
        _endingSoonMessage(l, info, associate: false),
        // A heads-up, not a fault: the neutral surface the grace warning uses,
        // so a renewal notice never looks like the red past-grace one.
        AppColors.surfaceContainer,
        AppColors.onSurface,
        Icons.event_outlined,
      ),
      SubscriptionBannerState.endingSoonAssociate => (
        _endingSoonMessage(l, info, associate: true),
        AppColors.surfaceContainer,
        AppColors.onSurface,
        Icons.event_outlined,
      ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: AppTypography.bodySm.copyWith(color: foreground),
                ),
                if (info.state == SubscriptionBannerState.grace &&
                    info.expiry != null) ...[
                  const SizedBox(height: 2),
                  _GraceCountdown(
                    expiryEpochMs: info.expiry!,
                    clockOffsetMs: info.clockOffsetMs,
                    color: foreground,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The pre-expiry sentence: days and date while several remain, the date
  /// alone on the last day (a plan ending tomorrow reads better than "in 1
  /// days").
  String _endingSoonMessage(
    AppLocalizations l,
    SubscriptionBannerInfo info, {
    required bool associate,
  }) {
    final daysLeft = info.daysLeft ?? 0;
    final expiry = info.expiry ?? 0;
    final date = AppDateUtils.formatDateDDMMYYYY(expiry, locale: l.localeName);
    final days = AppDateUtils.formatDigits(daysLeft, l.localeName);
    if (daysLeft < 2) {
      return associate
          ? l.subscription_bannerEndingAssociateLastDay(date)
          : l.subscription_bannerEndingLastDay(date);
    }
    return associate
        ? l.subscription_bannerEndingAssociate(days, date)
        : l.subscription_bannerEnding(days, date);
  }
}

/// The live `HH:MM:SS` remaining in the 48-hour grace.
///
/// It ticks once a second, uses the same corrected clock as the banner, and at
/// zero invalidates the banner's info so the state turns into the red expired
/// message. It is mounted only inside the grace state, so an account that is
/// not in the grace runs no timer at all.
class _GraceCountdown extends ConsumerStatefulWidget {
  const _GraceCountdown({
    required this.expiryEpochMs,
    required this.clockOffsetMs,
    required this.color,
  });

  /// The paid period's end, in epoch milliseconds.
  final int expiryEpochMs;

  /// The recorded `server - device` offset.
  final int clockOffsetMs;

  /// The banner's foreground, so the countdown matches the message.
  final Color color;

  @override
  ConsumerState<_GraceCountdown> createState() => _GraceCountdownState();
}

class _GraceCountdownState extends ConsumerState<_GraceCountdown> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _compute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (_remaining <= Duration.zero) {
      // A stale banner can mount this at the boundary; flip it after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(subscriptionBannerInfoProvider);
      });
    }
  }

  Duration _compute() {
    final serverNow = DateTime.now()
        .toUtc()
        .add(Duration(milliseconds: widget.clockOffsetMs));
    final graceEnd = DateTime.fromMillisecondsSinceEpoch(
      widget.expiryEpochMs,
      isUtc: true,
    ).add(const Duration(hours: 48));
    return graceEnd.difference(serverNow);
  }

  void _tick() {
    if (!mounted) return;
    final remaining = _compute();
    if (remaining <= Duration.zero) {
      _timer?.cancel();
      ref.invalidate(subscriptionBannerInfoProvider);
      return;
    }
    setState(() => _remaining = remaining);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Text(
      l.subscription_bannerGraceCountdown(
        formatGraceCountdown(_remaining, l.localeName),
      ),
      key: const ValueKey('subscription-grace-countdown'),
      style: AppTypography.titleMd.copyWith(color: widget.color),
    );
  }
}
