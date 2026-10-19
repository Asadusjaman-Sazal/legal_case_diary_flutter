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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../accounts_and_profile/data/account_mode.dart';
import '../data/payment_plans.dart';
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
///   tell them a plan is running that is not. *Premium* is the word for that
///   case rather than a repeated tier name. The owner is not a member and keeps
///   naming the plan they bought, because that purchase is the chamber's
///   renewal.
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
    final submissions =
        ref.watch(myPaymentSubmissionsProvider).value ?? const [];
    for (final submission in submissions) {
      if (submission.status == 'approved' &&
          planTier(submission.planType) == storedTier) {
        approvedPlan = submission.planType;
        break;
      }
    }
  }
  return (
    known: ref.watch(entitlementKnownProvider) && !premium.isLoading,
    premium: premium.value ?? false,
    planKey: approvedPlan,
  );
});

/// The localized label for [plan]: the dash while entitlement is in flight,
/// *Free*, *Premium*, or the paid plan's own name.
///
/// Phase 10 adds the lapsed case: a paid account whose period has ended holds a
/// tier but no entitlement, so calling it *Free* would contradict the allowance
/// — it names the tier and says it has lapsed instead. [tier] is optional so a
/// caller without a tier (a test, a surface with no tier yet) keeps the old
/// answer.
String currentPlanLabel(
  AppLocalizations l,
  CurrentPlan plan, {
  SubscriptionTier? tier,
}) {
  if (!plan.known) return '—';
  if (!plan.premium) {
    if (tier != null && tier != SubscriptionTier.free) {
      return l.settingsManageAccount_planLapsed(subscriptionTierLabel(l, tier));
    }
    return l.settingsManageAccount_planFree;
  }
  final key = plan.planKey;
  return key == null
      ? l.settingsManageAccount_planPremium
      : paymentPlanLabel(l, key);
}
