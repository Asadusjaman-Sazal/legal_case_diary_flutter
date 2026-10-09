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
/// * [CurrentPlan.planKey] is the newest **approved** submission's plan. A
///   member riding on the firm's subscription has no submission of their own,
///   which is the case the word *Premium* exists for rather than a repeated
///   tier name.
final currentPlanProvider = Provider<CurrentPlan>((ref) {
  final premium = ref.watch(premiumAccessProvider);
  // Own rows under RLS, newest first, so the first approval is the active plan.
  final submissions = ref.watch(myPaymentSubmissionsProvider).value ?? const [];
  String? approvedPlan;
  for (final submission in submissions) {
    if (submission.status == 'approved') {
      approvedPlan = submission.planType;
      break;
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
String currentPlanLabel(AppLocalizations l, CurrentPlan plan) {
  if (!plan.known) return '—';
  if (!plan.premium) return l.settingsManageAccount_planFree;
  final key = plan.planKey;
  return key == null
      ? l.settingsManageAccount_planPremium
      : paymentPlanLabel(l, key);
}
