/// The localized name of one subscription plan or tier.
///
/// The plan key is the single source of a plan's identity (see
/// `payment_plans.dart`), and three screens render its name — the paywall, the
/// checkout's plan summary and Manage Account — so the key-to-name mapping lives
/// here once rather than as a chain of ternaries repeated in each.
///
/// The tier's own name (`Pro` / `Firm` / `Firm Plus`) comes from
/// [subscriptionTierLabel] beside it: a screen that shows a plan in a tier group
/// needs both, and they must agree on the key that drives them.
library;

import '../../../core/l10n/generated/app_localizations.dart';
import '../data/payment_plans.dart';

/// The localized display name of [planKey], defaulting to the Pro 1 Month plan
/// for a null or unknown key (the same default the checkout applies).
String paymentPlanLabel(AppLocalizations l, String? planKey) => switch (planKey) {
  paymentPlanQuarterly => l.paywall_planQuarterly,
  paymentPlanHalfYearly => l.paywall_planHalfYearly,
  paymentPlanAnnual => l.paywall_planAnnual,
  paymentPlanFirmQuarterly => l.paywall_planFirmQuarterly,
  paymentPlanFirmHalfYearly => l.paywall_planFirmHalfYearly,
  paymentPlanFirmAnnual => l.paywall_planFirmAnnual,
  paymentPlanFirmPlusQuarterly => l.paywall_planFirmPlusQuarterly,
  paymentPlanFirmPlusHalfYearly => l.paywall_planFirmPlusHalfYearly,
  paymentPlanFirmPlusAnnual => l.paywall_planFirmPlusAnnual,
  _ => l.paywall_planMonthly,
};

/// The localized name of [tier] — *Pro*, *Firm* or *Firm Plus*.
///
/// The server stores the tier as a key (`pro`, `firm`, `firm_plus`), so the
/// stored value never localizes; this is where the app's own words come from.
String subscriptionTierLabel(AppLocalizations l, SubscriptionTier tier) =>
    switch (tier) {
      SubscriptionTier.free => l.settingsManageAccount_planFree,
      SubscriptionTier.pro => l.paywall_tierPro,
      SubscriptionTier.firm => l.paywall_tierFirm,
      SubscriptionTier.firmPlus => l.paywall_tierFirmPlus,
    };
