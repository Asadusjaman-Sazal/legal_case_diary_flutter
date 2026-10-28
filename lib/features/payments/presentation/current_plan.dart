/// The account's current plan — the one answer to "what plan is running".
///
/// Two surfaces print it: the side menu's plan row and Subscription Details'
/// **Current Plan**. Both read this, so the plan rule lives in one place
/// instead of being re-derived at a call site.
///
/// The rule it keeps: entitlement is *derived* (`subscription_expiry + 48h
/// grace`), never the display-only `subscription_status` flag, and an
/// entitlement that has not landed yet reads a **dash** rather than *Free* —
/// a premium user whose profile pull is still in flight must never be told
/// they have nothing (plan §6, the entitlement bullet).
///
/// The label is a plain function rather than a provider because it needs the
/// [AppLocalizations] of the widget that prints it, which a provider cannot
/// read.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../data/payment_local_store.dart';
import '../data/payment_plans.dart';
import '../data/payment_repository.dart';
import 'payment_plan_labels.dart';

/// The account's plan: whether entitlement has landed, whether it is premium
/// right now, and the latest approved plan's own key when it names one.
typedef CurrentPlan = ({bool known, bool premium, String? planKey});

/// The plan this account is running.
///
/// * [CurrentPlan.known] is false until the cached profile row has landed: the
///   plan is a fact only once that row exists, because `resolvePremiumAccess`
///   treats an absent row as "no expiry" — the safe answer for a gate and a
///   wrong answer for a label.
/// * [CurrentPlan.premium] is the derived entitlement, so a firm member counts
///   as premium on the firm's expiry and an individual on their own.
/// * [CurrentPlan.planKey] is the newest **approved** submission whose tier is
///   the tier the account holds — not the newest purchase outright, because a
///   different tier is queued until the current period ends. It is deliberately
///   absent for a chamber **member** (Phase 9): a plan they bought before
///   joining is ignored while they hold the chamber, so naming it here would
///   tell them a plan is running that is not. *Premium* is the generic word for
///   that case; the Firm Plan page names the chamber's own tier instead
///   (`firmPlanName`, 0.0.699). The owner is not a member and keeps
///   naming the plan they bought, because that purchase is the chamber's
///   renewal. **Offline**, the ledger cannot name a plan at all, so the key this
///   device last saw running stands in ([runningPlanCacheProvider]) — used only
///   while the cached row still holds the tier it was recorded for, and never
///   for a member.
final currentPlanProvider = Provider<CurrentPlan>((ref) {
  final premium = ref.watch(premiumAccessProvider);
  String? approvedPlan;
  if (!ref.watch(firmMemberProvider)) {
    // Own rows under RLS, newest first. A member's rows are never read: their
    // last tier is the chamber's.
    //
    // The newest approved purchase is **not** always the plan running: a
    // purchase of a different tier is queued and starts when the current
    // period ends. So the label looks for the newest approval whose tier is the
    // tier this account actually holds, and leaves the queued one to the
    // *Scheduled* line. Legacy `pro` keys answer Starter, which is what their
    // stored tier became.
    final storedTier = ref.watch(currentTierProvider);
    final ledger = ref.watch(myPaymentSubmissionsProvider);
    final live = runningPlanKey(
      (ledger.value ?? const <PaymentSubmission>[])
          .where((row) => row.status == 'approved')
          .map((row) => row.planType),
      storedTier,
    );
    // Offline the ledger never lands, and the plan key alone is what makes the
    // label a name rather than the generic *Premium* — so the device's own copy
    // stands in. It is used only while it was recorded for the tier the cached
    // profile (or firm) row still holds, which is what keeps a queued change
    // from leaving the old plan's name on screen (user report, 0.0.683).
    final cached = ref.watch(runningPlanCacheProvider);
    approvedPlan =
        live ??
        (!ledger.hasValue && cached != null && cached.tier == storedTier
            ? cached.planKey
            : null);
  }
  return (
    known: ref.watch(entitlementKnownProvider) && !premium.isLoading,
    premium: premium.value ?? false,
    planKey: approvedPlan,
  );
});

/// The moment the plan in force ended **because it was cancelled**, or null.
///
/// A plan stops two ways: its date runs out, or the account cancels it. The
/// page says which, and the answer comes from the ledger it already shows — the
/// newest approved purchase of the tier in force against the newest cancellation
/// of that same tier. A cancellation older than the latest purchase belongs to
/// a previous cycle, so a renewal hides it again instead of marking a plan that
/// has since run its course as cancelled.
///
/// Null while either ledger is still loading, and for a free tier, which has
/// nothing to cancel. A chamber **member** has no cancellation row of their own
/// (the owner's cancellation is the owner's), so a member reads the expired
/// wording; the screen still marks the plan Limited Access either way.
final subscriptionCancelledAtProvider = Provider<DateTime?>((ref) {
  final tier = ref.watch(allowanceTierProvider);
  if (tier == SubscriptionTier.free) return null;
  final submissions = ref.watch(myPaymentSubmissionsProvider).value;
  final cancellations = ref.watch(mySubscriptionCancellationsProvider).value;
  if (submissions == null || cancellations == null) return null;

  var newestPurchase = 0;
  for (final submission in submissions) {
    if (submission.status != 'approved' ||
        planTier(submission.planType) != tier) {
      continue;
    }
    final at =
        (submission.approvedAt ?? submission.submittedAt)
            ?.millisecondsSinceEpoch ??
        0;
    if (at > newestPurchase) newestPurchase = at;
  }

  var newestCancellation = 0;
  DateTime? cancelledAt;
  for (final cancellation in cancellations) {
    final key = cancellation.planType;
    final at = cancellation.cancelledAt?.millisecondsSinceEpoch ?? 0;
    if (key == null || planTier(key) != tier || at == 0) continue;
    if (at > newestCancellation) {
      newestCancellation = at;
      cancelledAt = cancellation.cancelledAt;
    }
  }
  return newestCancellation > newestPurchase ? cancelledAt : null;
});

/// The localized label for [plan]: the dash while entitlement is in flight,
/// *Free*, *Premium*, or the paid plan's own name.
///
/// A paid account whose period has ended holds a tier but no entitlement, so
/// calling it *Free* would contradict the allowance: it names the tier and adds
/// the **Limited Access** tag beside it instead (it read *— Lapsed* before the
/// user asked for plainer words). [tier] is optional so a caller without a tier
/// (a test, a surface with no tier yet) keeps the old answer.
///
/// [firmPlanName] names the chamber's own tier for a member whose ledger cannot
/// name a plan (user request, 0.0.699): the Firm Plan page asks for it, while
/// the side menu keeps its *Premium* wording.
String currentPlanLabel(
  AppLocalizations l,
  CurrentPlan plan, {
  SubscriptionTier? tier,
  bool firmPlanName = false,
}) {
  if (!plan.known) return '—';
  if (!plan.premium) {
    if (tier != null && tier != SubscriptionTier.free) {
      return '${subscriptionTierLabel(l, tier)} '
          '${l.settingsManageAccount_planLimitedAccessTag}';
    }
    return l.settingsManageAccount_planFree;
  }
  final key = plan.planKey;
  if (key == null &&
      firmPlanName &&
      tier != null &&
      tier != SubscriptionTier.free) {
    return subscriptionTierLabel(l, tier);
  }
  return key == null
      ? l.settingsManageAccount_planPremium
      : paymentPlanLabel(l, key);
}

/// The plan as it reads on screen, with the **Limited Access** tag when it
/// applies.
///
/// One widget rather than a bare string so the tag can be the app's error red
/// and a little smaller than the name beside it, wherever the plan is printed —
/// the side menu's plan row and Subscription Details' Current Plan row. The tag
/// is a pair of square brackets around the words in the ARB, so a translator
/// owns the bracket style along with the words.
///
/// [showTag] is false for the details card's heading: it prints the plan as the
/// card's title, and the tag is stated once in the Current Plan row below it
/// rather than twice on one card.
class CurrentPlanLabel extends ConsumerWidget {
  /// Creates the label.
  const CurrentPlanLabel({
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.showTag = true,
    this.tagGap = ' ',
    this.firmPlanName = false,
  });

  /// The style the caller's surface gives the plan's name.
  final TextStyle? style;

  /// Alignment of the label in the space it is given.
  final TextAlign textAlign;

  /// Lines before an ellipsis: one, so a long tier name or tag never wraps a
  /// row onto a second line.
  final int maxLines;

  /// Whether a plan that has ended carries its red tag.
  final bool showTag;

  /// The run of spaces that sets the tag apart from the plan's name.
  ///
  /// One space on the details card, where the row is narrow; the side menu asks
  /// for one more, because its row is wider and the tag reads there as a note
  /// beside the name rather than a suffix (user request).
  final String tagGap;

  /// Whether a member's label names the chamber's tier instead of *Premium*.
  ///
  /// Off by default: the side menu keeps its *Premium* wording. The Firm Plan
  /// page turns it on (user request, 0.0.699).
  final bool firmPlanName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final plan = ref.watch(currentPlanProvider);
    final tier = ref.watch(allowanceTierProvider);
    final base = style ?? AppTypography.bodyMd;
    final limited =
        showTag && plan.known && !plan.premium && tier != SubscriptionTier.free;
    if (!limited) {
      return Text(
        currentPlanLabel(l, plan, tier: tier, firmPlanName: firmPlanName),
        style: base,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: subscriptionTierLabel(l, tier)),
          TextSpan(
            text: '$tagGap${l.settingsManageAccount_planLimitedAccessTag}',
            style: TextStyle(
              color: AppColors.error,
              // Relative, not a size of its own: the tag has to sit inside a
              // 14 pt row and beside a 20 pt heading alike.
              fontSize: (base.fontSize ?? 14) * 0.8,
            ),
          ),
        ],
      ),
      style: base,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
