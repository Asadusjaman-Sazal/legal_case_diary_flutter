/// The localized name of one subscription plan.
///
/// The plan key is the single source of a plan's identity (see
/// `payment_plans.dart`), and three screens render its name — the paywall, the
/// checkout's plan summary and Manage Account — so the key-to-name mapping lives
/// here once rather than as a binary `monthly/annual` ternary repeated in each.
library;

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../data/payment_plans.dart';

/// The localized display name of [planKey], defaulting to the 1 Month plan for
/// a null or unknown key (the same default the checkout applies).
String paymentPlanLabel(AppLocalizations l, String? planKey) => switch (planKey) {
  paymentPlanQuarterly => l.paywall_planQuarterly,
  paymentPlanHalfYearly => l.paywall_planHalfYearly,
  paymentPlanAnnual => l.paywall_planAnnual,
  _ => l.paywall_planMonthly,
};

/// The localized price line for [plan], e.g. ৳285 for 3 months.
///
/// The plan carries its own amount, so this is the only place the price is
/// worded; the caller localizes the digits before calling this.
String paymentPlanPriceLabel(
  AppLocalizations l,
  SubscriptionPlan plan,
  String price,
) => switch (plan.key) {
  paymentPlanMonthly => l.paywall_planMonthlyPrice(price),
  paymentPlanQuarterly => l.paywall_planQuarterlyPrice(price),
  paymentPlanHalfYearly => l.paywall_planHalfYearlyPrice(price),
  _ => l.paywall_planAnnualPrice(price),
};

/// The localized "10% Off" badge for [plan], or null when it has no discount.
///
/// The percentage is derived from the plan's own amounts, so a badge can never
/// claim a saving the paywall is not actually offering.
String? paymentPlanDiscountLabel(AppLocalizations l, SubscriptionPlan plan) {
  final percent = plan.discountPercent;
  if (percent == 0) return null;
  return l.paywall_planDiscount(
    AppDateUtils.formatDigits(percent, l.localeName, grouping: false),
  );
}
